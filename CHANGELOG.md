CHANGELOG
==================

2.0.0 (2016-09-13)
==================
* [Fix] The method `loadMemoryCache` now returns NSUInteger, in line with it's documented behavior.
* [Fix] Persistence manager initializer throws exception when the required parameters are nil. Previous implementation returned nil in release-mode, effectively swallowing the errors.
* [Pod] Bump minimum version for iOS to 8.0, OSX to 10.10. No known breaking changes on the old versions, we just don't test against them.
* [Refactor] Enable many more warnings and patch code to fix resulting warnings
* [Refactor] Remove deprecated methods from 1.x

1.3.1 (2016-03-06)
==================
* [Feature] Remove use of `@import` in order to support ObjC++
* [Pod] Reduce minimum OS X version to 10.8

1.3.0 (2015-10-19)
==================
* [Feature] Expose `NSDataWritingOptions` to clients (adds support for encryption on iOS)

1.2.2 (2015-10-12)
==================
* [Bug] iOS 7 crasher upon removing any single value from the cache (@e28eta)

1.2.1 (2015-10-09)
==================
* [Bug] Unable to clear value using nil value with keyed subscripting
* [Travis] Fix travis secret variable format

1.2.0 (2015-10-05)
==================
* [Feature] Delegate callbacks for auto-save pre/post/fail
* [Refactor] Reduce log messages and fix log message format
* [Travis] Log expiration of code signing certificate on build

1.1.0 (2015-09-21)
==================
* [Feature] Added support for tracking item removal through a new change notification. Deprecated existing notification.
* XCode 7 support

1.0.2 (2015-09-09)
==================
* [Bug] Changes are no longer broadcast repeatedly with the same items
* [Test] Increased code coverage in YMMemoryCache.m to 100%

1.0.1 (2015-08-10)
==================
* [Refactor] Tightened up notification/eviction timing and timer setup.
* [Test] Increased code coverage in YMMemoryCache.m to 99%.
* Improved the README with examples.

1.0.0 (2015-08-01)
==================
* Initial public release of library (@adamkaplan)
