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
#import <libcrashreport/libcrashreport.h>
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
@synthesize logName = logName_;
@synthesize logDate = logDate_;
@synthesize victim = victim_;
@synthesize suspects = suspects_;
@synthesize potentialSuspects = potentialSuspects_;
@synthesize loaded = loaded_;
@synthesize viewed = viewed_;

@dynamic symbolicated;

#pragma mark - Creation & Destruction

// NOTE: Filename part of path must be of the form [app_name]_date_device-name.
//       The device-name cannot contain underscores.
// TODO: Is it possible for device-name to have an underscore?
+ (instancetype)crashLogWithFilepath:(NSString *)filepath {
    NSString *basename = [[filepath lastPathComponent] stringByDeletingPathExtension];
    NSArray *matches = [basename captureComponentsMatchedByRegex:@"(.+)_(\\d{4})-(\\d{2})-(\\d{2})-(\\d{2})(\\d{2})(\\d{2})_[^_]+"];
    if ([matches count] == 8) {
        return [[[self alloc] initWithFilepath:filepath matches:matches] autorelease];
    } else {
        return nil;
    }
}

- (instancetype)initWithFilepath:(NSString *)filepath matches:(NSArray *)matches {
    self = [super init];
    if (self != nil) {
        filepath_ = [filepath copy];
        logName_ = [[matches objectAtIndex:1] copy];

        // Parse the date.
        NSDateComponents *components = [[NSDateComponents alloc] init];
        [components setYear:[[matches objectAtIndex:2] integerValue]];
        [components setMonth:[[matches objectAtIndex:3] integerValue]];
        [components setDay:[[matches objectAtIndex:4] integerValue]];
        [components setHour:[[matches objectAtIndex:5] integerValue]];
        [components setMinute:[[matches objectAtIndex:6] integerValue]];
        [components setSecond:[[matches objectAtIndex:7] integerValue]];
        logDate_ = [[calendar() dateFromComponents:components] retain];
        [components release];
    }
    return self;
}

- (void)dealloc {
    [filepath_ release];
    [logName_ release];
    [logDate_ release];
    [victim_ release];
    [suspects_ release];
    [potentialSuspects_ release];
    [super dealloc];
}

#pragma mark - Loading

static NSInteger compareBinaryImagePaths(CRBinaryImage *binaryImage1, CRBinaryImage *binaryImage2, void *context) {
    NSString *name1 = [[binaryImage1 path] lastPathComponent];
    NSString *name2 = [[binaryImage2 path] lastPathComponent];
    return [name1 compare:name2];
}

- (BOOL)load {
    if (!loaded_) {
        NSString *filepath = [self filepath];
        NSData *data = dataForFile(filepath);
        if (data != nil) {
            CRCrashReport *report = [[CRCrashReport alloc] initWithData:data filterType:CRCrashReportFilterTypePackage];
            if (report != nil) {
                // Symbolicate (and blame) if necessary.
                if (!fileIsSymbolicated(filepath, report)) {
                    // Symbolicate.
                    NSString *outputFilepath = symbolicateFile(filepath, report);
                    if (outputFilepath != nil) {
                        // Update name used for determining viewed state.
                        if ([self isViewed]) {
                            deleteViewedState(filepath);
                            saveViewedState(outputFilepath);
                        }

                        // Update path for this crash log instance.
                        [filepath_ release];
                        filepath_ = [outputFilepath retain];
                    } else {
                        [report release];
                        return NO;
                    }
                } else {
                    // Reprocess blame for log files that were symbolicated with
                    // older versions of CrashReporter.
                    // NOTE: The output format changed with the release of
                    //       v1.8.0 (libcrashreport v1.0.0). Must reprocess
                    //       blame in order to retrieve blamable binary images.
                    // NOTE: Give users a two-week window to upgrade.
                    // TODO: Consider removing this at some point in the future.
                    const NSTimeInterval intervalAsOf20140901 = 431222400.0;
                    if ([[self logDate] timeIntervalSinceReferenceDate] < intervalAsOf20140901) {
                        [report blame];
                    }
                }

                // Determine path for victim.
                NSString *victimPath = [[report processInfo] objectForKey:@"Path"];

                // Collect victim and potential suspects.
                NSMutableDictionary *blamableBinaries = [[NSMutableDictionary alloc] init];
                for (CRBinaryImage *binaryImage in [[report binaryImages] allValues]) {
                    NSString *path = [binaryImage path];
                    if ([path isEqualToString:victimPath]) {
                        NSAssert(victim_ == nil, @"ERROR: Two binary images have the exact same path.");
                        victim_ = [binaryImage retain];
                    } else if ([binaryImage isBlamable]) {
                        [blamableBinaries setObject:binaryImage forKey:path];
                    }
                }

                // Collect suspects.
                NSMutableArray *suspects = [[NSMutableArray alloc] init];
                NSArray *suspectPaths = [[report properties] objectForKey:kCrashReportBlame];
                for (NSString *suspectPath in suspectPaths) {
                    CRBinaryImage *binaryImage = [blamableBinaries objectForKey:suspectPath];
                    if (binaryImage != nil) {
                        [suspects addObject:binaryImage];
                        [blamableBinaries removeObjectForKey:suspectPath];
                    }
                }
                suspects_ = suspects;

                // Collect potential suspects.
                potentialSuspects_ = [[[blamableBinaries allValues] sortedArrayUsingFunction:compareBinaryImagePaths context:NULL] retain];
                [blamableBinaries release];

                // Ensure that we at least have information for the victim.
                // NOTE: Some reports do not contain binary image information.
                if (victim_ == nil) {
                    victim_ = [[CRBinaryImage alloc] initWithPath:victimPath address:0 size:0 architecture:nil uuid:nil];
                }

                // Clean-up.
                [report release];

                loaded_ = YES;
            }
        }
    }

    return loaded_;
}

#pragma mark - Properties

- (CrashLogType)type {
    return CrashLogTypeApp;
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

    const BOOL didDelete = deleteFile(filepath);
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

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
