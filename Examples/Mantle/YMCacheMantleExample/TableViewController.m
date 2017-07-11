//  Created by Adam Kaplan on 8/2/15.
//  Copyright 2015 Yahoo.
//  Licensed under the terms of the MIT License. See LICENSE file in the project root.

#import "TableViewController.h"
#import "Stock.h"
#import "YMCachePersistenceController+MantleSupport.h"

static NSString *const kCacheName = @"stock.json";

@interface TableViewController ()
@property (nonatomic) YMMemoryCache *cache;
@property (nonatomic) YMCachePersistenceController *cacheController;
@property (nonatomic) NSArray *keys;
@property (nonatomic) dispatch_source_t timer;
@property (nonatomic) NSNumberFormatter *formatter;
@end

@implementation TableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.formatter = [NSNumberFormatter new];
    self.formatter.positivePrefix = @"+";
    self.formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    
    self.cache = [YMMemoryCache memoryCacheWithName:@"dog-cache"];
    self.cache.notificationInterval = 0.25;
    
    self.cacheController =[[YMCachePersistenceController alloc] initWithCache:self.cache
                                                             mantleModelClass:[Stock class]
                                                                         name:kCacheName];
    
    // Create randomizer using a repeating timer on a background thread
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC, 0.05 * NSEC_PER_SEC);

    srandom([NSDate timeIntervalSinceReferenceDate]);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.timer, ^{
        NSUInteger index = random() % weakSelf.keys.count;
        
        NSString *symbol = weakSelf.keys[index];
        Stock *old  = weakSelf.cache[symbol];
        double last = [old.last doubleValue] + (random() % 100) / 100.0;
        Stock *new = [[Stock alloc] initWithSymbol:old.symbol name:old.name last:@(last)];
        weakSelf.cache[symbol] = new;
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // load the cache (synchronously)
    NSError *error;
    [self.cacheController loadMemoryCache:&error];
    if (error) {
        NSLog(@"Memory cache error! %@", error);
    }
    
    self.keys = self.cache.allItems.allKeys;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cacheUpdated:)
                                                 name:kYFCacheDidChangeNotification
                                               object:self.cache];
    
    dispatch_resume(self.timer);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    dispatch_suspend(self.timer);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    // Trigger immediate synchronous cache cleanup
    [self.cache purgeEvictableItems:nil];
}

#pragma mark -


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.keys.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ReuseID" forIndexPath:indexPath];
    
    NSString *key = self.keys[indexPath.row];
    Stock *stock = self.cache[key];
    cell.textLabel.text = stock.name;
    cell.detailTextLabel.text = [self.formatter stringFromNumber:stock.last];
    
    return cell;
}

#pragma mark -

- (void)cacheUpdated:(NSNotification *)notification {
    NSDictionary *symbolUpdates = notification.userInfo;
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (NSString *symbol in symbolUpdates) {
        NSUInteger row = [self.keys indexOfObject:symbol];
        NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
        [indexPaths addObject:path];
    }
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
}

@end
