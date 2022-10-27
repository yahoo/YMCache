//  Created by Adam Kaplan on 1/4/21.
//  Copyright 2021 Verizon Media.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

import Foundation

/// The YMMemoryCache class declares a programatic interface to objects that manage ephemeral
/// associations of keys and values, similar to Foundation's NSMutableDictionary. The primary benefit
/// is that YMMemoryCache is designed to be safely accessed and mutated across multiple threads. It
/// offers specific optimizations for use in a multi-threaded environment, and hides certain functionality
/// that may be potentially unsafe or behave in unexpected ways for users accustomed to an NSDictionary.
///
/// Implementation Notes:
///
/// In general, non-mutating access (getters) execute synchronously and in parallel (by way of a concurrent
/// Grand Central Dispatch queue).
/// Mutating access (setters), on the other hand, take advantage of dispatch barriers to provide safe,
/// blocking writes while preserving in-band synchronous-like ordering behavior.
///
/// In other words, getters behave as if they were run on a concurrent dispatch queue with respect to
/// each other. However, setters behave as though they were run on a serial dispatch queue with respect
/// to both getters and other setters.
///
/// One side effect of this approach is that any access – even a non-mutating getter – may result in a
/// blocking call, though overall latency should be extremely low. Users should plan for this and try
/// to pull out all values at once (via `enumerateKeysAndObjectsUsingBlock`) or in the background.
@objc public class YMMemoryCache: NSObject {

    /// Unique name identifying this cache, for example, in log messages.
    @objc public let name: String?

    private var _evictionInterval: TimeInterval = 0

