//  Created by Adam Kaplan on 9/9/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

@import YMCache;

@interface TestDelegate : NSObject <YMSerializationDelegate>
@end
@implementation TestDelegate
- (id)persistenceController:(YMCachePersistenceController *)controller
    modelFromJSONDictionary:(NSDictionary *)value
                      error:(NSError * __autoreleasing *)error {
    return nil;
}

- (NSDictionary *)persistenceController:(YMCachePersistenceController *)controller
                JSONDictionaryFromModel:(id)value
                                  error:(NSError *  __autoreleasing *)error {
    return nil;
}
@end

SpecBegin(YMCachePersistenceControllerSpec)

describe(@"YMCachePersistenceControllerSpec", ^{
    
    __block YMCachePersistenceController *controller;
    __block YMMemoryCache *cache;
    __block Class modelClass;
    __block id<YMSerializationDelegate> delegate;
    __block NSString *fileName;
    
    beforeEach(^{
        cache = [[YMMemoryCache alloc] initWithName:@"CacheName" evictionDecider:nil];
        modelClass = [NSObject class];
        delegate = [TestDelegate new];
        fileName = @"test-cache";
        
        controller = [[YMCachePersistenceController alloc] initWithCache:cache
                                                              modelClass:modelClass
                                                                delegate:delegate
                                                                    name:fileName];
    });
    
    afterEach(^{});
    
    context(@"Default Cache Directory", ^{
        NSURL *gotUrl = [YMCachePersistenceController defaultCacheDirectory];
        NSURL *expectUrl = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                            inDomains:NSUserDomainMask].firstObject;
        expect(expectUrl).to.equal(gotUrl);
    });
    
    describe(@"Default initializer", ^{
        
        __block NSURL *fileUrl;
        
        beforeEach(^{
            cache = [[YMMemoryCache alloc] initWithName:@"Name" evictionDecider:nil];
            modelClass = [NSObject class];
            fileUrl = [NSURL URLWithString:@"file:///"];
        });
        
        context(@"required args", ^{
            __block id unused;
            
            it(@"throws exception if cache is nil", ^{
                cache = nil;
                expect(^{
                    unused = [[YMCachePersistenceController alloc] initWithCache:cache
                                                                      modelClass:modelClass
                                                                        delegate:delegate
                                                                         fileURL:fileUrl];
                }).to.raiseWithReason(@"InvalidParameterException",
                                      @"A cache is required to use cache persistence controller.");
            });
            
            it(@"throws exception if delegate is nil", ^{
                delegate = nil;
                expect(^{
                    unused = [[YMCachePersistenceController alloc] initWithCache:cache
                                                                      modelClass:modelClass
                                                                        delegate:delegate
                                                                         fileURL:fileUrl];
                }).to.raiseWithReason(@"InvalidParameterException",
                                      @"Serialization delegate is required for the persistence controller to "
                                      @"map between representations of the cache data between file and memory.");
            });
            
            it(@"throws exception if fileURL is nil", ^{
                fileUrl = nil;
                expect(^{
                    unused = [[YMCachePersistenceController alloc] initWithCache:cache
                                                                      modelClass:modelClass
                                                                        delegate:delegate
                                                                         fileURL:fileUrl];
                }).to.raiseWithReason(@"InvalidParameterException",
                                      @"The cache file URL is required to use cache persistence controller."
                                      @" If the cache is not meant to be stored in a file, do not use a"
                                      @" persistence controller.");
            });
        });
        
        context(@"correctly set initial values", ^{
            
            it(@"sets all values", ^{
                YMCachePersistenceController *con = [[YMCachePersistenceController alloc] initWithCache:cache
                                                                                             modelClass:modelClass
                                                                                               delegate:delegate
                                                                                                fileURL:fileUrl];
                expect(con.cache).to.beIdenticalTo(cache);
                expect(con.modelClass).to.beIdenticalTo(modelClass);
                expect(con.serializionDelegate).to.beIdenticalTo(delegate);
                expect(con.cacheFileURL).to.equal(fileUrl);
            });
            
            it(@"sets minimum values", ^{
                modelClass = nil;
                
                YMCachePersistenceController *con = [[YMCachePersistenceController alloc] initWithCache:cache
                                                                                             modelClass:modelClass
                                                                                               delegate:delegate
                                                                                                fileURL:fileUrl];
                expect(con.cache).to.beIdenticalTo(cache);
                expect(con.modelClass).to.beNil();
                expect(con.serializionDelegate).to.beIdenticalTo(delegate);
                expect(con.cacheFileURL).to.equal(fileUrl);
            });
            
        });
        
    });
    
    context(@"Convienance initializer", ^{
        
        it(@"return nil if name argument is not valid ", ^{
            NSString *name = nil;
            
            id obj = [[YMCachePersistenceController alloc] initWithCache:cache
                                                              modelClass:[NSObject class]
                                                                delegate:[TestDelegate new]
                                                                    name:name];
            expect(obj).to.beNil();
        });
        
        it(@"correctly set all initial values", ^{
            expect(controller.cache).to.beIdenticalTo(cache);
            expect(controller.modelClass).to.beIdenticalTo(modelClass);
            expect(controller.serializionDelegate).to.beIdenticalTo(delegate);
            
            NSURL *url = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                inDomains:NSUserDomainMask].firstObject;
            url = [url URLByAppendingPathComponent:fileName];
            expect(controller.cacheFileURL).to.equal(url);
        });
        
    });
    
    context(@"Saving Cache", ^{
        
        //it(@"Write ", <#^(void)block#>)
        
    });

    
    context(@"Restoring Cache", ^{
        //
    });

});

SpecEnd
