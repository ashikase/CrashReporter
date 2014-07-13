/*

   CrashLogsTableController.m ... Table of apps being crashed before.
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

#import "RootViewController.h"

#import "CrashLogDirectoryReader.h"
#import "CrashLogGroup.h"
#import "VictimViewController.h"
#import "CustomBlameController.h"

@implementation RootViewController {
    NSMutableArray *mobileCrashLogs_;
    NSMutableArray *rootCrashLogs_;
}

- (void)dealloc {
    [mobileCrashLogs_ release];
    [rootCrashLogs_ release];
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
    CustomBlameController *controller = [CustomBlameController new];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

#pragma mark - Other

- (void)reloadCrashLogs {
    [mobileCrashLogs_ release];
    mobileCrashLogs_ = [[CrashLogDirectoryReader crashLogsForMobile] mutableCopy];
    [rootCrashLogs_ release];
    rootCrashLogs_ = [[CrashLogDirectoryReader crashLogsForRoot] mutableCopy];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return (section == 0) ? @"mobile" : @"root";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0) ? [mobileCrashLogs_ count] : [rootCrashLogs_ count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"."];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"."] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSArray *crashLogs = (indexPath.section == 0) ?  mobileCrashLogs_ : rootCrashLogs_;
    CrashLogGroup *group = [crashLogs objectAtIndex:indexPath.row];
    cell.textLabel.text = group.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[group.crashLogs count]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *crashLogs = (indexPath.section == 0) ?  mobileCrashLogs_ : rootCrashLogs_;
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
    NSMutableArray *crashLogs = (section == 0) ?  mobileCrashLogs_ : rootCrashLogs_;
    [crashLogs removeObjectAtIndex:row];
    [CrashLogDirectoryReader deleteCrashLogsForUser:section group:row];
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
