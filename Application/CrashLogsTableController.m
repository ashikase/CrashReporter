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

#import "CrashLogsTableController.h"
#import "CrashLogsFolderReader.h"
#import "CrashLogDateChooser.h"
#import "CustomBlameController.h"

@implementation CrashLogsTableController
/*
-(id)initWithStyle:(UITableViewStyle)style {
	if ((self = [super initWithStyle:style])) {
	}
	return self;
}*/

-(void)viewDidLoad {
	UIBarButtonItem* editBlame = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(editBlame)];
	self.navigationItem.rightBarButtonItem = editBlame;
	[editBlame release];

	/*
	UIBarButtonItem* settings = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showSettings)];
	UIBarButtonItem* flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];

	settingsIcons = [[NSArray alloc] initWithObjects:settings, flexibleSpace, editBlame, nil];

	[settings release];
	[flexibleSpace release];
	[editBlame release];

	self.toolbarItems = settingsIcons;

	[settingsIcons release];
	 */
}

-(NSInteger)numberOfSectionsInTableView:(UITableView*)tableView { return 2; }
-(NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section { return section == 0 ? @"mobile" : @"root"; }
-(NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
	return [[GetCrashLogs() objectAtIndex:section] count];
}

-(UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
	UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"."];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"."] autorelease];
	}
	CrashLogGroup* group = [[GetCrashLogs() objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
	cell.textLabel.text = group->app;
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[group->files count]];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
	CrashLogDateChooser* dateChooser = [[CrashLogDateChooser alloc] initWithStyle:UITableViewStylePlain];
	CrashLogGroup* group = [[GetCrashLogs() objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
	dateChooser.title = group->app;
	dateChooser.group = group;
	[self.navigationController pushViewController:dateChooser animated:YES];
	[dateChooser release];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation { return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown; }

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData];
}

-(void)editBlame {
	CustomBlameController* ctrler = [[CustomBlameController alloc] init];
	[self.navigationController pushViewController:ctrler animated:YES];
	[ctrler release];
}

-(void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath {
	DeleteCrashLogs(indexPath.section, indexPath.row);
	[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
}



@end
