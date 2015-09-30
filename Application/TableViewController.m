/**
 * Name: CrashReporter
 * Type: iOS application
 * Desc: iOS app for viewing the details of a crash, determining the possible
 *       cause of said crash, and reporting this information to the developer(s)
 *       responsible.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import "TableViewController.h"

#import "SectionHeaderView.h"

extern NSString * const kNotificationCrashLogsChanged;

@interface TableViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, retain) UITableView *tableView;
@end

@implementation TableViewController

@synthesize tableView = tableView_;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [tableView_ release];
    [super dealloc];
}

- (void)loadView {
    UIScreen *mainScreen = [UIScreen mainScreen];
    const CGRect screenBounds = [mainScreen bounds];

    // Add a table view.
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    //tableView.allowsSelectionDuringEditing = YES;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.backgroundColor = [UIColor colorWithRed:(239.0 / 255.0) green:(239.0 / 255.0) blue:(239.0 / 255.0) alpha:1.0];
    tableView.dataSource = self;
    tableView.delegate = self;
    self.tableView = tableView;

    // Add footer so that separators are not shown for "empty" cells.
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectZero];
    [tableView setTableFooterView:footerView];
    [footerView release];

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = [UIColor whiteColor];
    [view addSubview:tableView];
    self.view = view;

    [tableView release];
    [view release];
}

- (void)viewDidLoad {
    if (IOS_GTE(6_0)) {
        if (self.supportsRefreshControl) {
            // Add a refresh control.
            UITableView *tableView = [self tableView];
            tableView.alwaysBounceVertical = YES;
            UIRefreshControl *refreshControl = [[NSClassFromString(@"UIRefreshControl") alloc] init];
            [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
            [tableView addSubview:refreshControl];
            [refreshControl release];

            // Listen for changes to crash log files.
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:kNotificationCrashLogsChanged object:nil];
        }
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Actions

- (void)refresh:(id)sender {
    [self.tableView reloadData];

    if ([sender isKindOfClass:NSClassFromString(@"UIRefreshControl")]) {
        [sender endRefreshing];
    }
}

#pragma mark - Delegate (UITableViewDataSource)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark - Delegate (UITableViewDelegate)

- (NSString *)titleForHeaderInSection:(NSInteger)section {
    return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *key = [self titleForHeaderInSection:section];
    SectionHeaderView *headerView = [[SectionHeaderView alloc] initWithDefaultSize];
    headerView.textLabel.text = NSLocalizedString(key, nil);
    return [headerView autorelease];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [SectionHeaderView defaultHeight];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
