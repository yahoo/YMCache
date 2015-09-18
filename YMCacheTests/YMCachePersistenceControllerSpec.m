//  Created by Adam Kaplan on 9/9/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import <YMCache/YMMemoryCache.h>
#import <YMCache/YMCachePersistenceController.h>

@interface TestDelegate : NSObject <YMSerializationDelegate>
@end
@implementation TestDelegate
- (id)persistenceController:(YMCachePersistenceController *)controller
    modelFromJSONDictionary:(NSDictionary *)value
                      error:(NSError **)error {
    return nil;
}

- (NSDictionary *)persistenceController:(YMCachePersistenceController *)controller
                JSONDictionaryFromModel:(id)value
                                  error:(NSError **)error {
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
    
    context(@"Default initializer", ^{
        
        it(@"return nil if arguments are not valid", ^{
            id obj;

            YMMemoryCache *cache = nil;
            Class class = [NSObject class];
            id<YMSerializationDelegate> delegate = [TestDelegate new];
            NSURL *fileUrl = [NSURL URLWithString:@"file:///"];
            
            obj = [[YMCachePersistenceController alloc] initWithCache:cache
                                                           modelClass:class
                                                             delegate:delegate
                                                              fileURL:fileUrl];
            expect(obj).to.beNil();
            
            cache = [[YMMemoryCache alloc] initWithName:@"Name" evictionDecider:nil];
            class = nil;
            obj = [[YMCachePersistenceController alloc] initWithCache:cache
                                                           modelClass:class
                                                             delegate:delegate
                                                              fileURL:fileUrl];
            expect(obj).to.beNil();

            class = [NSObject class];
            delegate = nil;
            obj = [[YMCachePersistenceController alloc] initWithCache:cache
                                                           modelClass:class
                                                             delegate:delegate
                                                              fileURL:fileUrl];
            expect(obj).to.beNil();
            
            delegate = [TestDelegate new];
            fileUrl = nil;
            obj = [[YMCachePersistenceController alloc] initWithCache:cache
                                                           modelClass:class
                                                             delegate:delegate
                                                              fileURL:fileUrl];
            expect(obj).to.beNil();
        });
        
        it(@"correctly set all initial values", ^{
            YMMemoryCache *cache = [[YMMemoryCache alloc] initWithName:@"Name" evictionDecider:nil];
            Class class = [NSObject class];
            id<YMSerializationDelegate> delegate = [TestDelegate new];
            NSURL *fileUrl = [NSURL URLWithString:@"file:///"];
            
            YMCachePersistenceController *con = [[YMCachePersistenceController alloc] initWithCache:cache
                                                                                         modelClass:class
                                                                                           delegate:delegate
                                                                                            fileURL:fileUrl];
            expect(con.cache).to.beIdenticalTo(cache);
            expect(con.modelClass).to.beIdenticalTo(class);
            expect(con.serializionDelegate).to.beIdenticalTo(delegate);
            expect(con.cacheFileURL).to.equal(fileUrl);
        });
        
    });
    
    context(@"Convienance initializer", ^{
        
        it(@"return nil if name argument is not valid ", ^{
            YMMemoryCache *cache = [[YMMemoryCache alloc] initWithName:@"Name" evictionDecider:nil];
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
