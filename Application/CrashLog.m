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

#import <libcrashreport/libcrashreport.h>
#import <libpackageinfo/libpackageinfo.h>
#import "crashlog_util.h"

#include <unicode/uregex.h>

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

@interface CrashLog ()
@property (nonatomic, readonly) CRCrashReport *report;
@end

@implementation CrashLog

@synthesize filepath = filepath_;
@synthesize logName = logName_;
@synthesize logDate = logDate_;
@synthesize type = type_;
@synthesize victim = victim_;
@synthesize suspects = suspects_;
@synthesize potentialSuspects = potentialSuspects_;
@synthesize loaded = loaded_;
@synthesize viewed = viewed_;

@synthesize report = report_;

@dynamic symbolicated;

#pragma mark - Creation & Destruction

// TODO: Versions of the following static functions also exist in
//       libcrashreport. Consider combining and moving to the Common module.
static URegularExpression *prepareRegularExpression(const char *pattern) {
    UParseError error;
    UErrorCode status = U_ZERO_ERROR;
    URegularExpression *regex = uregex_openC(pattern, 0, &error, &status);
    if (U_FAILURE(status)) {
        fprintf(stderr, "ERROR: Failed to compile regular expression: %s\n", u_errorName(status));
    }
    return regex;
}

static BOOL matchesRegularExpression(URegularExpression *regex, NSString *string) {
    BOOL result = NO;

    const UChar *data = (const uint16_t *)[string cStringUsingEncoding:NSUTF16StringEncoding];
    const size_t size = [string length];

    UErrorCode status = U_ZERO_ERROR;
    uregex_setText(regex, data, size, &status);
    if (U_SUCCESS(status)) {
        status = U_ZERO_ERROR;
        UBool matches = uregex_matches(regex, 0, &status);
        if (U_SUCCESS(status)) {
            result = (BOOL)matches;
        } else {
            fprintf(stderr, "ERROR: Failed to check for match against regular expression: %s\n", u_errorName(status));
        }
    } else {
        fprintf(stderr, "ERROR: Failed to set string to match against regular expression: %s\n", u_errorName(status));
    }

    return result;
}


static NSString *newStringFromMatch(URegularExpression *regex, unsigned groupIndex) {
    NSString *result = nil;

    UErrorCode status = U_ZERO_ERROR;
    int32_t length = uregex_group(regex, groupIndex, NULL, 0, &status);
    if (status == U_BUFFER_OVERFLOW_ERROR) {
        UChar *buf = (UChar *)malloc(length * sizeof(UChar));
        if (buf != NULL) {
            status = U_ZERO_ERROR;
            uregex_group(regex, groupIndex, buf, length, &status);
            if (U_SUCCESS(status)) {
                result = [[NSString alloc] initWithCharacters:(const unichar *)buf length:length];
            }
            free(buf);
        }
    }

    return result;
}

static int intFromString(const char *string, int length) {
    int result = 0;
    int i;
    for (i = 0; i < length; ++i) {
        char c = string[i];
        if ((c >= '0') && (c <= '9')) {
            result = result * 10 + (c - '0');
        } else {
            break;
        }
    }
    return result;
}

static int intFromMatch(URegularExpression *regex, unsigned groupIndex) {
    int result = 0;

    NSString *string = newStringFromMatch(regex, groupIndex);
    if (string != nil) {
        const char *cstr = [string UTF8String];
        result = intFromString(cstr, strlen(cstr));
        [string release];
    }

    return result;
}

