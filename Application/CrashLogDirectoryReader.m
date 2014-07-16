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
