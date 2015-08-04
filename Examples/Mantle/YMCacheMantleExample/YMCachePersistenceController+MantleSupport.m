//  Created by Adam Kaplan on 8/2/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import "YMCachePersistenceController+MantleSupport.h"
#import "YMMantleSerializer.h"

@implementation YMCachePersistenceController (MantleSupport)

+ (nonnull YMMantleSerializer *)mantleSerializer {
    static YMMantleSerializer *mantleSerializer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mantleSerializer = [YMMantleSerializer new];
    });
    return mantleSerializer;
}

- (nullable instancetype)initWithCache:(YMMemoryCache *)cache
                      mantleModelClass:(Class)modelClass
                               fileURL:(NSURL *)cacheFileURL {
    return [self initWithCache:cache modelClass:modelClass delegate:[[self class] mantleSerializer] fileURL:cacheFileURL];
}

- (nullable instancetype)initWithCache:(YMMemoryCache *)cache
                      mantleModelClass:(Class)modelClass
                                  name:(NSString *)cacheName {
    return [self initWithCache:cache modelClass:modelClass delegate:[[self class] mantleSerializer] name:cacheName];
}

@end
