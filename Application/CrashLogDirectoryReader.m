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

#import "CrashLog.h"
#import "CrashLogGroup.h"
#import "move_as_root.h"

#include "common.h"

static NSArray *crashLogGroupsForDirectory(NSString *directory) {
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];

    // Look in path for crash log files; group logs by app name.
    NSFileManager *fileMan = [NSFileManager defaultManager];
    for (NSString *filename in [fileMan contentsOfDirectoryAtPath:directory error:NULL]) {
        NSString *filepath = [directory stringByAppendingPathComponent:filename];
        CrashLog *crashLog = [[CrashLog alloc] initWithFilepath:filepath];
        if (crashLog != nil) {
            NSString *name = [crashLog processName];
            CrashLogGroup *group = [groups objectForKey:name];
            if (group == nil) {
                group = [[CrashLogGroup alloc] initWithName:name logDirectory:directory];
                [groups setObject:group forKey:name];
            }
            [group addCrashLog:crashLog];
            [crashLog release];
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
        for (CrashLog *crashLog in [group crashLogs]) {
            NSString *filepath = [crashLog filepath];
            if (![fileMan removeItemAtPath:filepath error:NULL]) {
                // FIXME: Extremely inefficient!
                exec_move_as_root("!", "!", [filepath UTF8String]);
            }
        }
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
