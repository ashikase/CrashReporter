/*

CrashLogFolderReader.m ... Data structures representing groups of crash logs.
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

#import "CrashLogsFolderReader.h"
#import "RegexKitLite.h"
#include "common.h"
#import "move_as_root.h"

static NSArray* crashPaths;

// user name -> { app name -> {date -> file} }
// The file name must be of the form [app_name]_date_device-name. The device-name cannot contain underscores.

@implementation NSDate (ReverseCompare)
-(NSComparisonResult)reverseCompare:(NSDate*)date2 {
	return -[self compare:date2];
}
@end


@implementation CrashLogGroup
+(CrashLogGroup*)groupWithApp:(NSString*)app datesAndFiles:(NSDictionary*)datesAndFiles {
	CrashLogGroup* grp = [[[CrashLogGroup alloc] init] autorelease];
	if (grp != NULL) {
		grp->app = [app retain];
		grp->dates = [[datesAndFiles allKeys] mutableCopy];
		[grp->dates sortUsingSelector:@selector(reverseCompare:)];
		NSMutableArray* fns = [[NSMutableArray alloc] init];
		for (NSDate* date in grp->dates) {
			[fns addObject:[datesAndFiles objectForKey:date]];
		}
		grp->files = fns;
	}
	return grp;
}
-(void)dealloc {
	[app release];
	[dates release];
	[files release];
	[folder release];
	[super dealloc];
}
@end

static NSArray* getCrashLogInDir(NSString* dir, NSFileManager* fman, NSCalendar* cal, NSDateComponents* dc) {
	[fman changeCurrentDirectoryPath:dir];
	NSMutableDictionary* res = [[NSMutableDictionary alloc] init];

	for (NSString* path in [fman contentsOfDirectoryAtPath:@"." error:NULL]) {
		NSArray* capture = [path captureComponentsMatchedByRegex:@"(.+)_(\\d{4})-(\\d{2})-(\\d{2})-(\\d{2})(\\d{2})(\\d{2})_[^_]+\\.plist"];

		if ([capture count] == 8) {
			NSString* matches[7];
			[capture getObjects:matches range:NSMakeRange(1, 7)];

			NSString* appName = matches[0];

			[dc setYear:[matches[1] integerValue]];
			[dc setMonth:[matches[2] integerValue]];
			[dc setDay:[matches[3] integerValue]];
			[dc setHour:[matches[4] integerValue]];
			[dc setMinute:[matches[5] integerValue]];
			[dc setSecond:[matches[6] integerValue]];

			NSDate* date = [cal dateFromComponents:dc];

			NSMutableDictionary* appDict = [res objectForKey:appName];
			if (appDict == nil) {
				appDict = [NSMutableDictionary dictionaryWithObject:path forKey:date];
				[res setObject:appDict forKey:appName];
			} else {
				[appDict setObject:path forKey:date];
			}
		}
	}

	NSMutableArray* actualRes = [NSMutableArray array];

	for (NSString* app in res) {
		CrashLogGroup* group = [CrashLogGroup groupWithApp:app datesAndFiles:[res objectForKey:app]];
		group->folder = [dir retain];
		[actualRes addObject:group];
	}

	[res release];

	return actualRes;
}

NSArray* GetCrashLogs() {
	if (crashPaths == nil) {
		NSFileManager* fman = [NSFileManager defaultManager];
		NSCalendar* cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		NSDateComponents* dc = [[NSDateComponents alloc] init];

		crashPaths = [[NSArray alloc] initWithObjects:
#if 1
					  getCrashLogInDir(@"/var/mobile/Library/Logs/CrashReporter", fman, cal, dc),
#else
					  getCrashLogInDir([[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"CR"], fman, cal, dc),
#endif
					  getCrashLogInDir(@"/Library/Logs/CrashReporter", fman, cal, dc),
					  nil];

		[dc release];
		[cal release];
	}

	return crashPaths;
}

void DeleteCrashLogs(int user, int idx) {
	NSMutableArray* r = [crashPaths objectAtIndex:user];
	CrashLogGroup* g = [r objectAtIndex:idx];
	if (g != nil) {
		NSFileManager* fman = [NSFileManager defaultManager];
		for (NSString* f in g->files) {
			NSString* fn = [g->folder stringByAppendingPathComponent:f];
			if (![fman removeItemAtPath:fn error:NULL])
				// oh no, extremely inefficient!
				exec_move_as_root("!", "!", [fn UTF8String]);
		}
	}
	[r removeObjectAtIndex:idx];
}
