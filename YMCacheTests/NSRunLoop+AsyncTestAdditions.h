//  Created by Adam Kaplan on 8/2/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.


#import <Foundation/Foundation.h>

@interface NSRunLoop (AsyncTestAdditions)

- (void)runContinuouslyForInterval:(NSTimeInterval)timeout;

- (void)runUntilNonNil:(id *)objPtr timeout:(NSTimeInterval)timeout;

- (void)runUntilTrue:(BOOL(^)())block timeout:(NSTimeInterval)timeout;

@end
