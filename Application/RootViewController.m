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

#import "CrashLogGroup.h"
#import "VictimViewController.h"
#import "ManualScriptViewController.h"

@implementation RootViewController {
    NSMutableArray *mobileCrashLogGroups_;
    NSMutableArray *rootCrashLogGroups_;
}

- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self != nil) {
        self.title = NSLocalizedString(@"CRASHREPORTER", nil);
    }
    return self;
}

- (void)dealloc {
    [mobileCrashLogGroups_ release];
    [rootCrashLogGroups_ release];
    [super dealloc];
}

- (void)viewDidLoad {
    UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
        target:self action:@selector(editBlame)];
    self.navigationItem.rightBarButtonItem = buttonItem;
    [buttonItem release];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadCrashLogs];
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

#pragma mark - Other

- (void)reloadCrashLogs {
    [mobileCrashLogGroups_ release];
    mobileCrashLogGroups_ = [[CrashLogGroup groupsForMobile] mutableCopy];
    [rootCrashLogGroups_ release];
    rootCrashLogGroups_ = [[CrashLogGroup groupsForRoot] mutableCopy];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return (section == 0) ? @"mobile" : @"root";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0) ? [mobileCrashLogGroups_ count] : [rootCrashLogGroups_ count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"."];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"."] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSArray *crashLogs = (indexPath.section == 0) ?  mobileCrashLogGroups_ : rootCrashLogGroups_;
    CrashLogGroup *group = [crashLogs objectAtIndex:indexPath.row];
    cell.textLabel.text = group.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[group.crashLogs count]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *crashLogs = (indexPath.section == 0) ?  mobileCrashLogGroups_ : rootCrashLogGroups_;
    CrashLogGroup *group = [crashLogs objectAtIndex:indexPath.row];

    VictimViewController *controller = [[VictimViewController alloc] initWithStyle:UITableViewStylePlain];
    controller.title = group.name;
    controller.group = group;
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath {
    NSUInteger section = indexPath.section;
    NSUInteger row = indexPath.row;
    NSMutableArray *crashLogs = (section == 0) ?  mobileCrashLogGroups_ : rootCrashLogGroups_;

    CrashLogGroup *group = [crashLogs objectAtIndex:row];
    if ([group delete]) {
        [crashLogs removeObjectAtIndex:row];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    } else {
        NSLog(@"ERROR: Failed to delete logs for group \"%@\".", [group name]);
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
