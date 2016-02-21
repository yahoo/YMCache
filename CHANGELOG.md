CHANGELOG
==================

1.3.1 ()
==================
* [Feature] Remove use of `@import` in order to support ObjC++

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
