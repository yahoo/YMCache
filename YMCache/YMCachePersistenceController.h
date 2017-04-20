//  Created by Adam Kaplan on 8/1/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class YMCachePersistenceController;

@protocol YMSerializationDelegate <NSObject>

- (nullable id)persistenceController:(YMCachePersistenceController *)controller modelFromJSONDictionary:(NSDictionary *)value
                               error:(NSError * _Nullable * _Nullable)error;

- (nullable NSDictionary *)persistenceController:(YMCachePersistenceController *)controller JSONDictionaryFromModel:(id)value
                                           error:(NSError * _Nullable * _Nullable)error;

@optional

/**
 *  Optional. Invoked immediately prior to saving the memory cache to disk.  This method will only be
 *  invoked due to expiration of the `saveInterval`, not if `saveMemoryCache:` is called.
 *
 *  @param controller Cache persistence controller
 */
- (void)persistenceControllerWillSaveMemoryCache:(YMCachePersistenceController *)controller;

/**
 *  Optional. Invoked immediately after successfully saving the memory cache to disk. This method will
 *  only be invoked due to expiration of the `saveInterval`, not if `saveMemoryCache:` is called.
 *
 *  @param controller Cache persistence controller
 */
- (void)persistenceControllerDidSaveMemoryCache:(YMCachePersistenceController *)controller;

/**
 *  Optional. Invoked immediately after failing to save the memory cache to disk. This method will
 *  only be invoked due to expiration of the `saveInterval`, not if `saveMemoryCache:` is called.
 *
 *  @param controller   Cache persistence controller
 *  @param error        The first error that was encountered
 */
- (void)persistenceController:(YMCachePersistenceController *)controller didFailToSaveMemoryCacheWithError:(NSError *)error;

@end

@class YMMemoryCache;

@interface YMCachePersistenceController : NSObject

/** The cache from which data will be loaded into or persisted from. */
@property (nonatomic, readonly) YMMemoryCache *cache;

/** The class of the items contained in the cache. */
@property (nonatomic, readonly) Class modelClass;

/** The instance used to serialize and de-serialize models */
@property (nonatomic, readonly) id<YMSerializationDelegate>serializionDelegate;

/** The URL of the file on disk from which cache data will be loaded from or written into. */
@property (nonatomic, readonly) NSURL *cacheFileURL;

/** The last error, if any, encountered during an automatic save operation. */
@property (nonatomic, readonly) NSError *lastSaveError;

/** The interval after which  `saveMemoryCache` will be automatically called. Set to 0 or negative to disable automatic saving. */
@property (nonatomic) NSTimeInterval saveInterval;

/** The options to pass to `-[NSData writeToFile:options:error:]` when saving the cache to disk. Default
 *  is `NSDataWritingAtomic`.
 */
@property (nonatomic) NSDataWritingOptions fileWritingOptions;

- (instancetype)init NS_UNAVAILABLE;

/** Returns a directory suitable for cache file operations.
 * @return A directory suitable for cache file operations, or nil if such a directory could not be located.
 */
+ (NSURL *)defaultCacheDirectory;

/** Creates and returns a new cache persistence manager using `cacheDirectoryURL` as the file storage
 * URL for all load/save operations.
 * @param modelClass    Required. The class of the items that will be stored in the cache. Currently only
 *  homogenously typed caches are supported.
 * @param cache         Required. The cache instance from which data shall be loaded into or saved from.
 * @param serializionDelegate   Required. the object responsible for serializing and de-serializing models
 * @param cacheFileURL  Required. The url on disk to use for saving and loading caches.
 * @return a new cache persistence manager or nil if `cacheDirectoryURL` was omitted and no suitable
 *  cache directory could be located.
 */
- (nullable instancetype)initWithCache:(YMMemoryCache *)cache
                            modelClass:(Class)modelClass
                              delegate:(id<YMSerializationDelegate>)serializionDelegate
                               fileURL:(NSURL *)cacheFileURL NS_DESIGNATED_INITIALIZER;

/** Creates and returns a new cache persistence manager using `cacheName` as the file name in the default
 * storage directory for all load/save operations.
 * @param modelClass    Required. The class of the items that will be stored in the cache. Currently only
 *  homogenously typed caches are supported.
 * @param cache         Required. The cache instance from which data shall be loaded into or saved from.
 * @param serializionDelegate   the object responsible for serializing and de-serializing models
 * @param cacheName     Required. The name of the cache file on disk to use for saving and loading.
 * @return a new cache persistence manager or nil if `cacheDirectoryURL` was omitted and no suitable
 *  cache directory could be located.
 * @see `defaultCacheDirectory`
 */
- (nullable instancetype)initWithCache:(YMMemoryCache *)cache
                            modelClass:(Class)modelClass
                              delegate:(id<YMSerializationDelegate>)serializionDelegate
                                  name:(NSString *)cacheName;

/** Loads the specified cache file from disk, parses it, and adds all items to the provided memory cache.
 * @param error If there is an error loading the data, upon return contains an NSError object that
 *  describes the problem.
 * @return The number of items loaded from the cache file and added to the memory cache. Zero if
 *  memoryCache or filename are not valid.
 */
- (NSUInteger)loadMemoryCache:(NSError * __autoreleasing *)error;

/** Saves the memory cache to the specified location on disk.
 * @param error If there is an error writing the data, upon return contains an NSError object that
 *  describes the problem.
 * @return True if the memory cache was written to disk. False if an error occurred or if either
 *  memoryCache or filename are not valid.
 */
- (BOOL)saveMemoryCache:(NSError * __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
