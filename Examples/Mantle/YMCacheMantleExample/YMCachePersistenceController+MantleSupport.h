//  Created by Adam Kaplan on 8/2/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

@import YMCache;

@class YMMantleSerializer;
@class YMMemoryCache;

@interface YMCachePersistenceController (MantleSupport)

NS_ASSUME_NONNULL_BEGIN

+ (YMMantleSerializer *)mantleSerializer;

- (nullable instancetype)initWithCache:(YMMemoryCache *)cache
                      mantleModelClass:(Class)modelClass
                               fileURL:(NSURL *)cacheFileURL;

- (nullable instancetype)initWithCache:(YMMemoryCache *)cache
                      mantleModelClass:(Class)modelClass
                                  name:(NSString *)cacheName;

NS_ASSUME_NONNULL_END

@end
