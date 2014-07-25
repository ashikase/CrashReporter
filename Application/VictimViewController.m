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

#import "VictimViewController.h"

#import <libsymbolicate/CRCrashReport.h>
#import "CrashLog.h"
#import "CrashLogGroup.h"
#import "SuspectsViewController.h"

#include "paths.h"

static inline NSUInteger indexOf(NSUInteger section, NSUInteger row, BOOL deletedRowZero) {
    return section + row - (deletedRowZero ? 1 : 0);
}

@implementation VictimViewController {
    BOOL deletedRowZero_;
}

@synthesize group = group_;

- (void)dealloc {
    [group_ release];
    [super dealloc];
}

- (void)viewDidLoad {
    // Localize the edit button.
    // NOTE: Apparently it does not get localized by default?
    self.navigationItem.rightBarButtonItem = [self editButtonItem];
    self.editButtonItem.title = NSLocalizedString(@"EDIT", nil);

    // Add a refresh control.
    if (IOS_GTE(6_0)) {
        UITableView *tableView = [self tableView];
        tableView.alwaysBounceVertical = YES;
        UIRefreshControl *refreshControl = [NSClassFromString(@"UIRefreshControl") new];
        [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
        [tableView addSubview:refreshControl];
        [refreshControl release];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [self.tableView reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Actions

- (void)refresh:(UIRefreshControl *)refreshControl {
    [self reloadCrashLogGroup];
    [self.tableView reloadData];
    [refreshControl endRefreshing];
}

#pragma mark - Other

- (void)reloadCrashLogGroup {
    NSString *groupName = [group_ name];
    NSString *logDirectory = [group_ logDirectory];

    // Reload all crash log groups.
    [CrashLogGroup forgetGroups];
    NSArray *crashLogGroups = [logDirectory isEqualToString:@kCrashLogDirectoryForMobile] ?
        [CrashLogGroup groupsForMobile] : [CrashLogGroup groupsForRoot];

    // Find the new group with the same group name (i.e. same process).
    for (CrashLogGroup *group in crashLogGroups) {
        if ([[group name] isEqualToString:groupName]) {
            [group_ release];
            group_ = [group retain];
            [self.tableView reloadData];
            break;
        }
    }
}

- (void)showSuspectsForCrashLog:(CrashLog *)crashLog {
    SuspectsViewController *controller = [[SuspectsViewController alloc] initWithCrashLog:crashLog];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *key = (section == 0) ? @"LATEST" : @"EARLIER";
    return NSLocalizedString(key, nil);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger numRows = 0;
    NSUInteger count = [[[self group] crashLogs] count];
    if (count != 0) {
        if (section == 0) {
            numRows = deletedRowZero_? 0 : 1;
        } else {
            numRows = deletedRowZero_? count : count - 1;
        }
    }
    return numRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"."];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"."] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSUInteger index = indexOf(indexPath.section, indexPath.row, deletedRowZero_);
    CrashLogGroup *group = [self group];
    CrashLog *crashLog = [[group crashLogs] objectAtIndex:index];

    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"HH:mm:ss (yyyy MMM d)"];
    UILabel *label = cell.textLabel;
    label.text = [formatter stringFromDate:[crashLog date]];
    label.textColor = [crashLog isViewed] ? [UIColor grayColor] : [UIColor blackColor];
    [formatter release];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger index = indexOf(indexPath.section, indexPath.row, deletedRowZero_);
    CrashLogGroup *group = [self group];
    CrashLog *crashLog = [[group crashLogs] objectAtIndex:index];
    [self showSuspectsForCrashLog:crashLog];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger section = indexPath.section;

    CrashLogGroup *group = [self group];
    NSUInteger index = indexOf(section, indexPath.row, deletedRowZero_);
    CrashLog *crashLog = [[group crashLogs] objectAtIndex:index];
    if ([group deleteCrashLog:crashLog]) {
        if (section == 0) {
            deletedRowZero_ = YES;
        }
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    } else {
        NSString *title = NSLocalizedString(@"ERROR", nil);
        NSString *message = NSLocalizedString(@"FILE_DELETION_FAILED"
           , nil);
        NSString *okMessage = NSLocalizedString(@"OK", nil);
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
            cancelButtonTitle:okMessage otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
