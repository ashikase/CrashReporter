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

#import <TechSupport/TechSupport.h>
#import "SectionHeaderView.h"
#import "TableViewCell.h"

extern NSString * const kNotificationCrashLogsChanged;

@interface TableViewController ()
@property (nonatomic, retain) UITableView *tableView;
@end

@implementation TableViewController

@synthesize tableView = tableView_;

+ (Class)cellClass {
    return nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [tableView_ release];
    [super dealloc];
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        // Set title for back button.
        NSString *title = NSLocalizedString(@"BACK", nil);
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain
            target:nil action:NULL];
        [[self navigationItem] setBackBarButtonItem:buttonItem];
        [buttonItem release];
    }
    return self;
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
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
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

- (void)helpButtonTapped:(UIButton *)button {
    [self presentHelpForSection:button.tag];
}

- (void)refresh:(id)sender {
    [self.tableView reloadData];

    if ([sender isKindOfClass:NSClassFromString(@"UIRefreshControl")]) {
        [sender endRefreshing];
    }
}

#pragma mark - Help

- (void)presentHelpForName:(NSString *)name {
    NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"html" subdirectory:@"Documentation"];
    if (url != nil) {
        TSHTMLViewController *controller = [[TSHTMLViewController alloc] initWithURL:url];
        controller.title = NSLocalizedString(name, nil);
        [self.navigationController pushViewController:controller animated:YES];
        [controller release];
    } else {
        NSLog(@"ERROR: Unable to obtain URL for help file \"%@\".", name);
    }
}

- (void)presentHelpForSection:(NSInteger)section {
    NSString *name = [self titleForHeaderInSection:section];
    [self presentHelpForName:name];
}

#pragma mark - Other

- (NSArray *)arrayForSection:(NSInteger)section {
    return nil;
}

- (NSDate *)referenceDate {
    return nil;
}

- (NSString *)titleForEmptyCell {
    return @"NONE";
}

- (NSString *)titleForHeaderInSection:(NSInteger)section {
    return nil;
}

#pragma mark - Delegate (UITableViewDataSource)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *array = [self arrayForSection:section];
    return [array count] ?: 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *array = [self arrayForSection:indexPath.section];
    if ([array count] > 0) {
        Class klass = [[self class] cellClass];
        NSString *reuseIdentifier = NSStringFromClass(klass);
        TableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
        if (cell == nil) {
            cell = [[[klass alloc] initWithReuseIdentifier:reuseIdentifier] autorelease];
        }
        cell.referenceDate = [self referenceDate];
        cell.showsTopSeparator = (indexPath.row == 0);
        [cell configureWithObject:[array objectAtIndex:indexPath.row]];
        return cell;
    } else {
        NSString * const reuseIdentifier = @"EmptyCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier] autorelease];
            cell.backgroundColor = [UIColor clearColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UILabel *label = cell.textLabel;
            label.font = [UIFont boldSystemFontOfSize:15.0];
            label.textColor = [UIColor colorWithRed:(109.0 / 255.0) green:(109.0 / 255.0) blue:(114.0 / 255.0) alpha:1.0];
            label.text = NSLocalizedString([self titleForEmptyCell], nil);
        }
        return cell;
    }
}

#pragma mark - Delegate (UITableViewDelegate)

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SectionHeaderView *headerView = [[SectionHeaderView alloc] initWithDefaultSize];

    NSString *key = [self titleForHeaderInSection:section];
    headerView.textLabel.text = NSLocalizedString(key, nil);

    UIButton *button = headerView.helpButton;
    button.tag = section;
    [button addTarget:self action:@selector(helpButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    return [headerView autorelease];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    return [view autorelease];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [SectionHeaderView defaultHeight];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    NSInteger lastSection = [tableView numberOfSections] - 1;
    return (section != lastSection) ? 10.0 : 0.0;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *array = [self arrayForSection:indexPath.section];
    if ([array count] > 0) {
        return UITableViewCellEditingStyleDelete;
    } else {
        return UITableViewCellEditingStyleNone;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *array = [self arrayForSection:indexPath.section];
    if ([array count] > 0) {
        return [[[self class] cellClass] cellHeight];
    } else {
        // Height for "EmptyCell".
        return 30.0;
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
