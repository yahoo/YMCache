//  Created by Adam Kaplan on 8/1/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import "YMCachePersistenceController.h"
#import "YMMemoryCache.h"
#import "YMLog.h"

#include "TargetConditionals.h"


static NSString *const kYFCachePersistenceErrorDomain = @"YFCachePersistenceErrorDomain";

@interface YMCachePersistenceController ()
@property (nonatomic) dispatch_source_t updateTimer;
@property (nonatomic) dispatch_queue_t updateQueue;
@end

@implementation YMCachePersistenceController

+ (NSURL *)defaultCacheDirectory {
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    if (!urls.count) {
        NSAssert(false, @"%@", @"Unable to find suitable cache directory URL");
        return nil;
    }
    return [urls lastObject];
}

- (instancetype)initWithCache:(YMMemoryCache *)cache
                   modelClass:(Class)modelClass
                     delegate:(id<YMSerializationDelegate>)serializionDelegate
                      fileURL:(NSURL *)cacheFileURL {
    NSParameterAssert(cache);
    NSParameterAssert(serializionDelegate);
    NSParameterAssert(cacheFileURL);
    if (!cache || !cacheFileURL || !serializionDelegate) {
        // If any of these variables are nil, the persistence controller cannot do it's job.
        NSString *exceptionReason;
        if (!cache) {
            exceptionReason = @"A cache is required to use cache persistence controller.";
        }
        
        if (!cacheFileURL) {
            exceptionReason = @"The cache file URL is required to use cache persistence controller."
            @" If the cache is not meant to be stored in a file, do not use a persistence controller.";
        }
        
        if (!serializionDelegate) {
            exceptionReason = @"Serialization delegate is required for the persistence controller to "
            @"map between representations of the cache data between file and memory.";
        }
        
        @throw [NSException exceptionWithName:@"InvalidParameterException"
                                       reason:exceptionReason
                                     userInfo:nil];
        
        return nil;
    }
    
    self = [super init];
    if (self) {
        _cache = cache;
        _modelClass = modelClass;
        _cacheFileURL = cacheFileURL;
        _serializionDelegate = serializionDelegate;
        _fileWritingOptions = NSDataWritingAtomic;
        
        NSString *queueName = @"com.yahoo.persist";
        if (cache.name) {
            [queueName stringByAppendingFormat:@"%@ ", cache.name];
        }
        _updateQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (instancetype)initWithCache:(YMMemoryCache *)cache
                   modelClass:(Class)modelClass
                     delegate:(id<YMSerializationDelegate>)serializionDelegate
                         name:(NSString *)cacheName {
    NSParameterAssert(cacheName.length);
    if (!cacheName.length) {
        return nil;
    }
    
    NSURL *defaultCacheDirectoryURL = [[self class] defaultCacheDirectory];
    NSURL *cacheFileURL = [defaultCacheDirectoryURL URLByAppendingPathComponent:cacheName isDirectory:NO];
    return [self initWithCache:cache modelClass:modelClass delegate:serializionDelegate fileURL:cacheFileURL];
}

- (void)setSaveInterval:(NSTimeInterval)saveInterval {
    // Explicitely not checking to see if saveInterval has actually changed. There may be some expectation
    // about timing from a client's perspective. For example, if at once point saveInterval is set to 10s,
    // and then 5s later it is once again set to 10s, when should it fire?
    // A) With a change check: 10s after the first call, 5s after the second call – second caller is confused
    // B) Without a change check: 20s after the first call, 10s after the second call – first caller is confused
    
    dispatch_sync(self.updateQueue, ^{
        self->_saveInterval = saveInterval;
        
        // Invalidate existing source timer.
        if (self.updateTimer) {
            dispatch_source_cancel(self.updateTimer);
            self.updateTimer = nil;
        }
        
        // Create new timer if interval is positive
        if (saveInterval > 0) {
            //YMLog(@"Setting cache (%@) auto-save interval to %0.4fs", _cache.name, saveInterval);
            
            dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.updateQueue);
            dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, (UInt64)(saveInterval * NSEC_PER_SEC), NSEC_PER_SEC / 10);
            __weak __typeof(self) weakSelf = self;
            dispatch_source_set_event_handler(timer, ^{
                __strong __typeof(self) strongSelf = weakSelf;
                
                if ([strongSelf.serializionDelegate respondsToSelector:@selector(persistenceControllerWillSaveMemoryCache:)]) {
                    [strongSelf.serializionDelegate persistenceControllerWillSaveMemoryCache:strongSelf];
                }
                
                NSError *error;
                [strongSelf saveMemoryCache:&error];
                
                if (error) {
                    if ([strongSelf.serializionDelegate respondsToSelector:@selector(persistenceController:didFailToSaveMemoryCacheWithError:)]) {
                        [strongSelf.serializionDelegate persistenceController:strongSelf didFailToSaveMemoryCacheWithError:error];
                    }
                    return;
                }
                
                if ([strongSelf.serializionDelegate respondsToSelector:@selector(persistenceControllerDidSaveMemoryCache:)]) {
                    [strongSelf.serializionDelegate persistenceControllerDidSaveMemoryCache:strongSelf];
                }
            });
            
            self.updateTimer = timer;
            dispatch_resume(timer);
        }
        else {
            //YMLog(@"Disabling cache (%@) auto-save", _cache.name);
        }
    });
}

