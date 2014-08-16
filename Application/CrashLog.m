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
@synthesize processPath = processPath_;
@synthesize blamableBinaries = blamableBinaries_;
@synthesize suspects = suspects_;
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
            logName_ = [[matches objectAtIndex:1] copy];

            // Parse the date.
            NSDateComponents *components = [NSDateComponents new];
            [components setYear:[[matches objectAtIndex:2] integerValue]];
            [components setMonth:[[matches objectAtIndex:3] integerValue]];
            [components setDay:[[matches objectAtIndex:4] integerValue]];
            [components setHour:[[matches objectAtIndex:5] integerValue]];
            [components setMinute:[[matches objectAtIndex:6] integerValue]];
            [components setSecond:[[matches objectAtIndex:7] integerValue]];
            logDate_ = [[calendar() dateFromComponents:components] retain];
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
    [logName_ release];
    [logDate_ release];
    [processPath_ release];
    [blamableBinaries_ release];
    [suspects_ release];
    [super dealloc];
}

#pragma mark - Properties

static NSInteger compareBinaryImagePaths(CRBinaryImage *binaryImage1, CRBinaryImage *binaryImage2, void *context) {
    NSString *name1 = [[binaryImage1 path] lastPathComponent];
    NSString *name2 = [[binaryImage2 path] lastPathComponent];
    return [name1 compare:name2];
}

- (NSArray *)blamableBinaries {
    if (blamableBinaries_ == nil) {
        if ([self isSymbolicated]) {
            NSData *data = dataForFile([self filepath]);
            if (data != nil) {
                CRCrashReport *report = [[CRCrashReport alloc] initWithData:data filterType:CRCrashReportFilterTypePackage];
                if (report != nil) {
                    // Process blame to mark which binary images are blamable.
                    [report blame];

                    // Collect blamable images.
                    NSString *processPath = [self processPath];
                    NSMutableArray *blamableBinaries = [NSMutableArray new];
                    for (CRBinaryImage *binaryImage in [[report binaryImages] allValues]) {
                        if ([binaryImage isBlamable]) {
                            if (![[binaryImage path] isEqualToString:processPath]) {
                                [blamableBinaries addObject:binaryImage];
                            }
                        }
                    }
                    [blamableBinaries sortUsingFunction:compareBinaryImagePaths context:NULL];
                    blamableBinaries_ = blamableBinaries;
                    [report release];
                }
            }
        }
    }
    return blamableBinaries_;
}

- (NSString *)processPath {
    if (processPath_ == nil) {
        NSData *data = dataForFile([self filepath]);
        if (data != nil) {
            CRCrashReport *report = [[CRCrashReport alloc] initWithData:data filterType:CRCrashReportFilterTypePackage];
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
                CRCrashReport *report = [[CRCrashReport alloc] initWithData:data filterType:CRCrashReportFilterTypePackage];
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
