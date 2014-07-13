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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)viewDidLoad {
    self.navigationItem.rightBarButtonItem = [self editButtonItem];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.tableView reloadData];
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
    NSUInteger count = [group_.files count];
    if (count != 0) {
        numRows = (section == 0) ? 1 : count;
        numRows -= deletedRowZero_ ? 0 : 1;
    }
    return numRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"."];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"."] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSUInteger section = indexPath.section;
    NSUInteger row = indexPath.row;
    NSString *filename = [group_.files objectAtIndex:indexOf(section, row, deletedRowZero_)];
    BOOL isReported = [filename hasSuffix:@".symbolicated.plist"] || [filename hasSuffix:@".symbolicated.ips"];

    NSDateFormatter* formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"HH:mm:ss (yyyy MMM d)"];
    UILabel *label = cell.textLabel;
    label.text = [formatter stringFromDate:[group_.dates objectAtIndex:indexOf(section, row, deletedRowZero_)]];
    label.textColor = isReported ? [UIColor grayColor] : [UIColor blackColor];
    [formatter release];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SuspectsViewController *controller = [SuspectsViewController new];

    NSUInteger index = indexOf(indexPath.section, indexPath.row, deletedRowZero_);
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:group_.logDirectory];
    NSString *file = [group_.files objectAtIndex:index];
    BOOL isReported = [file hasSuffix:@".symbolicated.plist"] || [file hasSuffix:@".symbolicated.ips"];
    if (!isReported) {
        // Symbolicate.
        ModalActionSheet* sheet = [[ModalActionSheet alloc] init2];
        [sheet show];

#if !TARGET_IPHONE_SIMULATOR
        // Load crash report.
        CRCrashReport *report = [[CRCrashReport alloc] initWithFile:file];

        // Symbolicate.
        if (![report symbolicate]) {
            NSLog(@"WARNING: Unable to symbolicate file \"%@\".", file);
        }

        // Process blame.
        NSDictionary *filters = [[NSDictionary alloc] initWithContentsOfFile:@"/etc/symbolicate/blame_filters.plist"];
        if (![report blameUsingFilters:filters]) {
            NSLog(@"WARNING: Failed to process blame.");
        }
        [filters release];

        // Write output to file.
        NSString *outputFilepath = [NSString stringWithFormat:@"%@.symbolicated.%@",
                 [file stringByDeletingPathExtension], [file pathExtension]];
        NSError *error = nil;
        if (![[report stringRepresentation] writeToFile:outputFilepath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            NSLog(@"ERROR: Unable to write to file \"%@\": %@.", outputFilepath, [error localizedDescription]);
        }
        [report release];

        file = outputFilepath;
#endif

        // FIXME:
        //[group_.files replaceObjectAtIndex:index withObject:file];
        [sheet hide];
        [sheet release];
    }

    // FIXME: Just pass blame array (e.g. setSuspects:].
    [controller readSuspects:file date:[group_.dates objectAtIndex:index]];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger section = indexPath.section;
    NSUInteger index = indexOf(section, indexPath.row, deletedRowZero_);
    NSString *filename = [group_.files objectAtIndex:index];
    NSString *filepath = [group_.logDirectory stringByAppendingPathComponent:filename];
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