- (NSUInteger)loadMemoryCache:(NSError * __autoreleasing *)error {
    // NSJSONSerialization and NSValueTransformers can be rather agressive in their exceptions.
    // Reading the pre-existing cache is not critical. If an exception is thrown, we'll swallow it here and wrap
    // it in an error. The app will act as though it did not have any cached data.
    @try {
        return [self p_loadMemoryCacheUnsafe:error];
    }
    @catch (NSException *exception) {
        if (error) {
            *error = [self errorFromException:exception context:@"Cache Save"];
        }
        return 0;
    }
}

- (NSUInteger)p_loadMemoryCacheUnsafe:(NSError * __autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    BOOL cacheFileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.cacheFileURL.path isDirectory:nil];
    if (!cacheFileExists) {
        return 0;
    }
    
    // Find, open, and load raw JSON into a dictionary
    NSInputStream *is = [NSInputStream inputStreamWithURL:self.cacheFileURL];
    [is open];
    if ([is streamError]) {
        if (error) {
            *error = [is streamError];
            //YMLog(@"Cache read stream error: %@", *error);
        }
        return 0;
    }
    
    NSMutableDictionary *dict = [NSJSONSerialization JSONObjectWithStream:is options:NSJSONReadingMutableContainers error:error];
    [is close];
    
    if (dict && ![dict isKindOfClass:[NSMutableDictionary class]]) {
        //YMLog(@"Invalid cache file format, not a dictionary in %@", self.cacheFileURL);
        
        if (error && !*error) { // set error if JSON parsing didn't fail, but the JSON root element was unexpected.
            NSString *errorStr = [NSString stringWithFormat:@"Invalid JSON format. Expected root element to be NSMutableDictionary, got %@", [dict class]];
            *error = [NSError errorWithDomain:@"YFCachePersistence" code:0 userInfo:@{ NSLocalizedDescriptionKey: errorStr }];
        }
        
        // Remove error can happen, but we can only return one error, so log it.
        NSError *removeError;
        [[NSFileManager defaultManager] removeItemAtURL:self.cacheFileURL error:&removeError];
        if (removeError) {
            YMLog(@"Error while attempting to delete corrupt cache file %@", removeError);
        }
        return 0;
    }
    
    // De-serialize model entries
    for (id key in dict.allKeys) {
        NSDictionary *value = dict[key];
        id model = [self.serializionDelegate persistenceController:self modelFromJSONDictionary:value error:error];
        if (!model) {
            NSError *logError;
            if (error) {
                logError = *error;
                error = nil;
            }
            YMLog(@"Error de-serializing model at %@ of type %@ from JSON value %@ – %@", key, self.modelClass, value, logError);
            continue;
        }
        dict[key] = model;
    }
    
    // Load into cache
    [self.cache addEntriesFromDictionary:dict];
    return dict.count;
}

- (BOOL)saveMemoryCache:(NSError * __autoreleasing *)error {
    // NSJSONSerialization and NSValueTransformers can be rather agressive in their exceptions.
    // Writing the cache is not critical. If an exception is thrown, we'll swallow it here and wrap
    // it in an error
    @try {
        return [self p_saveMemoryCacheUnsafe:error];
    }
    @catch (NSException *exception) {
        if (error) {
            *error = [self errorFromException:exception context:@"Cache Save"];
        }
        
        return NO;
    }
}

- (BOOL)p_saveMemoryCacheUnsafe:(NSError * __autoreleasing *)error {
    if (error) {
        *error = nil;
    }
    
    NSMutableDictionary *cacheEntries = [self.cache.allItems mutableCopy];
    for (id key in cacheEntries.allKeys) {
        id value = cacheEntries[key];
        
        NSDictionary *dict = [self.serializionDelegate persistenceController:self JSONDictionaryFromModel:value error:error];
        if (dict) {
            cacheEntries[key] = dict;
        }
    }
    
    NSError *localError;
    NSData *data = [NSJSONSerialization dataWithJSONObject:cacheEntries options:0 error:&localError];
    if (localError) {
        if (error) {
            *error = localError;
        }
        //YMLog(@"Error serializing cache to json: %@", localError.localizedDescription);
        return NO;
    }
    
    BOOL success = [data writeToURL:self.cacheFileURL options:self.fileWritingOptions error:&localError];
    if (localError) {
        if (error) {
            *error = localError;
        }
        //YMLog(@"Error writing cache to file '%@' %@", self.cacheFileURL, localError.localizedDescription);
    }
    return success;
}

- (NSError *)errorFromException:(NSException *)exception context:(NSString *)contextString {
    NSParameterAssert(contextString);
    NSParameterAssert(exception);
    
    NSString *reason = [NSString stringWithFormat:@"[%@] %@: %@", contextString, exception.name, exception.reason];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (exception.userInfo) {
        [userInfo addEntriesFromDictionary:exception.userInfo];
    }
    
    if (exception.callStackSymbols) {
        userInfo[@"CallStack"] = exception.callStackSymbols;
    }
    userInfo[NSLocalizedDescriptionKey] = reason;
    
    NSError *error = [NSError errorWithDomain:kYFCachePersistenceErrorDomain
                                         code:1
                                     userInfo:userInfo];
    return error;
}

@end
