/*

CrashLogDateChooser.m ... Crash log selector by date.
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

#import "CrashLogDateChooser.h"
#import <libsymbolicate/CRCrashReport.h>
#import "CrashLogsFolderReader.h"
#import "SuspectsViewController.h"
#import <UIKit/UIKit.h>
#import "ModalActionSheet.h"

#include "move_as_root.h"

static inline NSUInteger index_of(NSUInteger sect, NSUInteger row, BOOL deleted_row_0) {
	return sect + row - (deleted_row_0?1:0);
}

@implementation CrashLogDateChooser
@synthesize group;

-(void)viewDidLoad {
	self.navigationItem.rightBarButtonItem = [self editButtonItem];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView*)tableView { return 2; }
-(NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
	return [[NSBundle mainBundle] localizedStringForKey:(section == 0 ? @"Latest" : @"Earlier") value:nil table:nil];
}
-(NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
	NSUInteger count = [group->files count];
	if (deleted_row_0 || count == 0) {
		if (section == 0)
			return 0;
		else
			return count;
	} else {
		if (section == 0)
			return 1;
		else
			return count - 1;
	}
}

-(UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
	UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"."];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"."] autorelease];
	}

	NSUInteger row = indexPath.row, section = indexPath.section;
	NSString* filename = [group->files objectAtIndex:index_of(section, row, deleted_row_0)];
	BOOL is_reported = [filename hasSuffix:@".symbolicated.plist"] || [filename hasSuffix:@".symbolicated.ips"];

	UILabel* label = cell.textLabel;
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"HH:mm:ss (yyyy MMM d)"];
	label.text = [formatter stringFromDate:[group->dates objectAtIndex:index_of(section, row, deleted_row_0)]];
	[formatter release];
	label.textColor = is_reported ? [UIColor grayColor] : [UIColor blackColor];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
	SuspectsViewController* ctrler = [[SuspectsViewController alloc] init];
	NSUInteger idx = index_of(indexPath.section, indexPath.row, deleted_row_0);
	[[NSFileManager defaultManager] changeCurrentDirectoryPath:group->folder];
	NSString* file = [group->files objectAtIndex:idx];
	BOOL is_reported = [file hasSuffix:@".symbolicated.plist"] || [file hasSuffix:@".symbolicated.ips"];
	if (!is_reported) {
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
		[group->files replaceObjectAtIndex:idx withObject:file];
		[sheet hide];
		[sheet release];
	}
	[ctrler readSuspects:file date:[group->dates objectAtIndex:idx]];
	[self.navigationController pushViewController:ctrler animated:YES];
	[ctrler release];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation { return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown; }

-(void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath {
	NSUInteger sect = indexPath.section;
	NSUInteger idx = index_of(sect, indexPath.row, deleted_row_0);
	NSString* file = [group->files objectAtIndex:idx];
	NSString* filename = [group->folder stringByAppendingPathComponent:file];
	if (![[NSFileManager defaultManager] removeItemAtPath:filename error:NULL]) {
		// Try to delete as root.
		exec_move_as_root("!", "!", [filename UTF8String]);
	}
	if (sect == 0)
		deleted_row_0 = YES;

	[group->files removeObjectAtIndex:idx];
	[group->dates removeObjectAtIndex:idx];
	[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
}

-(void)viewWillAppear:(BOOL)animated {
	[self.tableView reloadData];
}
@end
