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
#import "ModalActionSheet.h"
#import "SuspectsViewController.h"

static inline NSUInteger indexOf(NSUInteger section, NSUInteger row, BOOL deletedRowZero) {
    return section + row - (deletedRowZero ? 1 : 0);
}

@implementation VictimViewController {
    BOOL deletedRowZero_;
}

@synthesize group = group_;

- (void)viewDidLoad {
    self.navigationItem.rightBarButtonItem = [self editButtonItem];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.tableView reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *key = (section == 0) ? @"Latest" : @"Earlier";
    return [[NSBundle mainBundle] localizedStringForKey:key value:nil table:nil];
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
    label.textColor = [crashLog isSymbolicated] ? [UIColor grayColor] : [UIColor blackColor];
    [formatter release];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SuspectsViewController *controller = [SuspectsViewController new];

    NSUInteger index = indexOf(indexPath.section, indexPath.row, deletedRowZero_);
    CrashLogGroup *group = [self group];
    CrashLog *crashLog = [[group crashLogs] objectAtIndex:index];
    if (![crashLog isSymbolicated]) {
        // Symbolicate.
        ModalActionSheet *sheet = [ModalActionSheet new];
        [sheet show];
#if !TARGET_IPHONE_SIMULATOR
        [crashLog symbolicate];
#endif
        [sheet hide];
        [sheet release];
    }

    [controller readSuspectsForCrashLog:crashLog];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
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
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *title = [mainBundle localizedStringForKey:@"Error" value:nil table:nil];
        NSString *message = [mainBundle localizedStringForKey:@"FILE_DELETION_FAILED"
            value:@"Could not delete the selected file." table:nil];
        NSString *okMessage = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
            cancelButtonTitle:okMessage otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
