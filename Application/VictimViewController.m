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

#import <libcrashreport/libcrashreport.h>
#import "CrashLog.h"
#import "CrashLogGroup.h"
#import "SuspectsViewController.h"

#include "paths.h"

extern NSString * const kNotificationCrashLogsChanged;

static inline NSUInteger indexOf(NSUInteger section, NSUInteger row, BOOL deletedRowZero) {
    return section + row - (deletedRowZero ? 1 : 0);
}

@implementation VictimViewController {
    CrashLogGroup *group_;
    BOOL deletedRowZero_;
}

- (id)initWithGroup:(CrashLogGroup *)group {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self != nil) {
        group_ = [group retain];
        self.title = group_.name;

        // Add button for deleting all logs for this group.
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
            target:self action:@selector(trashButtonTapped)];
        self.navigationItem.rightBarButtonItem = buttonItem;
        [buttonItem release];

        // Listen for changes to crash log files.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:kNotificationCrashLogsChanged object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [group_ release];
    [super dealloc];
}

- (void)viewDidLoad {
    // Add a refresh control.
    if (IOS_GTE(6_0)) {
        UITableView *tableView = [self tableView];
        tableView.alwaysBounceVertical = YES;
        UIRefreshControl *refreshControl = [[NSClassFromString(@"UIRefreshControl") alloc] init];
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

- (void)trashButtonTapped {
    NSString *message = [[NSString alloc] initWithFormat:NSLocalizedString(@"DELETE_ALL_FOR_MESSAGE", nil), [group_ name]];
    NSString *deleteTitle = NSLocalizedString(@"DELETE", nil);
    NSString *cancelTitle = NSLocalizedString(@"CANCEL", nil);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self
        cancelButtonTitle:cancelTitle otherButtonTitles:deleteTitle, nil];
    [alert show];
    [alert release];
    [message release];
}

- (void)refresh:(id)sender {
    [self reloadCrashLogGroup];
    [self.tableView reloadData];

    if ([sender isKindOfClass:NSClassFromString(@"UIRefreshControl")]) {
        [sender endRefreshing];
    }
}

#pragma mark - Other

- (void)reloadCrashLogGroup {
    // Reload all crash log groups.
    [CrashLogGroup forgetGroups];

    NSArray *crashLogGroups = [CrashLogGroup groupsForType:[group_ type]];

    // Find the new group with the same group name (i.e. same process).
    NSString *groupName = [group_ name];
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

#pragma mark - Delegate (UIAlertView)

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        if ([group_ delete]) {
            // FIXME: For a better visual effect, refresh the table, detect when
            //        the reload has finished, and then, after a brief delay, pop.
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            NSString *title = NSLocalizedString(@"ERROR", nil);
            NSString *message = NSLocalizedString(@"DELETE_ALL_FAILED", nil);
            NSString *okMessage = NSLocalizedString(@"OK", nil);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
                cancelButtonTitle:okMessage otherButtonTitles:nil];
            [alert show];
            [alert release];

            [self refresh:nil];
        }
    }
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
    const NSUInteger count = [[group_ crashLogs] count];
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

    const NSUInteger index = indexOf(indexPath.section, indexPath.row, deletedRowZero_);
    CrashLog *crashLog = [[group_ crashLogs] objectAtIndex:index];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss (yyyy MMM d)"];
    UILabel *label = cell.textLabel;
    label.text = [formatter stringFromDate:[crashLog logDate]];
    label.textColor = [crashLog isViewed] ? [UIColor grayColor] : [UIColor blackColor];
    [formatter release];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    const NSUInteger index = indexOf(indexPath.section, indexPath.row, deletedRowZero_);
    CrashLog *crashLog = [[group_ crashLogs] objectAtIndex:index];
    [self showSuspectsForCrashLog:crashLog];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    const NSUInteger section = indexPath.section;

    const NSUInteger index = indexOf(section, indexPath.row, deletedRowZero_);
    CrashLog *crashLog = [[group_ crashLogs] objectAtIndex:index];
    if ([group_ deleteCrashLog:crashLog]) {
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

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    // Change background color of header to improve visibility.
    [view setTintColor:[UIColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0]];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
