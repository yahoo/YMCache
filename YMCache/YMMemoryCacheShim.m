//
//  YMMemoryCacheShim.m
//  YMCache
//
//  Created by Amos Elmaliah on 2/2/16.
//  Copyright © 2016 Yahoo.com. All rights reserved.
//

#import "YMMemoryCacheShim.h"
#import <YMCache/YMCache-Swift.h>

NSString *const kYMShimCacheItemsChangedNotificationKey = @"kYFCacheItemsChangedNotificationKey";

@interface YMMemoryCacheShim ()
@property (nonatomic, strong) YMMemoryCacheSwift* swift;
@end

@implementation YMMemoryCacheShim

+ (instancetype)memoryCacheWithName:(NSString *)name {
    return [[self alloc] initWithName:name evictionDecider:nil];
}

+ (instancetype)memoryCacheWithName:(NSString *)name evictionDecider:(YMMemoryCacheShimEvictionDecider)evictionDecider {
    return [[self alloc] initWithName:name evictionDecider:evictionDecider];
}

- (instancetype)initWithName:(NSString *)cacheName
             evictionDecider:(YMMemoryCacheShimEvictionDecider)evictionDecider {
    
    if (self = [super init]) {
        
        _swift = [[YMMemoryCacheSwift alloc] initWithCacheName:cacheName
                                               evictionDecider:evictionDecider];
    }
    return self;
}

-(instancetype)init {
    return [self initWithName:nil evictionDecider:nil];
}

#pragma mark - Persistence

- (void)addEntriesFromDictionary:(NSDictionary *)dictionary {
    [_swift append:dictionary];
}

- (NSDictionary *)allItems {
    return [_swift allItems];
}

#pragma mark - Property Getters

-(NSString *)name {
    return _swift.name;
}

-(NSTimeInterval)evictionInterval {
    return _swift.evictionInterval;
}


-(NSTimeInterval)notificationInterval {
    return _swift.notificationInterval;
}

#pragma mark - Property Setters

- (void)setEvictionInterval:(NSTimeInterval)evictionInterval {
    [_swift setEvictionInterval:evictionInterval];
}

- (void)setNotificationInterval:(NSTimeInterval)notificationInterval {
    [_swift setNotificationInterval:notificationInterval];
}

#pragma mark - Keyed Subscripting

- (id)objectForKeyedSubscript:(id)key {
    return _swift[key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    _swift[key] = obj;
}

#pragma mark - Key-Value Management

- (void)removeAllObjects {
    [_swift removeAllObjects];
}

- (void)removeObjectsForKeys:(NSArray *)keys {
    [_swift removeObjectsForKeys:keys];
}

#pragma mark - Notification

- (void)sendPendingNotifications {
    [_swift sendPendingNotifications];
}

#pragma mark - Cleanup

- (void)purgeEvictableItems:(id __nullable)context {
    [_swift purgeEvictableItems:context];
}


@end
