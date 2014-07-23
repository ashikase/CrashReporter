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

#import "CrashLogGroup.h"

#import "CrashLog.h"

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

static NSInteger reverseCompareCrashLogs(CrashLog *a, CrashLog *b, void *context) {
    return [[b filepath] compare:[a filepath]];
}

@implementation CrashLogGroup {
    NSMutableArray *crashLogs_;
}

@synthesize name = name_;
@synthesize logDirectory = logDirectory_;

+ (NSArray *)groupsForMobile {
    return crashLogGroupsForDirectory(@"/var/mobile/Library/Logs/CrashReporter");
}

+ (NSArray *)groupsForRoot {
    return crashLogGroupsForDirectory(@"/Library/Logs/CrashReporter");
}

+ (instancetype)groupWithName:(NSString *)name logDirectory:(NSString *)logDirectory {
    return [[[self alloc] initWithName:name logDirectory:logDirectory] autorelease];
}

- (instancetype)initWithName:(NSString *)name logDirectory:(NSString *)logDirectory {
    self = [super init];
    if (self != nil) {
        name_ = [name copy];
        logDirectory_ = [logDirectory copy];
        crashLogs_ = [NSMutableArray new];
    }
    return self;
}

- (void)dealloc {
    [name_ release];
    [logDirectory_ release];
    [crashLogs_ release];
    [super dealloc];
}

- (NSArray *)crashLogs {
    return [crashLogs_ sortedArrayUsingFunction:reverseCompareCrashLogs context:NULL];
}

- (void)addCrashLog:(CrashLog *)crashLog {
    [crashLogs_ addObject:crashLog];
}

- (BOOL)delete {
    NSUInteger count = [crashLogs_ count];
    for (NSInteger i = (count - 1); i >= 0; --i) {
        CrashLog *crashLog = [crashLogs_ objectAtIndex:i];
        if ([crashLog delete]) {
            [crashLogs_ removeObjectAtIndex:i];
        } else {
            // Failed to delete a log file; stop and return.
            return NO;
        }
    }
    return YES;
}

// FIXME: Update "LatestCrash-*" link, if necessary.
- (BOOL)deleteCrashLog:(CrashLog *)crashLog {
    if ([crashLogs_ containsObject:crashLog]) {
        [crashLog delete];
        if (![[NSFileManager defaultManager] fileExistsAtPath:[crashLog filepath]]) {
            [crashLogs_ removeObject:crashLog];
            return YES;
        }
    }
    return NO;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
