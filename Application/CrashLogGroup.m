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

static NSInteger reverseCompareCrashLogs(CrashLog *a, CrashLog *b, void *context) {
    return [[b filepath] compare:[a filepath]];
}

@implementation CrashLogGroup {
    NSMutableArray *crashLogs_;
}

@synthesize name = name_;
@synthesize logDirectory = logDirectory_;

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