    /// Maximum amount of time between evictions checks. Evictions may occur at any time up to this value.
    /// Defaults to 600 seconds, or 10 minutes.
    @objc public var evictionInterval: TimeInterval {
        set {
            evictionDeciderQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self._evictionInterval = newValue // set shadow value

                let source = self.newSourceTimer(replacing: self.evictionSourceTimer, interval: newValue, queue: self.evictionDeciderQueue) { [weak self] in
                        self?.purgeEvictableItems()
                }

                // Start source timer
                self.evictionSourceTimer = source
                source?.resume()
            }
        }
        get { _evictionInterval }
    }

    private var _notificationInterval: TimeInterval = 0

    /// Maximum amount of time between notification of changes to cached items. After each notificationInterval,
    /// the cache will post a notification named `kYFCacheDidChangeNotification` with userInfo that contains
    /// `kYFCacheUpdatedItemsUserInfoKey` and `kYFCacheRemovedItemsUserInfoKey`. They keys contain information
    /// that is as a complete delta of changes since the last notification.
    ///
    /// Defaults to 0, disabled.
    @objc public var notificationInterval: TimeInterval {
        set {
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self._notificationInterval = newValue

                let source = self.newSourceTimer(replacing: self.notificationSourceTimer, interval: newValue, queue: self.queue) { [weak self] in
                    self?.sendPendingNotifications()
                }
                self.notificationSourceTimer = source
                if let source = source {
                    source.resume()
                } else {
                    // Re-claim any resources no longer needed if notifications are disabled
                    self.itemsUpdatedPendingNotify.removeAll()
                    self.itemsRemovedPendingNotify.removeAll()
                }
            }
        }
        get { _notificationInterval }
    }

    /// Eviction decider block invoked during eviction runs
    private let evictionDecider: EvictionDecider?

    private let queue: DispatchQueue

    private lazy var evictionDeciderQueue = DispatchQueue(label: "com.yahoo.cache (eviction)")
    private var evictionSourceTimer: DispatchSourceTimer? = nil

    private var notificationSourceTimer: DispatchSourceTimer? = nil

    private var items = [AnyHashable: Any]()
    private var itemsUpdatedPendingNotify = [AnyHashable: Any]()
    private var itemsRemovedPendingNotify = Set<AnyHashable>()

    private static let kYFPrivateQueueKey = DispatchSpecificKey<UUID>()
    private let privateQueueNonce = UUID()

    /// Creates and returns a new memory cache using the specified name, but no eviction delegate.
    /// - Parameter name: Unique name for this cache. Optional, helpful for debugging.
    /// - Returns: New cache identified by `name`
    @objc public class func memoryCache(withName name: String?) -> YMMemoryCache {
        return memoryCache(withName: name, evictionDecider: nil)
    }

    /// Creates and returns a new memory cache using the specified name, but no eviction delegate.
    /// - Parameter name: Unique name for this cache. Optional, helpful for debugging.
    /// - Parameter evictionDecider: The eviction decider to use. See `evictionDecider` property.
    /// - Returns: New cache identified by `name`
    @objc public class func memoryCache(withName name: String?, evictionDecider: EvictionDecider? = nil) -> YMMemoryCache {
        return YMMemoryCache(withName: name, evictionDecider: evictionDecider)
    }

    /// Initializes a newly allocated memory cache using the specified cache name, delegate & queue.
    /// - Parameters:
    ///   - name: Unique name for this cache. Helpful for debugging.
    ///   - evictionDecider: block used to decide if an item (a key-value pair) is evictable. Clients return YES
    ///   if the item can be evicted, or NO if the item should not be evicted from the cache. A nil evictionDevider is
    ///   equivalent to returning NO for all items. The decider will execute on an arbitrary thread. The `context`
    ///   parameter is NULL if the block is called due to the internal eviction timer expiring.
    @objc public init(withName name: String? = nil, evictionDecider: EvictionDecider? = nil) {
        self.name = name
        self.evictionDecider = evictionDecider

        let queueName: String
        if let name = name {
            queueName = "com.yahoo.cache \(name)"
        } else {
            queueName = "com.yahoo.cache"
        }
        queue = DispatchQueue(label: queueName, attributes: .concurrent)
        queue.setSpecific(key: YMMemoryCache.kYFPrivateQueueKey, value: privateQueueNonce)

        super.init()

        if evictionDecider != nil {
            // Time interval to notify UI. This sets the overall update cadence for the app.
            evictionInterval = 600
        }
        notificationInterval = 0
    }

    deinit {
        if let source = evictionSourceTimer, !source.isCancelled {
            source.cancel()
        }

        if let source = notificationSourceTimer, !source.isCancelled {
            source.cancel()
        }
    }

    /// Returns the value associated with a given key
    @objc public subscript(key: AnyHashable) -> Any? {
        get { self[key, withDefault: nil] }
        set { self[key, withDefault: nil] = newValue }
    }

    /// Get the value for the key. If value does not exist, invokes defaultLoader(), sets the result as
    /// the value for key, and returns it. In order to ensure consistency, the cache is locked when
    /// the defaultLoader block needs to be invoked
    @objc public subscript(key: AnyHashable, withDefault loader: (() -> Any?)? = nil) -> Any? {
        get {
            assertNotPrivateQueue()

            var item: Any? = nil
            queue.sync {
                item = self.items[key]
            }

            // Stop here unless a loader was provided and item did not exist.
            // The loader phase requires more expensive dispatch barrier
            guard let loader = loader, item == nil else { return item }

            queue.sync(flags: .barrier) {
                // In order to ensure that read call are only blocking when they need
                // to be, this mutating block is executed with it's own barrier. This
                // means that we have a potential race condition if this method is called
                // in parallel with the same missing key. Resolve by checking again!
                item = self.items[key]
                guard item == nil else { return } // item may have been added concurrently in another thread (another loading block).

                if let item = loader() {
                    self.itemsRemovedPendingNotify.remove(key)
                    self.items[key] = item
                    self.itemsUpdatedPendingNotify[key] = item
                }
            }
            return item
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                if let newValue = newValue {
                    self.itemsRemovedPendingNotify.remove(key)
                    self.items[key] = newValue
                    self.itemsUpdatedPendingNotify[key] = newValue
                } else if self.items[key] != nil { // removing existing entry
                    self.itemsRemovedPendingNotify.insert(key)
                    self.items.removeValue(forKey: key)
                    self.itemsUpdatedPendingNotify.removeValue(forKey: key)
                }
            }
        }
    }

    /// Adds to the cache the entries from a dictionary.
    /// If the cache contains the same key as the dictionary, the cache's previous value object for that key
    /// is replaced with new value object. All entries from dictionary are added to the cache at once such
    /// that all of them are accessable by the next cache accessor, even if that accessor is triggered
    /// before this method returns.
    ///
    /// All entries in the dictionary will be part of the next change notification event, even if an identical
    /// key-value pair was already present in the cache.
    ///
    /// - Parameters:
    ///   - other: The dictionary from which to add entries
    @objc public func addEntries(fromDictionary other: [AnyHashable: Any]) {
        queue.async(flags: .barrier) {
            self.items.merge(other) { $1 }
            self.itemsUpdatedPendingNotify.merge(other) { $1 }
            other.keys.forEach { self.itemsRemovedPendingNotify.remove($0) }
        }
    }

    /** Empties the cache of its entries.
     * Each key and corresponding value object is sent a release message.
     */
    @objc public func removeAllObjects() {
        assertNotPrivateQueue()

        queue.sync(flags: .barrier) {
            self.items.keys.forEach { key in
                self.itemsUpdatedPendingNotify.removeValue(forKey: key)
                self.itemsRemovedPendingNotify.insert(key)
            }
            self.items.removeAll()
        }
    }

    /// Removes from the cache entries specified by keys in a given array.
    /// If a key in `keys` does not exist, the entry is ignored. This method is more efficient at removing
    /// the values for multiple keys than calling `setObject:forKeyedSubscript` multiple times.
    /// - Parameter keys: An array of objects specifying the keys to remove
    @objc public func removeObjects(forKeys keys: [AnyHashable]) {
        assertNotPrivateQueue()

        queue.sync(flags: .barrier) {
            keys.forEach { key in
                guard self.items[key] != nil else { return }
                self.itemsUpdatedPendingNotify.removeValue(forKey: key)
                self.itemsRemovedPendingNotify.insert(key)
                self.items.removeValue(forKey: key)
            }
        }
    }

    /// Returns a snapshot of all values in the cache.
    /// The returned dictionary may differ from the actual cache as soon as it is returned. Because of this,
    /// it is recommended to use `enumerateKeysAndObjectsUsingBlock:` for any operations that require a
    /// guarantee that all items are operated upon (such as in low-memory situations).
    /// - Returns:  A copy of the underlying dictionary upon which the cache is built.
    @objc public func allItems() -> [AnyHashable: Any] {
        assertNotPrivateQueue()

        var items = [AnyHashable: Any]()
        queue.sync {
            items = self.items
        }
        return items
    }

    /// Triggers an immediate (synchronous) check for exired items, and releases those items that are expired.
    /// This method does nothing if no expirationDecider block was provided during initialization. The
    /// evictionDecider block is run on the queue that this method is called on.
    @objc(purgeEvictableItems:) public func purgeEvictableItems(context: UnsafeMutableRawPointer? = nil) {
        // All external execution must have been dispatched to another queue so as to not leak the private queue
        // though the user-provided evictionDecider block.
        assertNotPrivateQueue()
        guard let evictionDecider = evictionDecider else { return }

        let frozenItems = allItems() // Trampoline to internal queue and copy items
        let purgableItems = frozenItems.filter { kv in
            let (key, value) = kv
            return evictionDecider(key, value, context)
        }.keys
        removeObjects(forKeys: Array(purgableItems))
    }
}

