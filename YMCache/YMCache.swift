//
//  YMCache.swift
//  YMCache
//
//  Created by Adam Kaplan on 8/14/15.
//  Modified by Amos Elmaliah on 2//16
//  Copyright (c) 2015 Yahoo, Inc. All rights reserved.
//

import Foundation

let CacheItemsChangedNotificationKey = kYMSheemCacheItemsChangedNotificationKey


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
public class YMMemoryCacheSwift : NSObject {
    
    
    public typealias Key = String
    public typealias Val = NSCopying
    /** Type of a decider block for determining is an item is evictable.
     * @param key The key associated with value in the cache.
     * @param value The value of the item in the cache.
     * @param context Arbitrary user-provided context.
     */
    public typealias EvictionDeciderType = (key: Key, val: Val) -> Bool
    let evictionDecider: EvictionDeciderType?
    
    /** Unique name identifying this cache, for example, in log messages. */
    public let name: String
    
    
    private func updateAferEvictionIntervalChanged() {
        if let queue = self.evictionQueue {
            dispatch_async(queue, _updateAferEvictionIntervalChanged)
        }
    }
    
    private func _updateAferEvictionIntervalChanged() {
        if let oldTimer = self.evictionTimer {
            dispatch_source_cancel(oldTimer)
            self.evictionTimer = nil
        }
        
        if self.evictionInterval == 0 {
            return
        }
        
        let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, evictionQueue)
        
        self.evictionTimer = timer
        
