/*

   VictimViewController.m ... Crash log selector by date.
   Copyright (C) 2009  KennyTM~ <kennytm@gmail.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#import "VictimViewController.h"

#import <libsymbolicate/CRCrashReport.h>
#import "CrashLog.h"
#import "CrashLogGroup.h"
#import "ModalActionSheet.h"
#import "SuspectsViewController.h"

#include "move_as_root.h"

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

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *key = (section == 0) ? @"Latest" : @"Earlier";
    return [[NSBundle mainBundle] localizedStringForKey:key value:nil table:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numRows = 0;
    NSUInteger count = [[[self group] crashLogs] count];
    if (count != 0) {
        numRows = (section == 0) ? 1 : (count - 1);
        numRows -= deletedRowZero_ ? 1 : 0;
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
        ModalActionSheet *sheet = [[ModalActionSheet alloc] init2];
        [sheet show];
#if !TARGET_IPHONE_SIMULATOR
        [crashLog symbolicate];
#endif
        [sheet hide];
        [sheet release];
    }

    // FIXME: Pass CrashLog object instead.
    [controller readSuspects:[[crashLog filepath] lastPathComponent] date:[crashLog date]];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger section = indexPath.section;

    CrashLogGroup *group = [self group];
    NSUInteger index = indexOf(section, indexPath.row, deletedRowZero_);
    CrashLog *crashLog = [[group crashLogs] objectAtIndex:index];
    NSString *filepath = [crashLog filepath];

    // Move to CrashLogGroup.
    if (![[NSFileManager defaultManager] removeItemAtPath:filepath error:NULL]) {
        // Try to delete as root.
        exec_move_as_root("!", "!", [filepath UTF8String]);
    }

    if (section == 0) {
        deletedRowZero_ = YES;
    }

    // FIXME:
    //[group_.files removeObjectAtIndex:index];
    //[group_.dates removeObjectAtIndex:index];
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
