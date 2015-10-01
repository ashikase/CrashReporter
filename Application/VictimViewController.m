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
#import "SectionHeaderView.h"
#import "SuspectsViewController.h"
#import "VictimCell.h"

#include "paths.h"

@implementation VictimViewController {
    CrashLogGroup *group_;
}

- (id)initWithGroup:(CrashLogGroup *)group {
    self = [super init];
    if (self != nil) {
        group_ = [group retain];

        self.title = group_.name;
        self.supportsRefreshControl = YES;

        // Add button for deleting all logs for this group.
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
            target:self action:@selector(trashButtonTapped)];
        self.navigationItem.rightBarButtonItem = buttonItem;
        [buttonItem release];
    }
    return self;
}

- (void)dealloc {
    [group_ release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.tableView reloadData];
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

#pragma mark - Overrides (TableViewController)

+ (Class)cellClass {
    return [VictimCell class];
}

- (NSArray *)arrayForSection:(NSInteger)section {
    NSArray *array = nil;

    switch (section) {
        case 0: {
            NSArray *crashLogs = [group_ crashLogs];
            const NSUInteger count = [crashLogs count];
            if (count > 0) {
                array = [crashLogs subarrayWithRange:NSMakeRange(0, 1)];
            }
        }   break;
        case 1: {
            NSArray *crashLogs = [group_ crashLogs];
            const NSUInteger count = [crashLogs count];
            if (count > 1) {
                array = [crashLogs subarrayWithRange:NSMakeRange(1, count - 1)];
            }
        }   break;
        default:
            break;
    }

    return array;
}

- (void)refresh:(id)sender {
    [self reloadCrashLogGroup];
    [super refresh:sender];
}

- (NSString *)titleForHeaderInSection:(NSInteger)section {
    return (section == 0) ? @"LATEST" : @"EARLIER";
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

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *array = [self arrayForSection:indexPath.section];
    if (array != nil) {
        CrashLog *crashLog = [array objectAtIndex:indexPath.row];
        [self showSuspectsForCrashLog:crashLog];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    const NSInteger section = indexPath.section;

    // NOTE: Retrieve arrays for both sections before deletion in order to know
    //       what has changed, needed for deletion animation.
    NSArray *latest = [self arrayForSection:0];
    NSArray *earlier = [self arrayForSection:1];

    NSArray *array = (section == 0) ? latest : earlier;
    CrashLog *crashLog = [array objectAtIndex:indexPath.row];
    if ([group_ deleteCrashLog:crashLog]) {
        // Animate deletion of row.
        NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
        [tableView beginUpdates];
        if ([array count] == 1) {
            [tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
        } else {
            [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
        }
        if (section == 0) {
            // Animate movement of row from section 1 to section 0.
            const NSUInteger earlierCount = [earlier count];
            NSArray *earlierIndexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:1]];
            if (earlierCount == 1) {
                [tableView reloadRowsAtIndexPaths:earlierIndexPaths withRowAnimation:UITableViewRowAnimationLeft];
            } else if (earlierCount > 1) {
                [tableView deleteRowsAtIndexPaths:earlierIndexPaths withRowAnimation:UITableViewRowAnimationLeft];
            }
        }
        [tableView endUpdates];
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