extension YMMemoryCache {

    /// Throws an assertion if the current queue is not the private queue of this instance
    private func assertPrivateQueue() {
        guard let key = DispatchQueue.getSpecific(key: YMMemoryCache.kYFPrivateQueueKey) else {
            return assertionFailure("Incorrect queue")
        }
        assert(key == privateQueueNonce, "Incorrect queue")
    }

    /// Throws an assertion if the current queue is the private queue of this instance
    private func assertNotPrivateQueue() {
        guard let key = DispatchQueue.getSpecific(key: YMMemoryCache.kYFPrivateQueueKey) else { return }
        assert(key != privateQueueNonce, "Potential deadlock: blocking call issued from current queue to the same queue")
    }

    /// Create a new Dispatch Source Timer instance.
    /// - Parameters:
    ///   - oldSource: An existing timer to be canceled
    ///   - interval: Repeat interval for the timer. If not greater than 0, the new timer is not set, but any old timer would be canceled
    ///   - queue: Dispatch queue to use for timer source invocations
    ///   - execute: The block to invoke on `queue` after each `interval`
    /// - Returns: The new source timer that was created, if any was. Call `resume()` on this timer to start it.
    private func newSourceTimer(replacing oldSource: DispatchSourceTimer?, interval: TimeInterval, queue: DispatchQueue, execute: @escaping () -> Void) -> DispatchSourceTimer? {
        // Cancel any scheduled work
        if let oldSource = oldSource {
            oldSource.cancel()
        }

        guard interval > .zero else { return nil } // nothing to schedule

        // Create a new source timer
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.setEventHandler(handler: execute)

        // Schedule repeating invocations
        let usecInterval = Int(interval * Double(USEC_PER_SEC))
        source.schedule(deadline: .now() + .microseconds(usecInterval), repeating: .microseconds(usecInterval))

        return source
    }

