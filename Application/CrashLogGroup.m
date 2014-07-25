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
#include "paths.h"

static NSMutableArray *mobileCrashLogGroups$ = nil;
static NSMutableArray *rootCrashLogGroups$ = nil;

static NSArray *crashLogGroupsForDirectory(NSString *directory) {
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    NSMutableArray *existentFilepaths = [NSMutableArray new];

    // Look in path for crash log files; group logs by app name.
    NSFileManager *fileMan = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [fileMan contentsOfDirectoryAtPath:directory error:&error];
    if (contents != nil) {
        for (NSString *filename in contents) {
            if ([filename hasSuffix:@"ips"] || [filename hasSuffix:@"plist"] || [filename hasSuffix:@"synced"]) {
                NSString *filepath = [directory stringByAppendingPathComponent:filename];
                CrashLog *crashLog = [[CrashLog alloc] initWithFilepath:filepath];
                if (crashLog != nil) {
                    // Store filepath for "known viewed" check below.
                    [existentFilepaths addObject:filepath];

                    // Store crash log object in group.
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
        }
    } else {
        NSLog(@"ERROR: Unable to retrieve contents of directory \"%@\": %@", directory, [error localizedDescription]);
    }

    // Update list of viewed crash logs, removing entries that no longer exist.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *oldViewedCrashLogs = [defaults arrayForKey:kViewedCrashLogs];
    NSMutableArray *newViewedCrashLogs = [[NSMutableArray alloc] initWithArray:oldViewedCrashLogs];
    for (NSString *filepath in oldViewedCrashLogs) {
        if ([[filepath stringByDeletingLastPathComponent] isEqualToString:directory]) {
            if (![existentFilepaths containsObject:filepath]) {
                [newViewedCrashLogs removeObject:filepath];
            }
        }
    }
    [defaults setObject:newViewedCrashLogs forKey:kViewedCrashLogs];
    [defaults synchronize];
    [newViewedCrashLogs release];
    [existentFilepaths release];

    return [groups allValues];
}

static NSInteger compareCrashLogGroups(CrashLogGroup *a, CrashLogGroup *b, void *context) {
    return [[a name] compare:[b name] options:NSCaseInsensitiveSearch];
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
    if (mobileCrashLogGroups$ == nil) {
        NSArray *groups = crashLogGroupsForDirectory(@kCrashLogDirectoryForMobile);
        mobileCrashLogGroups$ = [[groups sortedArrayUsingFunction:compareCrashLogGroups context:NULL] mutableCopy];
    }
    return mobileCrashLogGroups$;
}

+ (NSArray *)groupsForRoot {
    if (rootCrashLogGroups$ == nil) {
        NSArray *groups = crashLogGroupsForDirectory(@kCrashLogDirectoryForRoot);
        rootCrashLogGroups$ = [[groups sortedArrayUsingFunction:compareCrashLogGroups context:NULL] mutableCopy];
    }
    return rootCrashLogGroups$;
}

+ (void)forgetGroups {
    [mobileCrashLogGroups$ release];
    mobileCrashLogGroups$ = nil;
    [rootCrashLogGroups$ release];
    rootCrashLogGroups$ = nil;
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
    // Delete contained crash logs.
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

    // Remove group from global array.
    NSMutableArray *crashLogGroups = [[self logDirectory] isEqualToString:@kCrashLogDirectoryForMobile] ?
        mobileCrashLogGroups$ : rootCrashLogGroups$;
    [crashLogGroups removeObject:self];

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
