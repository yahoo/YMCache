//  Created by Adam Kaplan on 8/1/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import "YMMemoryCache.h"

#define AssertPrivateQueue \
NSAssert(dispatch_get_specific(kYFPrivateQueueKey) == (__bridge void *)self, @"Wrong Queue")

#define AssertNotPrivateQueue \
NSAssert(dispatch_get_specific(kYFPrivateQueueKey) != (__bridge void *)self, @"Potential deadlock: blocking call issues from current queue, to current queue")

NSString *const kYFCacheItemsChangedNotificationKey = @"kYFCacheItemsChangedNotificationKey";

CFStringRef kYFPrivateQueueKey = CFSTR("kYFPrivateQueueKey");

@interface YMMemoryCache ()
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) dispatch_source_t notificationTimer;
@property (nonatomic) dispatch_source_t evictionTimer;
@property (nonatomic) NSMutableDictionary *items;
@property (nonatomic) NSMutableDictionary *pendingNotify;

@property (nonatomic, strong) YMMemoryCacheEvictionDecider evictionDecider;
@property (nonatomic) dispatch_queue_t evictionDeciderQueue;
@end

@implementation YMMemoryCache

#pragma mark - Lifecycle

+ (instancetype)memoryCacheWithName:(NSString *)name {
    return [[self alloc] initWithName:name evictionDecider:nil];
}

+ (instancetype)memoryCacheWithName:(NSString *)name evictionDecider:(YMMemoryCacheEvictionDecider)evictionDecider {
    return [[self alloc] initWithName:name evictionDecider:evictionDecider];
}

- (instancetype)initWithName:(NSString *)cacheName evictionDecider:(YMMemoryCacheEvictionDecider)evictionDecider {
    
    if (self = [super init]) {
        
        NSString *queueName = @"com.yahoo.cache";
        if (cacheName) {
            _name = cacheName;
            queueName = [queueName stringByAppendingFormat:@" %@", cacheName];
        }
        _queue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_CONCURRENT);
        dispatch_queue_set_specific(_queue, kYFPrivateQueueKey, (__bridge void *)self, NULL);
        
        if (evictionDecider) {
            _evictionDecider = evictionDecider;
            NSString *evictionQueueName = [queueName stringByAppendingString:@" (eviction)"];
            _evictionDeciderQueue = dispatch_queue_create([evictionQueueName UTF8String], DISPATCH_QUEUE_CONCURRENT);
            
            // Time interval to notify UI. This sets the overall update cadence for the app.
            [self setEvictionInterval:600.0];
        }
        
        [self setNotificationInterval:0.0];
        
        _items = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Persistence

- (void)addEntriesFromDictionary:(NSDictionary *)dictionary {
    dispatch_barrier_async(self.queue, ^{
        [self.items addEntriesFromDictionary:dictionary];
        [self.pendingNotify addEntriesFromDictionary:dictionary];
    });
}

- (NSDictionary *)allItems {
    AssertNotPrivateQueue;
    
    __block NSDictionary *items;
    dispatch_sync(self.queue, ^{
        items = [self.items copy];
    });
    
    return items;
}

#pragma mark - Property Setters

- (void)setEvictionInterval:(NSTimeInterval)evictionInterval {
    if (!_evictionDeciderQueue) { // abort if this instance was not configured with an evictionDecider
        return;
    }
    
    dispatch_barrier_async(_evictionDeciderQueue, ^{
        _evictionInterval = evictionInterval;
        
        if (_evictionTimer) {
            dispatch_source_cancel(_evictionTimer);
            _evictionTimer = nil;
        }
        
        if (evictionInterval > 0) {
            _evictionTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _evictionDeciderQueue);
            
            dispatch_source_set_timer(_evictionTimer,
                                      dispatch_time(DISPATCH_TIME_NOW, _evictionInterval * NSEC_PER_SEC),
                                      _evictionInterval * NSEC_PER_SEC,
                                      5.0 * NSEC_PER_SEC);
            
            __weak typeof(self) weakSelf = self;
            dispatch_source_set_event_handler(_evictionTimer, ^{ [weakSelf purgeEvictableItems:NULL]; });
            
            dispatch_resume(_evictionTimer);
        }
    });
}

