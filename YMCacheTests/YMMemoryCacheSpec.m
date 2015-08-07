//  Created by Adam Kaplan on 8/2/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import <YMCache/YMCache.h>

SpecBegin(YMMemoryCacheSpec)

fdescribe(@"YMMemoryCache", ^{
    
    NSDictionary *const cacheValues = @{ @"Key0": @"Value0",
                                         @"Key1": @"Value1",
                                         @"Key2": @"Value2" };
    
    static NSString *const cacheName = @"TestCache";
    
    __block YMMemoryCacheEvictionDecider decider;
    __block YMMemoryCache *emptyCache;
    __block YMMemoryCache *populatedCache;
    
    beforeEach(^{
        emptyCache = [YMMemoryCache memoryCacheWithName:cacheName];
        emptyCache.notificationInterval = 0.2;

        decider = ^BOOL(id key, id value, void *ctx) {
            return NO;
        };
        
        populatedCache = [YMMemoryCache memoryCacheWithName:cacheName evictionDecider:^BOOL(id key, id value, void *context) {
            return decider(key, value, context); // tests can swap this value out as needed.
        }];
        [populatedCache addEntriesFromDictionary:cacheValues];
    });
    
    afterEach(^{
        // Only YOU can prevent memory leaks!
        emptyCache = nil;
        populatedCache = nil;
        decider = NULL;
    });
    
    // Single Setter
    
    it(@"Should set values in order, via keyed subscripting", ^{
        emptyCache[@"key"] = @"Value!";
        expect(emptyCache[@"key"]).to.beIdenticalTo(@"Value!");
    });
    
    // Single Getter
    
    it(@"Should return nil when a key has no value", ^{
        expect(emptyCache[@"key"]).to.beNil();
    });
    
    context(@"Bulk setter", ^{
        
        it(@"Should do nothing on empty value dictionary", ^{
            emptyCache[@"Key"] = @"Wheee!";
            NSDictionary *dict; // can't pass nil directly; compiler warning due to __nonnull annotation
            [emptyCache addEntriesFromDictionary:dict];
            expect(emptyCache[@"Key"]).to.equal(@"Wheee!");
        });
        
        it(@"Should set all new values from a dictionary", ^{
            [emptyCache addEntriesFromDictionary:cacheValues];
            
            for (id key in cacheValues) {
                expect(emptyCache[key]).to.beIdenticalTo(emptyCache[key]);
            }
        });
        
        it(@"Should set all values from a dictionary, overriding existing", ^{
            NSMutableDictionary *updatesDict = [cacheValues mutableCopy];
            updatesDict[@"Key0"] = @"BORK!";
            updatesDict[@"Key2"] = @"ZONK!";
            updatesDict[@"Key3"] = @"Value3";
            
            [populatedCache addEntriesFromDictionary:updatesDict];
            
            for (id key in updatesDict) {
                expect(populatedCache[key]).to.beIdenticalTo(updatesDict[key]);
            }
        });
    });
    
    context(@"-removeAllObjects", ^{
        
        it(@"Should do nothing (not crash) on empty cache", ^{
            [emptyCache removeAllObjects];
        });
        
        it(@"Should remove all items", ^{
            [populatedCache removeAllObjects];
            
            for (id key in cacheValues) {
                expect(populatedCache[key]).to.beNil();
            }
        });
        
    });
    
    context(@"-removeObjectsForKeys:", ^{
        
        NSArray *nilArray; // can't pass nil directly; compiler warning due to __nonnull annotation
        
        it(@"Should do nothing (not crash) on empty cache", ^{
            [emptyCache removeObjectsForKeys:@[@"Key"]];
        });
        
        it(@"Should do nothing (not crash) on empty cache & empty key array", ^{
            [emptyCache removeObjectsForKeys:nilArray];
        });
        
        it(@"Should do nothing (not crash) on empty key array", ^{
            [populatedCache removeObjectsForKeys:nilArray];
            
            for (id key in cacheValues) {
                expect(populatedCache[key]).to.beIdenticalTo(cacheValues[key]);
            }
        });
        
        it(@"Should remove: single key in single-value cache", ^{
            id key = @"Key";
            emptyCache[key] = @"Val";
            
            [emptyCache removeObjectsForKeys:@[key]];
            
            expect(emptyCache[key]).to.beNil();
        });
        
        it(@"Should remove: single key in multi-value cache", ^{
            NSString *removedKey = cacheValues.allKeys.firstObject;
            [populatedCache removeObjectsForKeys:@[removedKey]];
            
            NSMutableDictionary *newValues = [cacheValues mutableCopy];
            [newValues removeObjectForKey:removedKey];
            
            expect(populatedCache[removedKey]).to.beNil();
            for (id key in newValues) {
                expect(populatedCache[key]).to.beIdenticalTo(cacheValues[key]);
            }
        });
        
        it(@"Should remove: multiple keys in multi-value cache", ^{
            [populatedCache removeObjectsForKeys:cacheValues.allKeys];
            
            for (id key in cacheValues) {
                expect(populatedCache[key]).to.beNil();
            }
        });
    });
    
    context(@"-allItems", ^{
        
        it(@"Should return empty dictionary from empty cache", ^{
            expect(emptyCache.allItems).to.beEmpty();
        });
        
        it(@"Should return all items from cache", ^{
            expect(populatedCache.allItems).to.equal(cacheValues);
        });
    });
    
    context(@"-purgeEvictableItems", ^{
        
        it(@"Should do nothing (not crash) on empty cache without decider", ^{
            [emptyCache purgeEvictableItems:NULL];
        });
        
        it(@"Should do nothing (not crash) on non-empty cache without decider", ^{
            for (id key in cacheValues) {
                emptyCache[key] = cacheValues[key];
            }
            [emptyCache purgeEvictableItems:NULL];
            for (id key in cacheValues) {
                expect(emptyCache[key]).to.beIdenticalTo(cacheValues[key]);
            }
        });
        
        it(@"Should do nothing on empty cache with decider", ^{
            __block BOOL deciderCalled = NO;
            decider = ^BOOL(id key, id value, void *ctx) {
                deciderCalled = YES;
                return NO;
            };
            [emptyCache purgeEvictableItems:NULL];
            expect(deciderCalled).to.beFalsy();
        });
        
        it(@"Should do nothing on non-empty cache with default (always NO) decider", ^{
            [populatedCache purgeEvictableItems:NULL];
            expect(populatedCache.allItems).to.equal(cacheValues);
        });
        
        it(@"Should remove all items from cache with an always YES decider", ^{
            decider = ^BOOL(id key, id value, void *ctx) {
                return YES;
            };
            [populatedCache purgeEvictableItems:NULL];
            expect(populatedCache.allItems).to.beEmpty();
        });
        
        it(@"Should remove some items from cache based on decider", ^{
            NSArray *keys = cacheValues.allKeys;
            NSArray *keysToRemove = [keys subarrayWithRange:NSMakeRange(0, 2)]; // 2 of 3
            NSArray *keysToKeep = [keys subarrayWithRange:NSMakeRange(2, keys.count - 2)];
            decider = ^BOOL(id key, id value, void *ctx) {
                return [keysToRemove containsObject:key];
            };
            [populatedCache purgeEvictableItems:NULL];
            
            for (id key in keysToKeep) { // test kept
                expect(populatedCache[key]).to.beIdenticalTo(cacheValues[key]);
            }
            
            for (id key in keysToRemove) { // test removed
                expect(populatedCache[key]).to.beNil();
            }
        });
        
        it(@"Should pass the eviction contexxt", ^{ // easy dispatch_time bug
            __block NSString *context;
            decider = ^BOOL(id key, id value, void *ctx) {
                context = (__bridge NSString *)(ctx);
                return NO;
            };
            
            NSString *notNullPtr = @"Not Null";
            [populatedCache purgeEvictableItems:(__bridge void * __nullable)(notNullPtr)];
            expect(context).will.beIdenticalTo(notNullPtr);
        });
    });
    
    context(@"-evictionInterval", ^{
        
        it(@"Should return default value if not set", ^{
            expect(populatedCache.evictionInterval).will.equal(600.0);
        });
        
        it(@"Should not evict after upon initialization", ^{ // easy dispatch_time bug
            __block BOOL deciderCalled = NO;
            decider = ^BOOL(id key, id value, void *ctx) {
                deciderCalled = YES;
                return NO;
            };
            
            [NSThread sleepForTimeInterval:0.25];
            expect(deciderCalled).to.beFalsy;
        });
        
        it(@"Should evict after interval", ^{
            __block BOOL deciderCalled = NO;
            decider = ^BOOL(id key, id value, void *ctx) {
                deciderCalled = YES;
                return NO;
            };
            
            NSTimeInterval interval = 0.5;
            populatedCache.evictionInterval = interval;
            expect(deciderCalled).will.beTruthy;
        });
        
        it(@"Should disable eviction property", ^{
            __block BOOL deciderCalled = NO;
            decider = ^BOOL(id key, id value, void *ctx) {
                deciderCalled = YES;
                return NO;
            };
            
            NSTimeInterval interval = 0.5;
            populatedCache.evictionInterval = interval;
            [NSThread sleepForTimeInterval:interval / 2.0];
            populatedCache.evictionInterval = 0;
            
            [NSThread sleepForTimeInterval:interval];
            expect(deciderCalled).to.beFalsy;
        });
        
        it(@"Should pass NULL for eviction contexxt", ^{ // easy dispatch_time bug
            __block void *context = "Not Null";
            decider = ^BOOL(id key, id value, void *ctx) {
                context = ctx;
                return NO;
            };
            
            NSTimeInterval interval = 0.5;
            populatedCache.evictionInterval = interval;
            expect(context).will.beNull;
        });
        
        it(@"Should pass NULL for eviction contexxt", ^{ // easy dispatch_time bug
            NSTimeInterval origInterval = emptyCache.evictionInterval;
            emptyCache.evictionInterval = 123.0;
            expect(emptyCache.evictionInterval).equal(origInterval);
        });
    });
    
    context(@"-sendPendingNotifications", ^{
        
        it(@"Should send notification shortly after -addEntriesFromDictionary", ^{
            __block NSNotification *notification;
            __block id observer;
            waitUntilTimeout(emptyCache.notificationInterval + 0.10, ^(DoneCallback done) {
                observer = [[NSNotificationCenter defaultCenter] addObserverForName:kYFCacheItemsChangedNotificationKey
                                                                                object:emptyCache
                                                                                 queue:[NSOperationQueue mainQueue]
                                                                            usingBlock:^(NSNotification *note) {
                                                                                notification = note;
                                                                                done();
                                                                            }];
                [emptyCache addEntriesFromDictionary:cacheValues];
            });
            
            expect(notification).toNot.beNil();
            expect(notification.userInfo).to.equal(cacheValues);
            
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        });
        
        it(@"Should send notification shortly after -setObject:forKeyedSubscript:", ^{
            __block NSNotification *notification;
            __block id observer;
            waitUntilTimeout(emptyCache.notificationInterval + 0.10, ^(DoneCallback done) {
                observer = [[NSNotificationCenter defaultCenter] addObserverForName:kYFCacheItemsChangedNotificationKey
                                                                             object:emptyCache
                                                                              queue:[NSOperationQueue mainQueue]
                                                                         usingBlock:^(NSNotification *note) {
                                                                             notification = note;
                                                                             done();
                                                                         }];
                emptyCache[@"Key"] = @"Value";
            });
            
            expect(notification.userInfo).to.equal(@{@"Key": @"Value"});
            
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        });
        
        it(@"Should send notification including multiple changes during the same period", ^{
            __block NSNotification *notification;
            __block id observer;
            waitUntilTimeout(emptyCache.notificationInterval + 0.10, ^(DoneCallback done) {
                observer = [[NSNotificationCenter defaultCenter] addObserverForName:kYFCacheItemsChangedNotificationKey
                                                                             object:emptyCache
                                                                              queue:[NSOperationQueue mainQueue]
                                                                         usingBlock:^(NSNotification *note) {
                                                                             notification = note;
                                                                             done();
                                                                         }];
                
                [emptyCache addEntriesFromDictionary:cacheValues];
                emptyCache[@"Key"] = @"Value";
            });
            
            NSMutableDictionary *d = [cacheValues mutableCopy];
            d[@"Key"] = @"Value";
            expect(notification.userInfo).to.equal([d copy]);
            
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        });
        
        it(@"Should NOT send notification after -removeAllObjects", ^{
            __block NSNotification *notification;
            id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kYFCacheItemsChangedNotificationKey
                                                                            object:populatedCache
                                                                             queue:[NSOperationQueue mainQueue]
                                                                        usingBlock:^(NSNotification *note) {
                                                                            notification = note;
                                                                        }];
            populatedCache.notificationInterval = 0.10;
            [populatedCache removeAllObjects];
            
            expect(notification).after(0.20).to.beNil();
            
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        });
        
        it(@"Should NOT send notification after -removeObjectsForKeys:", ^{
            __block NSNotification *notification;
            id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kYFCacheItemsChangedNotificationKey
                                                                            object:populatedCache
                                                                             queue:[NSOperationQueue mainQueue]
                                                                        usingBlock:^(NSNotification *note) {
                                                                            notification = note;
                                                                        }];
            populatedCache.notificationInterval = 0.10;
            [populatedCache removeObjectsForKeys:cacheValues.allKeys];
            
            expect(notification).after(0.20).to.beNil();
            
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        });
    });
    
    context(@"-notificationInterval", ^{
        
        it(@"Should return the default value after initalization", ^{
            expect(populatedCache.notificationInterval).to.equal(0.0);
        });
        
        it(@"Should return the new value after setting", ^{
            emptyCache.notificationInterval = 500.0;
            expect(emptyCache.notificationInterval).will.equal(500.0);
        });
        
        it(@"Should NOT send notification when interval is 0", ^{
            __block NSNotification *notification;
            id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kYFCacheItemsChangedNotificationKey
                                                                            object:populatedCache
                                                                             queue:[NSOperationQueue mainQueue]
                                                                        usingBlock:^(NSNotification *note) {
                                                                            notification = note;
                                                                        }];
            populatedCache.notificationInterval = 0.2;
            populatedCache.notificationInterval = 0.0;
            [populatedCache removeAllObjects];
            populatedCache.notificationInterval = 0.2;
        
            expect(notification).after(0.5).to.beNil();
            
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        });
        
        it(@"Should not include in notification changes that were made while notifications were disabled", ^{
            __block NSDictionary *userInfo;
            __block id observer;
            waitUntil(^(DoneCallback done) {
                observer = [[NSNotificationCenter defaultCenter] addObserverForName:kYFCacheItemsChangedNotificationKey
                                                                             object:populatedCache
                                                                              queue:[NSOperationQueue mainQueue]
                                                                         usingBlock:^(NSNotification *note) {
                                                                             userInfo = note.userInfo;
                                                                             done();
                                                                         }];
                
                populatedCache.notificationInterval = 0.0;
                [populatedCache removeAllObjects];
                
                populatedCache.notificationInterval = 0.2;
                populatedCache[@"Key"] = @"Value";
            });
            
            expect(userInfo).after(0.5).to.equal(@{@"Key": @"Value"});
            
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        });
        
        // Notification interval timing precision is pretty well covered by the -sendNotifications tests.
    });
});

SpecEnd
