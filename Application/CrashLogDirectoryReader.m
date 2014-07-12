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

#import "CrashLogDirectoryReader.h"

#import <RegexKitLite/RegexKitLite.h>
#import "CrashLogGroup.h"
#import "move_as_root.h"

#include "common.h"

// user name -> { app name -> {date -> file} }
// The file name must be of the form [app_name]_date_device-name.
// The device-name cannot contain underscores.

static NSCalendar *calendar() {
    static NSCalendar *calendar = nil;
    if (calendar == nil) {
        calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    }
    return calendar;
}

static NSArray *crashLogGroupsForDirectory(NSString *directory) {
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];

    // Look in path for crash log files; group logs by app name.
    NSFileManager *fileMan = [NSFileManager defaultManager];
    for (NSString *filename in [fileMan contentsOfDirectoryAtPath:directory error:NULL]) {
        NSArray *matches = [filename captureComponentsMatchedByRegex:@"(.+)_(\\d{4})-(\\d{2})-(\\d{2})-(\\d{2})(\\d{2})(\\d{2})_[^_]+\\.(?:plist|ips)"];
        if ([matches count] == 8) {
            NSDate *date = nil;
            NSDateComponents *components = [NSDateComponents new];
            [components setYear:[[matches objectAtIndex:2] integerValue]];
            [components setMonth:[[matches objectAtIndex:3] integerValue]];
            [components setDay:[[matches objectAtIndex:4] integerValue]];
            [components setHour:[[matches objectAtIndex:5] integerValue]];
            [components setMinute:[[matches objectAtIndex:6] integerValue]];
            [components setSecond:[[matches objectAtIndex:7] integerValue]];
            date = [calendar() dateFromComponents:components];
            [components release];

            NSString *name = [matches objectAtIndex:1];
            CrashLogGroup *group = [groups objectForKey:name];
            if (group == nil) {
                group = [[CrashLogGroup alloc] initWithName:name logDirectory:directory];
                [groups setObject:group forKey:name];
            }
            [group addFilename:filename forDate:date];
        }
    }

    return [groups allValues];
}

@implementation CrashLogDirectoryReader

+ (NSArray *)crashLogsForMobile {
    return crashLogGroupsForDirectory(@"/var/mobile/Library/Logs/CrashReporter");
}

+ (NSArray *)crashLogsForRoot {
    return crashLogGroupsForDirectory(@"/Library/Logs/CrashReporter");
}

+ (void)deleteCrashLogsForUser:(int)userIndex group:(int)groupIndex {
    // NOTE: userIndex should be 0 (mobile) or 1 (root).
    assert(userIndex < 2);
    NSArray *groups = (userIndex == 0) ? [self crashLogsForMobile] : [self crashLogsForRoot];

    assert(groupIndex < [groups count]);
    CrashLogGroup *group = [groups objectAtIndex:groupIndex];
    if (group != nil) {
        NSFileManager *fileMan = [NSFileManager defaultManager];
        for (NSString *filename in [group files]) {
            NSString *filepath = [[group logDirectory] stringByAppendingPathComponent:filename];
            if (![fileMan removeItemAtPath:filepath error:NULL]) {
                // FIXME: Extremely inefficient!
                exec_move_as_root("!", "!", [filepath UTF8String]);
            }
        }
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
