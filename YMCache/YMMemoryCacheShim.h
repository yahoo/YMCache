//
//  YMMemoryCacheShim.h
//  YMCache
//
//  Created by Amos Elmaliah on 2/2/16.
//  Copyright © 2016 Yahoo.com. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kYMShimCacheItemsChangedNotificationKey;

typedef BOOL(^YMMemoryCacheShimEvictionDecider)(NSString * __nonnull, id <NSCopying> __nonnull, id __nullable);


@interface YMMemoryCacheShim : NSObject

@property (nonatomic, readonly, nullable) NSString *name;

@property (nonatomic) NSTimeInterval evictionInterval;

@property (nonatomic) NSTimeInterval notificationInterval;

+ (instancetype)memoryCacheWithName:(nullable NSString *)name;

+ (instancetype)memoryCacheWithName:(nullable NSString *)name
                    evictionDecider:(nullable YMMemoryCacheShimEvictionDecider)evictionDecider;

- (instancetype)initWithName:(nullable NSString *)name
             evictionDecider:(nullable YMMemoryCacheShimEvictionDecider)evictionDecider NS_DESIGNATED_INITIALIZER;

- (nullable id)objectForKeyedSubscript:(nonnull id)key;

- (void)setObject:(nullable id)obj forKeyedSubscript:(id<NSCopying>)key;

- (void)addEntriesFromDictionary:(NSDictionary *)dictionary;

- (void)removeAllObjects;

- (void)removeObjectsForKeys:(NSArray *)keys;

- (NSDictionary *)allItems;

- (void)purgeEvictableItems:(id __nullable)context;

@end

NS_ASSUME_NONNULL_END
