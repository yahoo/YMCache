# YMCache

YMCache is a lightweight object caching solution for iOS and Mac OS X that is designed for highly parallel access scenarios. YMCache presents a familiar interface emulating `NSMutableDictionary`, while internally leveraging Apple's [Grand Central Dispath](https://developer.apple.com/library/ios/documentation/Performance/Reference/GCD_libdispatch_Ref/index.html) technology to strike a balance between perforamnce and consistency.

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

We support the [CocoaPods](http://github.com/CocoaPods/CocoaPods) and [Carthage](https://github.com/carthage/carthage) distribution systems.

### CocoaPods

1. Add YMCache to your project's `Podfile`:

	```ruby
	target :MyApp do
	  pod 'YMCache', '~> 1.0'
	end
	```

2. Run `pod update` or `pod install` in your project directory.

### Carthage

1. Add YMCache to your project's `Cartfile`

    ```
    github "YMCache/YMCache"
    ```

2. Run `carthage update` in your project directory
3. Drag the appropriate `YMCache.framework` for your platform (located in `$PROJECT/Carthage/Build/`) into your application’s Xcode project, and add it to your target.
4. If you are building for iOS, a new `Run Script Phase` must be added to copy the framework. The instructions can be found on [Carthage's getting started instructions](https://github.com/carthage/carthage#getting-started)

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Support & Contributing

Report any bugs or send feature requests to the GitHub issues. Pull requests are very much welcomed. See [CONTRIBUTING](https://github.com/yahoo/YMCache/blob/master/CONTRIBUTING.md) for details.

## License

Apache 2.0 license. See the [LICENSE](https://github.com/yahoo/YMCache/blob/master/LICENSE) file for details.