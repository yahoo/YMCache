//  Created by Adam Kaplan on 8/1/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Cache update notification. The userInfo dictionary in the notification contains two values:
 *  `kYFCacheUpdatedItemsUserInfoKey` containing key-value pairs that have been added/updated and
 *  `kYFCacheRemovedItemsUserInfoKey` containing keys that have been removed.
 *  The notification is essentially a delta between the last notification and the current cache state.
 */
extern NSString *const kYFCacheDidChangeNotification;
/**
 *  A key whose value is an NSDictionary of key-value pairs representing entries that have been added
 *  to or removed from the cache since the last notification.
 */
extern NSString *const kYFCacheUpdatedItemsUserInfoKey;
/**
 *  A key whose value is an NSSet of cache keys representing entries that have been removed from the
 *  cache since the last notification.
 */
extern NSString *const kYFCacheRemovedItemsUserInfoKey;

/** Type of a decider block for determining is an item is evictable.
 * @param key The key associated with value in the cache.
 * @param value The value of the item in the cache.
 * @param context Arbitrary user-provided context.
 */
typedef BOOL (^YMMemoryCacheEvictionDecider)(id key, id value, void *__nullable context);

typedef __nullable id (^YMMemoryCacheObjectLoader)(void);

/** The YMMemoryCache class declares a programatic interface to objects that manage ephemeral
 * associations of keys and values, similar to Foundation's NSMutableDictionary. The primary benefit
 * is that YMMemoryCache is designed to be safely accessed and mutated across multiple threads. It
 * offers specific optimizations for use in a multi-threaded environment, and hides certain functionality
 * that may be potentially unsafe or behave in unexpected ways for users accustomed to an NSDictionary.
 *
 * Implementation Notes:
 *
 * In general, non-mutating access (getters) execute synchronously and in parallel (by way of a concurrent
 * Grand Central Dispatch queue).
 * Mutating access (setters), on the other hand, take advantage of dispatch barriers to provide safe,
 * blocking writes while preserving in-band synchronous-like ordering behavior.
 *
 * In other words, getters behave as if they were run on a concurrent dispatch queue with respect to
 * each other. However, setters behave as though they were run on a serial dispatch queue with respect
 * to both getters and other setters.
 *
 * One side effect of this approach is that any access – even a non-mutating getter – may result in a
 * blocking call, though overall latency should be extremely low. Users should plan for this and try
 * to pull out all values at once (via `enumerateKeysAndObjectsUsingBlock`) or in the background.
 */
@interface YMMemoryCache : NSObject

/** Unique name identifying this cache, for example, in log messages. */
@property (nonatomic, readonly, nullable) NSString *name;

/** Maximum amount of time between evictions checks. Evictions may occur at any time up to this value.
 * Defaults to 600 seconds, or 10 minutes.
 */
@property (nonatomic) NSTimeInterval evictionInterval;

/** Maximum amount of time between notification of changes to cached items. After each notificationInterval,
 * the cache will post a notification named `kYFCacheDidChangeNotification` with userInfo that contains
 * `kYFCacheUpdatedItemsUserInfoKey` and `kYFCacheRemovedItemsUserInfoKey`. They keys contain information
 * that is as a complete delta of changes since the last notification.
 *
 * Defaults to 0, disabled.
 */
@property (nonatomic) NSTimeInterval notificationInterval;

/** Creates and returns a new memory cache using the specified name, but no eviction delegate.
 * @param name A unique name for this cache. Optional, helpful for debugging.
 * @return a new cache identified by `name`
 */
+ (instancetype)memoryCacheWithName:(nullable NSString *)name;

/** Creates and returns a new memory cache using the specified name, and eviction delegate.
 * @param name A unique name for this cache. Optional, helpful for debugging.
 * @param evictionDecider The eviction decider to use. See initWithName:evictionDecider:`
 * @return a new cache identified by `name`
 */
+ (instancetype)memoryCacheWithName:(nullable NSString *)name
                    evictionDecider:(nullable YMMemoryCacheEvictionDecider)evictionDecider;

- (instancetype)init NS_UNAVAILABLE; // use designated initializer

/** Initializes a newly allocated memory cache using the specified cache name, delegate & queue.
 * @param name (Optional) A unique name for this cache. Helpful for debugging.
 * @param evictionDecider (Optional) A block used to decide if an item (a key-value pair) is evictable.
 *  Clients return YES if the item can be evicted, or NO if the item should not be evicted from the cache.
 *  A nil evictionDevider is equivalent to returning NO for all items. The decider will execute on an
 *  arbitrary thread. The `context` parameter is NULL if the block is called due to the internal eviction
 *  timer expiring.
 * @return An initialized memory cache using name, delegate and delegateQueue.
 */
- (instancetype)initWithName:(nullable NSString *)name
             evictionDecider:(nullable YMMemoryCacheEvictionDecider)evictionDecider NS_DESIGNATED_INITIALIZER;

/** Returns the value associated with a given key.
 * @param key The key for which to return the corresponding value.
 * @return The value associated with `key`, or `nil` if no value is associated with key.
 */
- (nullable id)objectForKeyedSubscript:(nonnull id)key;

/** Get the value for the key. If value does not exist, invokes defaultLoader(), sets the result as
 the value for key, and returns it. In order to ensure consistency, the cache is locked when
 the defaultLoader block needs to be invoked.
 */
- (nullable id)objectForKey:(NSString *)key withDefault:(YMMemoryCacheObjectLoader)defaultLoader;

/** Sets the value associated with a given key.
 * @param obj The value for `key`
 * @param key The key for `value`. The key is copied (keys must conform to the NSCopying protocol).
 *  If `key` already exists in the cache, `object` takes its place. If `object` is `nil`, key is removed
 *  from the cache.
 */
- (void)setObject:(nullable id)obj forKeyedSubscript:(id<NSCopying>)key;

/** Adds to the cache the entries from a dictionary.
 * If the cache contains the same key as the dictionary, the cache's previous value object for that key
 * is replaced with new value object. All entries from dictionary are added to the cache at once such
 * that all of them are accessable by the next cache accessor, even if that accessor is triggered before
 * this method returns.
 *
 * All entries in the dictionary will be part of the next change notification event, even if an identical
 * key-value pair was already present in the cache.
 *
 * @param dictionary The dictionary from which to add entries.
 */
- (void)addEntriesFromDictionary:(NSDictionary *)dictionary;

/** Empties the cache of its entries.
 * Each key and corresponding value object is sent a release message.
 */
- (void)removeAllObjects;

/** Removes from the cache entries specified by keys in a given array.
 * If a key in `keys` does not exist, the entry is ignored. This method is more efficient at removing
 * the values for multiple keys than calling `setObject:forKeyedSubscript` multiple times.
 * @param keys An array of objects specifying the keys to remove.
 */
- (void)removeObjectsForKeys:(NSArray *)keys;

/** Returns a snapshot of all values in the cache.
 * The returned dictionary may differ from the actual cache as soon as it is returned. Because of this,
 * it is recommended to use `enumerateKeysAndObjectsUsingBlock:` for any operations that require a
 * guarantee that all items are operated upon (such as in low-memory situations).
 * @return A copy of the underlying dictionary upon which the cache is built.
 */
- (NSDictionary *)allItems;

/** Triggers an immediate (synchronous) check for exired items, and releases those items that are expired.
 * This method does nothing if no expirationDecider block was provided during initialization. The
 * evictionDecider block is run on the queue that this method is called on.
 */
- (void)purgeEvictableItems:(nullable void *)context;

@end

NS_ASSUME_NONNULL_END
