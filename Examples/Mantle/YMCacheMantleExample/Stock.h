//  Created by Adam Kaplan on 8/2/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import <Mantle/Mantle.h>

@interface Stock : MTLModel <MTLJSONSerializing>

@property (nonatomic, readonly) NSString *symbol;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSNumber *last;

- (instancetype)initWithSymbol:(NSString *)symbol name:(NSString *)name last:(NSNumber *)last;

@end
