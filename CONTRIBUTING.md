# Contribution Guidelines

## General Guidelines

- **Min iOS SDK**: 7.0
- **Language**: Swift-compatible Objective-C.
- **Tests**: Yes, please

#### Architecture guidelines

- Avoid singletons that don't encapsulate a finite resource
- Never expose mutable state
- Public API designed to be called safely from any thread
- Keep classes/methods sharply focused
- Stay generic

## Style Guide

#### Base style:

Please add new code to this project based on the following style guidelines:

- [Apple's Coding Guidelines for Cocoa](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CodingGuidelines/CodingGuidelines.html)
- [NYTimes Objective C Style Guidelines](https://github.com/NYTimes/objective-c-style-guide)

Among other things, these guidelines call for:

- Open braces on the same line; close braces on their own line
- Always using braces for `if` statements, even with single-liners
- No spaces in method signatures except after the scope (-/+) and between parameter segments
- Use dot-notation, not `setXXX`, for properties (e.g. `self.enabled = YES`)
- Asterisk should touch variable name, not type (e.g. `NSString *myString`)
- Prefer `static const` (or `static Type *const`) over `#define` for compile-time constants
- Prefer private properties to ‘naked’ instance variables wherever possible
- Prefer accessor methods over direct struct access (e.g. CGGeometry methods like `CGRectGetMinX()`)

#### Additions:

- Prefix all class names with `YM`
- Prefix all constants with `kYM`
- Group related methods with `#pragma mark`
- Keep as much of the API private as is practically possible