        dispatch_source_set_event_handler(timer, {[weak self] () -> Void in
            self?.purgeEvictableItems(nil)
            })
        
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, UInt64(self.evictionInterval) * NSEC_PER_SEC, 5 * NSEC_PER_SEC)
        
        dispatch_resume(timer)
    }
    
    /** Maximum amount of time between evictions checks. Evictions may occur at any time up to this value.
     * Defaults to 600 seconds, or 10 minutes.
     */
    public var evictionInterval: UInt64 = 0 {
        didSet {
            // Exit early if no eviction queue, which means this is not an evicting memory cache
            guard oldValue != evictionInterval else {
                evictionInterval = oldValue
                return
            }
            updateAferEvictionIntervalChanged()
        }
    }

    private func updateAfterNotificationIntervalChanged() {
        if let oldTimer = self.notificationTimer {
            dispatch_source_cancel(oldTimer)
            self.notificationTimer = nil
        }
        
        // Reset any pending notifications since they might be invalid for
        // notification based on the new interval
        self.pendingNotify = [Key: Val]()
        
        guard self.notificationInterval > 0 else {
            return
        }
        
        let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
        self.notificationTimer = timer;
        
        dispatch_source_set_event_handler(timer, {[weak self] () -> Void in
            self?.sendPendingNotifications()
            })
        
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, UInt64(notificationInterval) * NSEC_PER_SEC, 5 * NSEC_PER_SEC)
        
        dispatch_resume(timer)
    }
    
    /** Maximum amount of time between notification of changes to cached items. After each notificationInterval,
     * the cache will post a notification named `kYMSheemCacheItemsChangedNotificationKey` which includes as
     * user info, a dictionary containing all key-value pairs which have been added to the cache since
     * the previous notification was posted.
     *
     * Values which have been removed from the cache prior to the notification are not included in the
     * notification dictionary.
     *
     * Defaults to 0, disabled.
     */
    public var notificationInterval: NSTimeInterval = 0 {
        didSet {
            write { $0.updateAfterNotificationIntervalChanged() }
        }
    }
    
    /** Creates and returns a new memory cache using the specified name, but no eviction delegate.
     * @param name A unique name for this cache. Optional, helpful for debugging.
     * @return a new cache identified by `name`
     */
    public init(cacheName: String?, evictionDecider: EvictionDeciderType?) {
        name = cacheName ?? NSUUID().UUIDString
        
        // Initialize reader-writer queue
        
        let queueId = "com.yahoo.cache" + name
        
        self.queue = dispatch_queue_create(queueId.cStringUsingEncoding(NSUTF8StringEncoding)!,
            DISPATCH_QUEUE_CONCURRENT)
        
        // Initialize eviction system, if needed
        
        self.evictionDecider = evictionDecider
        if self.evictionDecider != nil {
            let evictionQueueId = queueId + ".eviction"
            
            let evictionQueue = dispatch_queue_create(evictionQueueId.cStringUsingEncoding(NSUTF8StringEncoding)!,
                DISPATCH_QUEUE_SERIAL)
            self.evictionQueue = evictionQueue
            
            self.evictionInterval = 600
        }
        else {
            evictionQueue = nil
        }
        
        super.init()
        
        updateAferEvictionIntervalChanged()

        updateAfterNotificationIntervalChanged()
        
    }

    deinit {
        if let timer = self.evictionTimer {
            if  0 == dispatch_source_testcancel(timer) {
                dispatch_source_cancel(timer)
            }
        }
        
        if let timer = self.notificationTimer {
            if  0 == dispatch_source_testcancel(timer) {
                dispatch_source_cancel(timer)
            }
        }
    }
    
    func write(block:(YMMemoryCacheSwift) -> () ) {
        dispatch_barrier_async(self.queue) {[weak self] in
            guard let it = self else {
                return
            }
            block(it)
        }
    }
    
    func read<T>(block:(YMMemoryCacheSwift)->(T?)) -> T? {
        var ret : T?
        dispatch_sync(queue) { () -> Void in
            ret = block(self)
        }
        return ret
    }
    
    /** Sets the value associated with a given key.
     * @param obj The value for `key`
     * @param key The key for `value`. The key is copied (keys must conform to the NSCopying protocol).
     *  If `key` already exists in the cache, `object` takes its place. If `object` is `nil`, key is removed
     *  from the cache.
     */
     /** Returns the value associated with a given key.
     * @param key The key for which to return the corresponding value.
     * @return The value associated with `key`, or `nil` if no value is associated with key.
     */
    public subscript(key: Key) -> Val? {
        // Synchronous (but parallel)
        get {
            return read { $0.items[key] }
        }
        
        // Concurrent (but not parallel)
        set(newVal) {
            write {
                $0.items[key] = newVal
                $0.pendingNotify[key] = newVal
            }
        }
    }
    
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
    public func addEntriesFromDictionary(dict: Dictionary<Key, Val>) {
        append(dict)
    }
    
    /** Adds to the cache the entries from a dictionary.
     * The same as addEntriesFromDictionary
     */
    public func append(dict:Dictionary<Key, Val>) {
        write {
            for (key,val) in dict {
                $0.items[key] = val
                $0.pendingNotify[key] = val
            }
        }
        
    }
    /** Empties the cache of its entries.
     * Each key and corresponding value object is sent a release message.
     */
    public func removeAllObjects() {
        removeAll()
    }
    public func removeAll() {
        write {
            $0.items.removeAll()
            $0.pendingNotify.removeAll()
        }
    }
    /** Removes from the cache entries specified by keys in a given array.
     * If a key in `keys` does not exist, the entry is ignored. This method is more efficient at removing
     * the values for multiple keys than calling `setObject:forKeyedSubscript` multiple times.
     * @param keys An array of objects specifying the keys to remove.
     */
    public func removeObjectsForKeys(keys: [Key]) {
        guard keys.isEmpty == false else {
            return
        }
        write {
            for key in keys {
                $0.items.removeValueForKey(key)
                $0.pendingNotify.removeValueForKey(key)
            }
        }
    }
    /** Returns a snapshot of all values in the cache.
     * The returned dictionary may differ from the actual cache as soon as it is returned. Because of this,
     * it is recommended to use `enumerateKeysAndObjectsUsingBlock:` for any operations that require a
     * guarantee that all items are operated upon (such as in low-memory situations).
     * @return A copy of the underlying dictionary upon which the cache is built.
     */
    public var allItems: Dictionary<Key, Val> {
        get {
            return read ({ $0.items })!
        }
    }
    
    // Notifications
    
    public func sendPendingNotifications() {
        // Assert private queue only
        
        guard self.pendingNotify.isEmpty == true else {
            return
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            let nc = NSNotificationCenter.defaultCenter()
            nc.postNotificationName(kYMSheemCacheItemsChangedNotificationKey, object: self, userInfo: pending)
        }
    }
    
    // Eviction
    
    /** Triggers an immediate (synchronous) check for exired items, and releases those items that are expired.
    * This method does nothing if no expirationDecider block was provided during initialization. The
    * evictionDecider block is run on the queue that this method is called on.
    */
    public func purgeEvictableItems(context:Context) {
        guard let evictionDecider = self.evictionDecider else {
            return
        }
        
        let keysToEvict = self.allItems
            .filter { evictionDecider(key: $0, val: $1, context:context) }
            .map { return $0.0 }
        
        self.removeObjectsForKeys(keysToEvict)
    }
    
    // Private
    
    private var items = [Key: Val]()
    private var pendingNotify = [Key: Val]()
    private let queue: dispatch_queue_t
    private let evictionQueue: dispatch_queue_t?
    private var evictionTimer: dispatch_source_t?
    private var notificationTimer: dispatch_source_t?
    
}