// NOTE: Filename part of path must be of the form [app_name]_date_device-name.
//       The device-name cannot contain underscores.
// TODO: Is it possible for device-name to have an underscore?
+ (instancetype)crashLogWithFilepath:(NSString *)filepath {
    id object = nil;

    static const char * const kRegexLogNameDate = "(.+)_(\\d{4})-(\\d{2})-(\\d{2})-(\\d{2})(\\d{2})(\\d{2})_[^_]+";
    NSString *basename = [[filepath lastPathComponent] stringByDeletingPathExtension];

    URegularExpression *regex = prepareRegularExpression(kRegexLogNameDate);
    if (regex != NULL) {
        if (matchesRegularExpression(regex, basename)) {
            // Determine the log name.
            NSString *name = newStringFromMatch(regex, 1);
            if (name != nil) {
                // Parse the log date.
                NSDateComponents *components = [[NSDateComponents alloc] init];
                [components setYear:intFromMatch(regex, 2)];
                [components setMonth:intFromMatch(regex, 3)];
                [components setDay:intFromMatch(regex, 4)];
                [components setHour:intFromMatch(regex, 5)];
                [components setMinute:intFromMatch(regex, 6)];
                [components setSecond:intFromMatch(regex, 7)];
                NSDate *date = [calendar() dateFromComponents:components];
                [components release];

                object = [[[self alloc] initWithFilepath:filepath name:name date:date] autorelease];

                [name release];
            }
        }

        uregex_close(regex);
    }

    return object;
}

- (instancetype)initWithFilepath:(NSString *)filepath name:(NSString *)name date:(NSDate *)date {
    self = [super init];
    if (self != nil) {
        filepath_ = [filepath copy];
        logName_ = [name copy];
        logDate_ = [date retain];
        type_ = CrashLogTypeUnknown;
    }
    return self;
}

- (void)dealloc {
    [report_ release];
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
        CRCrashReport *report = [self report];
        if (report != nil) {
            NSString *filepath = [self filepath];

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
                    // Filter out trusted packages.
                    NSString *identifier = binaryImage.package.identifier;
                    if (![identifier isEqualToString:@"mobilesubstrate"]) {
                        [blamableBinaries setObject:binaryImage forKey:path];
                    }
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

            loaded_ = YES;
        }
    }

    return loaded_;
}

#pragma mark - Properties

- (CRCrashReport *)report {
    if (report_ == nil) {
        NSString *filepath = [self filepath];
        NSData *data = dataForFile(filepath);
        if (data != nil) {
            report_ = [[CRCrashReport alloc] initWithData:data filterType:CRCrashReportFilterTypePackage];
        }
    }
    return report_;
}

- (CrashLogType)type {
    if (type_ == CrashLogTypeUnknown) {
        type_ = CrashLogTypeService;

        // Determine bundle path.
        // NOTE: Process may not be from a bundle.
        NSString *bundlePath = nil;
        NSString *processPath = [[[self report] processInfo] objectForKey:@"Path"];
        NSArray *components = [processPath componentsSeparatedByString:@"/"];
        for (NSUInteger n = [components count]; n > 0; --n) {
            NSString *component = [components objectAtIndex:(n - 1)];
            if (
                [component hasSuffix:@".app"] ||
                [component hasSuffix:@".appex"]
               ) {
                bundlePath = [[components subarrayWithRange:NSMakeRange(0, n)] componentsJoinedByString:@"/"];
                break;
            }
        }

        if (bundlePath != nil) {
            // Use bundle path to determine type.
            NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
            if (bundle != nil) {
                char *executablePath = realpath([[bundle executablePath] UTF8String], NULL);
                if (executablePath != NULL) {
                    if (strcmp(executablePath, [processPath UTF8String]) == 0) {
                        NSDictionary *infoDictionary = [bundle infoDictionary];
                        id object = [infoDictionary objectForKey:@"CFBundlePackageType"];
                        if ([object isKindOfClass:[NSString class]]) {
                            NSString *packageType = object;
                            if ([packageType isEqualToString:@"APPL"]) {
                                type_ = CrashLogTypeApp;
                            } else if ([packageType isEqualToString:@"XPC!"]) {
                                object = [infoDictionary objectForKey:@"NSExtension"];
                                if (object != nil) {
                                    type_ = CrashLogTypeAppExtension;
                                }
                            }
                        }
                    }

                    free(executablePath);
                }
            } else {
                // Bundle no longer installed; make intelligent guess.
                // NOTE: This should always work for AppStore app bundles, but may be
                //       incorrect for other app bundles.
                if ([bundlePath hasSuffix:@".app"]) {
                    type_ = CrashLogTypeApp;
                } else if ([bundlePath hasSuffix:@".appex"]) {
                    type_ = CrashLogTypeAppExtension;
                }
            }
        }
    }

    return type_;
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
