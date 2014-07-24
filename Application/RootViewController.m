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

#import "RootViewController.h"

#import "CrashLog.h"
#import "CrashLogGroup.h"
#import "VictimViewController.h"
#import "ManualScriptViewController.h"

@implementation RootViewController

- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self != nil) {
        self.title = NSLocalizedString(@"CRASHREPORTER", nil);
    }
    return self;
}

- (void)viewDidLoad {
    // Add button for accessing "manual script" view.
    UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
        target:self action:@selector(editBlame)];
    self.navigationItem.rightBarButtonItem = buttonItem;
    [buttonItem release];

    // Add a refresh control.
    if (IOS_GTE(6_0)) {
        UITableView *tableView = [self tableView];
        tableView.alwaysBounceVertical = YES;
        UIRefreshControl *refreshControl = [UIRefreshControl new];
        [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
        [tableView addSubview:refreshControl];
        [refreshControl release];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [CrashLogGroup forgetGroups];
    [self.tableView reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Actions

- (void)editBlame {
    ManualScriptViewController *controller = [ManualScriptViewController new];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void)refresh:(UIRefreshControl *)refreshControl {
    [CrashLogGroup forgetGroups];
    [self.tableView reloadData];
    [refreshControl endRefreshing];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return (section == 0) ? @"mobile" : @"root";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *crashLogGroups = (section == 0) ?  [CrashLogGroup groupsForMobile] : [CrashLogGroup groupsForRoot];
    return [crashLogGroups count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"."];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"."] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSArray *crashLogGroups = (indexPath.section == 0) ?  [CrashLogGroup groupsForMobile] : [CrashLogGroup groupsForRoot];
    CrashLogGroup *group = [crashLogGroups objectAtIndex:indexPath.row];
    cell.textLabel.text = group.name;

    NSArray *crashLogs = [group crashLogs];
    unsigned long totalCount = [crashLogs count];
    unsigned long unviewedCount = 0;
    for (CrashLog *crashLog in crashLogs) {
        if (![crashLog isViewed]) {
            ++unviewedCount;
        }
    }

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu/%lu", unviewedCount, totalCount];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *crashLogGroups = (indexPath.section == 0) ?  [CrashLogGroup groupsForMobile] : [CrashLogGroup groupsForRoot];
    CrashLogGroup *group = [crashLogGroups objectAtIndex:indexPath.row];

    VictimViewController *controller = [[VictimViewController alloc] initWithStyle:UITableViewStylePlain];
    controller.title = group.name;
    controller.group = group;
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath {
    NSArray *crashLogGroups = (indexPath.section == 0) ?  [CrashLogGroup groupsForMobile] : [CrashLogGroup groupsForRoot];
    CrashLogGroup *group = [crashLogGroups objectAtIndex:indexPath.row];
    if ([group delete]) {
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    } else {
        NSLog(@"ERROR: Failed to delete logs for group \"%@\".", [group name]);
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
