//  Created by Adam Kaplan on 1/4/21.
//  Copyright 2021 Verizon Media.
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

NS_ASSUME_NONNULL_END