    /// Dispatch any pending change notifications
    private func sendPendingNotifications() {
        assertPrivateQueue()
        guard !itemsUpdatedPendingNotify.isEmpty && !itemsRemovedPendingNotify.isEmpty else {
            return
        }

        let updated = itemsUpdatedPendingNotify
        let removed = itemsRemovedPendingNotify
        itemsUpdatedPendingNotify.removeAll()
        itemsRemovedPendingNotify.removeAll()

        DispatchQueue.main.async { [weak self] in
            NotificationCenter.default.post(name: YMMemoryCache.CacheDidChangeNotification, object: self, userInfo: [
                YMMemoryCache.CacheUpdatedItemsUserInfoKey: updated,
                YMMemoryCache.CacheRemovedItemsUserInfoKey: removed
            ])
        }
    }
}

@objc public extension YMMemoryCache {
    /// Cache update notification. The userInfo dictionary in the notification contains two values:
    /// `kYFCacheUpdatedItemsUserInfoKey` containing key-value pairs that have been added/updated and
    /// `kYFCacheRemovedItemsUserInfoKey` containing keys that have been removed.
    /// The notification is essentially a delta between the last notification and the current cache state.
    @objc static var CacheDidChangeNotification: NSNotification.Name { NSNotification.Name.yfCacheDidChange }

    /// A key whose value is an NSDictionary of key-value pairs
    /// representing entries that have been added
    /// to or removed from the cache since the last notification.
    @objc static var CacheUpdatedItemsUserInfoKey: String { kYFCacheUpdatedItemsUserInfoKey }

    /// A key whose value is an NSSet of cache keys representing entries that have been removed from the
    /// cache since the last notification.
    @objc static var CacheRemovedItemsUserInfoKey: String { kYFCacheRemovedItemsUserInfoKey }

    /// Type of a decider block for determining is an item is evictable.
    /// - Parameters:
    ///  - key: The key associated with value in the cache
    ///  - value: The value of the item in the cache
    ///  - context: Arbitrary user-provided context
    typealias EvictionDecider = (_ key: Any, _ value: Any, _ context: UnsafeMutableRawPointer?) -> Bool
}
