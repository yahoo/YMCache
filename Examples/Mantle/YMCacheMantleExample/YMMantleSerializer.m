//  Created by Adam Kaplan on 8/2/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import "YMMantleSerializer.h"

#import <Mantle/MTLModel.h>
#import <Mantle/MTLJSONAdapter.h>
#import <objc/message.h>

// Mantle 2 – unable to resolve 2.0-only version of the method.
// If you do not need Mantle 1.0 support, call -JSONDictionaryFromModel:error: directly.
typedef NSDictionary *(*mtl2_msgSend_t)(__strong id, SEL, __strong MTLModel *, NSError *__autoreleasing*);
mtl2_msgSend_t dictFromModel = (mtl2_msgSend_t)objc_msgSend;

static NSString *const kYMMantleTypeError = @"Mantle model object must be of type MTLModel<MTLJSONSerializing>";

@implementation YMMantleSerializer

- (nullable id)persistenceController:(YMCachePersistenceController *)controller
             modelFromJSONDictionary:(NSDictionary *)value
                               error:(NSError *__nullable*__nullable)error {
    NSParameterAssert(controller.modelClass);
    NSParameterAssert(value);
    
    return [MTLJSONAdapter modelOfClass:controller.modelClass fromJSONDictionary:value error:error];
}

- (nullable NSDictionary *)persistenceController:(YMCachePersistenceController *)controller
                         JSONDictionaryFromModel:(id)value
                                           error:(NSError *__nullable*__nullable)error {
    NSParameterAssert(controller);
    NSParameterAssert(value);
    
    if ([value isKindOfClass:[MTLModel class]] && [value conformsToProtocol:@protocol(MTLJSONSerializing)]) {
        static SEL mtl2sel = NULL;
        if (!mtl2sel) {
            mtl2sel = NSSelectorFromString(@"JSONDictionaryFromModel:error:");
        }
        
        // Mantle 2
        if ([MTLJSONAdapter respondsToSelector:mtl2sel]) {
            NSDictionary *jsonDict = dictFromModel([MTLJSONAdapter class], mtl2sel, value, error);
            return jsonDict;
        }

        // Mantle 1
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [MTLJSONAdapter JSONDictionaryFromModel:value];
#pragma clang diagnostic pop
    }

    if (error) {
        *error = [NSError errorWithDomain:@"YMMantleSerializer"
                                     code:0
                                 userInfo:@{ NSLocalizedDescriptionKey: kYMMantleTypeError }];
    }
    return nil;
}

@end