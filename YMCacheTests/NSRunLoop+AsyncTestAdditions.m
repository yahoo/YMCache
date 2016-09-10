//  Created by Adam Kaplan on 8/2/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import "NSRunLoop+AsyncTestAdditions.h"

@implementation NSRunLoop (AsyncTestAdditions)

- (void)runContinuouslyForInterval:(NSTimeInterval)timeout {
    id neverTrue = nil;
    
    [self runUntilNonNil:&neverTrue timeout:timeout];
}

- (void)runUntilNonNil:(id __autoreleasing *)objPtr timeout:(NSTimeInterval)timeout {
    NSParameterAssert(objPtr);
    if (!objPtr) {
        return;
    }
    
    NSDate *stopDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    
    NSTimeInterval stopInterval = stopDate.timeIntervalSinceReferenceDate;

    while (!*objPtr && stopInterval >= [NSDate date].timeIntervalSinceReferenceDate) {
        [self runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
    }
}

- (void)runUntilTrue:(BOOL(^)())block timeout:(NSTimeInterval)timeout {
    NSParameterAssert(block);
    if (!block) {
        return;
    }
    
    NSDate *stopDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    
    NSTimeInterval stopInterval = stopDate.timeIntervalSinceReferenceDate;
    
    while (!block() && stopInterval >= [NSDate date].timeIntervalSinceReferenceDate) {
        [self runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
    }
}

@end