- (void)setNotificationInterval:(NSTimeInterval)notificationInterval {
    dispatch_barrier_async(self.queue, ^{
        _notificationInterval = notificationInterval;
        
        if (_notificationTimer) {
            dispatch_source_cancel(_notificationTimer);
            _notificationTimer = nil;
        }
        
        if (_notificationInterval > 0) {
            _pendingNotify = [NSMutableDictionary dictionary];
            
            _notificationTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
            
            dispatch_source_set_timer(_notificationTimer,
                                      dispatch_time(DISPATCH_TIME_NOW, _notificationInterval * NSEC_PER_SEC),
                                      _notificationInterval * NSEC_PER_SEC,
                                      0.15 * NSEC_PER_SEC);
            
            __weak typeof(self) weakSelf = self;
            dispatch_source_set_event_handler(_notificationTimer, ^{ [weakSelf sendPendingNotifications]; });
            
            dispatch_resume(_notificationTimer);
        }
        else {
            _pendingNotify = nil;
        }
    });
}

#pragma mark - Keyed Subscripting

- (id)objectForKeyedSubscript:(id)key {
    AssertNotPrivateQueue;
    
    __block id item;
    dispatch_sync(self.queue, ^{
        item = self.items[key];
    });
    return item;
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    NSParameterAssert(key);
    NSParameterAssert(obj); // The collections will assert, but fail earlier to aid in async debugging
    
    __weak typeof(self) weakSelf = self;
    dispatch_barrier_async(self.queue, ^{
        weakSelf.items[key] = obj;
        weakSelf.pendingNotify[key] = obj;
    });
}

#pragma mark - Key-Value Management

- (void)removeAllObjects {
    AssertNotPrivateQueue;
    
    dispatch_barrier_sync(self.queue, ^{
        [self.items removeAllObjects];
        [self.pendingNotify removeAllObjects];
    });
}

- (void)removeObjectsForKeys:(NSArray *)keys {
    AssertNotPrivateQueue;
    
    if (!keys.count) {
        return;
    }
    
    dispatch_barrier_sync(self.queue, ^{
        [self.items removeObjectsForKeys:keys];
        [self.pendingNotify removeObjectsForKeys:keys];
    });
}

#pragma mark - Notification

- (void)sendPendingNotifications {
    NSAssert([NSThread isMainThread], @"Main thread only");
    
    __block NSDictionary *pending;
    dispatch_sync(self.queue, ^{ // does not require a barrier since setObject: is the only other mutator
        if (_pendingNotify.count > 0) {
            pending = [self.pendingNotify copy];
            self.pendingNotify = [NSMutableDictionary dictionary];
        }
    });
    
    if (pending.count > 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kYFCacheItemsChangedNotificationKey
                                                            object:self
                                                          userInfo:pending];
    }
}

#pragma mark - Cleanup

- (void)purgeEvictableItems:(void *)context {
    // All external execution must have been dispatched to another queue so as to not leak the private queue
    // though the user-provided evictionDecider block.
    AssertNotPrivateQueue;
    
    // Don't clean up if no expiration decider block
    if (!self.evictionDecider) {
        return;
    }
    
    NSDictionary *items = self.allItems; // sync & safe
    YMMemoryCacheEvictionDecider evictionDecider = self.evictionDecider;
    NSMutableArray *itemKeysToPurge = [NSMutableArray new];
    
    for (id key in items) {
        id value = items[key];
        
        BOOL shouldEvict = evictionDecider(key, value, context);
        if (shouldEvict) {
            [itemKeysToPurge addObject:key];
        }
    }
    
    [self removeObjectsForKeys:itemKeysToPurge];
}

@end
