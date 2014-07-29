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

#import "CrashLog.h"

#import <RegexKitLite/RegexKitLite.h>
#import <libsymbolicate/CRCrashReport.h>
#import "crashlog_util.h"

NSString * const kViewedCrashLogs = @"viewedCrashLogs";

static NSCalendar *calendar() {
    static NSCalendar *calendar = nil;
    if (calendar == nil) {
        calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    }
    return calendar;
}

static void deleteViewedState(NSString *filepath) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *viewedCrashLogs = [defaults arrayForKey:kViewedCrashLogs];
    if ([viewedCrashLogs containsObject:filepath]) {
        NSMutableArray *array = [[NSMutableArray alloc] initWithArray:viewedCrashLogs];
        [array removeObject:filepath];
        [defaults setObject:array forKey:kViewedCrashLogs];
        [defaults synchronize];
        [array release];
    }
}

static void saveViewedState(NSString *filepath) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *viewedCrashLogs = [defaults arrayForKey:kViewedCrashLogs];
    if (![viewedCrashLogs containsObject:filepath]) {
        NSMutableArray *array = [[NSMutableArray alloc] initWithArray:viewedCrashLogs];
        [array addObject:filepath];
        [defaults setObject:array forKey:kViewedCrashLogs];
        [defaults synchronize];
        [array release];
    }
}

@implementation CrashLog

@synthesize filepath = filepath_;
@synthesize processName = processName_;
@synthesize processPath = processPath_;
@synthesize suspects = suspects_;
@synthesize date = date_;
@synthesize viewed = viewed_;

@dynamic symbolicated;

// NOTE: Filename part of path must be of the form [app_name]_date_device-name.
//       The device-name cannot contain underscores.
- (instancetype)initWithFilepath:(NSString *)filepath {
    self = [super init];
    if (self != nil) {
        NSString *basename = [[filepath lastPathComponent] stringByDeletingPathExtension];
        NSArray *matches = [basename captureComponentsMatchedByRegex:@"(.+)_(\\d{4})-(\\d{2})-(\\d{2})-(\\d{2})(\\d{2})(\\d{2})_[^_]+"];
        if ([matches count] == 8) {
            filepath_ = [filepath copy];
            processName_ = [[matches objectAtIndex:1] copy];

            // Parse the date.
            NSDateComponents *components = [NSDateComponents new];
            [components setYear:[[matches objectAtIndex:2] integerValue]];
            [components setMonth:[[matches objectAtIndex:3] integerValue]];
            [components setDay:[[matches objectAtIndex:4] integerValue]];
            [components setHour:[[matches objectAtIndex:5] integerValue]];
            [components setMinute:[[matches objectAtIndex:6] integerValue]];
            [components setSecond:[[matches objectAtIndex:7] integerValue]];
            date_ = [[calendar() dateFromComponents:components] retain];
            [components release];
        } else {
            // Filename is invalid.
            [self release];
            self = nil;
        }
    }
    return self;
}

- (void)dealloc {
    [filepath_ release];
    [processName_ release];
    [processPath_ release];
    [suspects_ release];
    [date_ release];
    [super dealloc];
}

#pragma mark - Properties

- (NSString *)processPath {
    if (processPath_ == nil) {
        NSData *data = dataForFile([self filepath]);
        if (data != nil) {
            CRCrashReport *report = [[CRCrashReport alloc] initWithData:data];
            processPath_ = [[[report processInfo] objectForKey:@"Path"] retain];
            [report release];
        }
    }
    return processPath_;
}

- (NSArray *)suspects {
    if (suspects_ == nil) {
        if ([self isSymbolicated]) {
            NSData *data = dataForFile([self filepath]);
            if (data != nil) {
                CRCrashReport *report = [[CRCrashReport alloc] initWithData:data];
                if (report != nil) {
                    suspects_ = [[[report properties] objectForKey:@"blame"] retain];
                    [report release];
                }
            }
        }
    }
    return suspects_;
}

- (BOOL)isSymbolicated {
    return fileIsSymbolicated([self filepath], nil);
}

- (BOOL)isViewed {
    // NOTE: Once a log has been viewed, it cannot be unviewed.
    if (!viewed_) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *filepath = [self filepath];
        viewed_ = [[defaults arrayForKey:kViewedCrashLogs] containsObject:filepath];
    }
    return viewed_;
}

- (void)setViewed:(BOOL)viewed {
    if (viewed_ != viewed) {
        if (!viewed_) {
            saveViewedState([self filepath]);
            viewed_ = YES;
        }
    }
}

#pragma mark - Other

- (BOOL)delete {
    NSString *filepath = [self filepath];

    BOOL didDelete = deleteFile(filepath);
    if (didDelete) {
        // Also delete the associated syslog file.
        // TODO: Should also update any associated "Latest-" links.
        NSString *syslogPath = syslogPathForFile(filepath);
        if (syslogPath != nil) {
            deleteFile(syslogPath);
        }

        // Remove from list of viewed entries.
        if ([self isViewed]) {
            deleteViewedState(filepath);
        }
    }
    return didDelete;
}

- (BOOL)symbolicate {
    BOOL didSymbolicate = NO;

    if (![self isSymbolicated]) {
        // Symbolicate.
        NSString *inputFilepath = [self filepath];
        NSString *outputFilepath = symbolicateFile(inputFilepath, nil);
        if (outputFilepath != nil) {
            // Update name used for determining viewed state.
            if ([self isViewed]) {
                deleteViewedState(inputFilepath);
                saveViewedState(outputFilepath);
            }

            // Update path for this crash log instance.
            filepath_ = [outputFilepath retain];

            // Note that symbolication succeeded.
            didSymbolicate = YES;
        }
    }

    return didSymbolicate;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
