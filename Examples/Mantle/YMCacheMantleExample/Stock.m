//  Created by Adam Kaplan on 8/2/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import "Stock.h"

@implementation Stock

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:self];
}

- (instancetype)initWithSymbol:(NSString *)symbol name:(NSString *)name last:(NSNumber *)last {
    self = [super init];
    if (self) {
        _symbol = symbol;
        _name = name;
        _last = last;
    }
    return self;
}

@end
