# YMCache

[![build-status](https://github.com/yahoo/YMCache/workflows/YMCache%20CI/badge.svg?branch=master)](https://github.com/yahoo/YMCache/actions)

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![CocoaPods Compatible](https://img.shields.io/badge/CocoaPods-compatible-brightgreen.svg)](https://github.com/CocoaPods/CocoaPods)
[![GitHub license](https://img.shields.io/github/license/yahoo/YMCache.svg)](https://raw.githubusercontent.com/yahoo/YMCache/master/LICENSE.md)
[![Supported Platforms](https://img.shields.io/cocoapods/p/YMCache.svg)]()

---

YMCache is a lightweight object caching solution for iOS and macOS that is designed for highly parallel access scenarios. YMCache presents a familiar interface emulating `NSMutableDictionary`, while internally leveraging Apple's [Grand Central Dispatch](https://developer.apple.com/library/ios/documentation/Performance/Reference/GCD_libdispatch_Ref/index.html) technology to strike a balance between performance and consistency.

The Yahoo Finance iOS team uses YMCache to multiplex access to it's database of thousands of real-time stocks, which change in unpredictable ways, with an unpredictable cadence. YMCache helps relieve the complexity of multi-thread access to a central data store by providing a set of easy to understand [reader-writer](https://en.wikipedia.org/wiki/Readers–writer_lock) access semantics.

### Parallel Access

1. All read operations occur synchronously on the calling thread, but concurrently across all readers (as system resources allow).
2. All write operations occur asynchronously
3. Read operations initiated after a write operation will wait for the write to complete

The above rules allow for multiple readers, but a single writer. A nice result of this approach is that reads are serialized with respect to writes, enforcing a sensible order: you may read with the confidence that the expected data has been fully written.

### Features

- **Persistence**: save/load a cache from disk once, or at a defined interval
- **Eviction**: handle low memory situations in-band, using whatever logic suits your needs
- **Serialization**: arbitrary model transformations comes for free. You can use Mantle, straight NSJSONSerialization or any other format you can think up!
- **Bulk operations**: efficient multi-value reads/writes. (Bulk operations follow the [Parallel Access](#ParallelAccess) rules, but count as a single operation)

## SETUP

We support distribution through [CocoaPods](http://github.com/CocoaPods/CocoaPods) and [Swift Package Manager](https://swift.org/package-manager/).

### CocoaPods

1. Add YMCache to your project's `Podfile`:

	```ruby
	target :MyApp do
	  pod 'YMCache', '~> 1.0'
	end
	```

2. Run `pod update` or `pod install` in your project directory.

### SwiftPM

Add `.package(url: "https://github.com/yahoo/YMCache.git", from: "2.2.0")` to your `package.swift`

## Usage

#### Synopsis
```objc
YMMemoryCache *cache = [YMMemoryCache memoryCacheWithName:@"my-object-cache"];
cache[@"Key1"] = valueA;
MyVal *valueA = cache[@"Key1"];
[cache addEntriesFromDictionary:@{ @"Key2": value2 }];
NSDictionary *allItems = [cache allItems];
[cache removeAllObjects];
// cache = empty; allItems = @{ @"Key1": value1, @"Key2": value2 }
```
This cache is essentially a completely thread-safe NSDictionary with read-write order guarantees.

#### Eviction

##### Manual eviction
```objc
// Create memory cache with an eviction decider block, which will be triggered for each item in the cache whenever
// you call `-purgeEvictableItems:`.
YMMemoryCache *cache = [YMMemoryCache memoryCacheWithName:@"my-object-cache"
                                          evictionDecider:^(NSString *key, NewsStory *value, void *context) {
                                              return value.publishDate > [NSDate dateWithTimeIntervalSinceNow:-300];
                                          }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [cache purgeEvictableItems:nil];
    });
```

This example cache includes an eviction block which is called once after a 10 second delay. You are responsible for implementing the logic to decide which items are safe to evict. In this case, `NewsStory` models published more than 5 minutes ago will be purged from the cache. In this case, the eviction decider will be invoked on the main queue, because that is where `-purgeEvictableItems:` is called from.

##### Time-based eviction
```objc
YMMemoryCache *cache = [YMMemoryCache memoryCacheWithName:@"my-object-cache"
                                          evictionDecider:^(NSString *key, NewsStory *value, void *context) {
                                              return value.publishDate > [NSDate dateWithTimeIntervalSinceNow:-300];
                                          }];

cache.evictionInterval = 60.0; // trigger eviction every 60 seconds
```
This creates a cache with periodic time-based cache evictions every 60 seconds. Note that automatic invocations of the eviction decider execute on an arbitrary background thread. This approach can be combined with other manual eviction calls to provide a situations in which cache eviction is triggered on-demand, but at lease every N minutes.

##### Automatic eviction on low memory
```objc
// Create memory cache with an eviction decider block, which will be triggered for each item in the cache whenever
// you call `-purgeEvictableItems:`.
YMMemoryCache *cache = [YMMemoryCache memoryCacheWithName:@"my-object-cache"
                                          evictionDecider:^(NSString *key, NewsStory *value, void *context) {
                                              return value.publishDate > [NSDate dateWithTimeIntervalSinceNow:-300];
                                          }];

// Trigger in-band cache eviction during low memory events.
[[NSNotificationCenter defaultCenter] addObserver:cache
                                         selector:@selector(purgeEvictableItems:)
                                             name:UIApplicationDidReceiveMemoryWarningNotification
                                           object:nil];

// or, more commonly

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];

    // Trigger immediate synchronous cache cleanup
    [self.cache purgeEvictableItems:nil];
}
```
The eviction decider blocks that react to low memory situations will execute on the main thread because that is the only thread that sends low memory notifications or calls `-didReceiveMemoryWarning`.

#### Observing Changes
```objc
YMMemoryCache *cache = [YMMemoryCache memoryCacheWithName:@"my-object-cache"];

cache.notificationInterval = 0.5;

[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(cacheUpdated:)
                                             name:kYFCacheDidChangeNotification
                                           object:cache];

// from any thread, such as a network client on a background thread
cache[@"Key"] = value;

// within 0.5s (as per configuration) a notification will fire and call this:
- (void)cacheUpdated:(NSNotification *)notification {
    // Get a snapshot of all values that were added or replaced since the last notification
    NSDictionary *addedOrUpdated = notification.userInfo[kYFCacheUpdatedItemsUserInfoKey];
    // Get a set of all keys that were removed since the last notification
    NSSet *removedKeys = notification.userInfo[kYFCacheRemovedItemsUserInfoKey];
}
```

### File Encryption (iOS) and writing options

The `YMCachePersistenceManager` uses `NSData` to read and write data to disk. By default, we write atomically. You may control write options by setting the persistence manager's `fileWritingOptions` property before the next write.

### Examples

To run the example projects, clone the repo, and run `pod install` from one of the directories in Example.

#### Example: Mantle Serialization

It's very easy to use Mantle – version 1 or 2 – to serialize your cache to disk! Check out the pre-built, production-ready example in [Examples/Mantle](https://github.com/yahoo/YMCache/tree/master/Examples/Mantle).

## Support & Contributing

Report any bugs or send feature requests to the GitHub issues. Pull requests are very much welcomed. See [CONTRIBUTING](https://github.com/yahoo/YMCache/blob/master/CONTRIBUTING.md) for details.

## License

MIT license. See the [LICENSE](https://github.com/yahoo/YMCache/blob/master/LICENSE) file for details.
