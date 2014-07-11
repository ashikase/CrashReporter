/*

SuspectsViewController.m ... Table of crash suspects
Copyright (c) 2009  KennyTM~ <kennytm@gmail.com>

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

#import "SuspectsViewController.h"
#import <Foundation/Foundation.h>
#import "CrashLogViewController.h"
#import "reporter.h"
#import "BlameController.h"
#import "find_dpkg.h"
#import <RegexKitLite/RegexKitLite.h>

static NSComparisonResult blameSorter(id a, id b, void* c) {
	unsigned au = [[a objectAtIndex:1] unsignedIntValue], bu = [[b objectAtIndex:1] unsignedIntValue];
	if (au < bu)
		return NSOrderedAscending;
	else if (au > bu)
		return NSOrderedDescending;
	else
		return NSOrderedSame;
}

@implementation SuspectsViewController
-(void)readSuspects:(NSString*)file date:(NSDate*)date {
	_file = [file retain];
	_date = [[ReporterLine formatSyslogTime:date] retain];

	NSArray* sortedBlames = [[[NSDictionary dictionaryWithContentsOfFile:file] objectForKey:@"blame"] sortedArrayUsingFunction:blameSorter context:NULL];

	[primarySuspect release];
	primarySuspect = nil;
	[secondarySuspects release];
	secondarySuspects = [[NSMutableArray alloc] init];
	[tertiarySuspects release];
	tertiarySuspects = [[NSMutableArray alloc] init];

	for (NSArray* blame in sortedBlames) {
		unsigned blameRank = [[blame objectAtIndex:1] unsignedIntValue];
		NSString* blamePath = [blame objectAtIndex:0];
		if (blameRank & 0x80000000) {
			[tertiarySuspects addObject:blamePath];
		} else {
			if (primarySuspect == nil)
				primarySuspect = [blamePath retain];
			else
				[secondarySuspects addObject:blamePath];
		}
	}

	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"HH:mm:ss"];
	self.title = [formatter stringFromDate:date];
	[formatter release];
}
-(void)dealloc {
	[primarySuspect release];
	[secondarySuspects release];
	[tertiarySuspects release];
	[_file release];
	[_date release];
	[super dealloc];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView*)tableView { return 4; }

-(NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case 0: return 2;
		case 1: return primarySuspect != nil ? 1 : 0;
		case 2: return [secondarySuspects count];
		case 3: return [tertiarySuspects count];
		default: return 0;
	}
}

-(NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
	NSString* key;
	switch (section) {
		default: return nil;
		case 1: key = @"Primary suspect"; break;
		case 2: key = @"Secondary suspects"; break;
		case 3: key = @"Tertiary suspects"; break;
	}
	return [[NSBundle mainBundle] localizedStringForKey:key value:nil table:nil];
}

-(UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
	UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"."];
	if (cell == nil)
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"."] autorelease];

	NSUInteger row = indexPath.row;
	NSString* txt = nil;
	switch (indexPath.section) {
		default: txt = [[NSBundle mainBundle] localizedStringForKey:(row == 0 ? @"View crash log" : @"View syslog") value:nil table:nil]; break;
		case 1: txt = primarySuspect; break;
		case 2: txt = [secondarySuspects objectAtIndex:row]; break;
		case 3: txt = [tertiarySuspects objectAtIndex:row]; break;
	}
	cell.textLabel.text = [txt lastPathComponent];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	return cell;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
	UIViewController* ctrler = nil;
	NSUInteger row = indexPath.row;
	NSString* path = nil;

	NSString* syslogLine = [NSString stringWithFormat:@"include as syslog command grep -F \"%@\" /var/log/syslog", _date];
	NSString* crashlogLine = [NSString stringWithFormat:@"include as \"Crash log\" file \"%@\"", _file];

	switch (indexPath.section) {
		default: {
			ctrler = [[CrashLogViewController alloc] init];
			((CrashLogViewController*)ctrler).reporter = (IncludeReporterLine*)[ReporterLine reporterWithLine:(row == 1 ? syslogLine : crashlogLine)];

			goto view_crash_log;
		}

		case 1: path = primarySuspect; break;
		case 2: path = [secondarySuspects objectAtIndex:row]; break;
		case 3: path = [tertiarySuspects objectAtIndex:row]; break;
	}

	BOOL isAppStore = NO;
	struct Package package;
	NSArray* reporters = [ReporterLine reportersWithSuspect:path appendReporters:[NSArray arrayWithObjects:
																				  [ReporterLine reporterWithLine:crashlogLine],
																				  [ReporterLine reporterWithLine:syslogLine], nil]
													package:&package isAppStore:&isAppStore];
	NSString* authorStripped = [package.author stringByReplacingOccurrencesOfRegex:@"\\s*<[^>]+>" withString:@""] ?: @"developer";
	ctrler = [[BlameController alloc] initWithReporters:reporters
											packageName:(package.name ?: [path lastPathComponent])
											 authorName:authorStripped
												suspect:path
											 isAppStore:isAppStore];
	ctrler.title = [path lastPathComponent];

view_crash_log:
	[self.navigationController pushViewController:ctrler animated:YES];
	[ctrler release];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation { return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown; }
@end
