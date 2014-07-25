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

#include "exec_as_root.h"

NSString * const kViewedCrashLogs = @"viewedCrashLogs";

static const char * const kTempFilepath = "/tmp/CrashReporter.XXXXXX";

static NSCalendar *calendar() {
    static NSCalendar *calendar = nil;
    if (calendar == nil) {
        calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    }
    return calendar;
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
        NSString *filepath = [self filepath];
        CRCrashReport *report = [[CRCrashReport alloc] initWithFile:filepath];
        processPath_ = [[[report processInfo] objectForKey:@"Path"] retain];
        [report release];
    }
    return processPath_;
}

- (BOOL)isSymbolicated {
    // NOTE: This assumes that symbolicated files have a specific extension,
    //       which may not be the case if the file was symbolicated by a
    //       tool other than CrashReporter.
    NSString *basename = [[[self filepath] lastPathComponent] stringByDeletingPathExtension];
    return [basename hasSuffix:@".symbolicated"];
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

static BOOL deleteFileAtPath(NSString *filepath) {
    if ([[NSFileManager defaultManager] removeItemAtPath:filepath error:NULL]) {
        // Successfullly deleted.
        return YES;
    } else {
        // Try to delete as root.
        return delete_as_root([filepath UTF8String]);
    }
}

- (BOOL)delete {
    NSString *filepath = [self filepath];

    BOOL didDelete = deleteFileAtPath(filepath);
    if (didDelete) {
        if ([self isViewed]) {
            // Must remove from list of viewed entries.
            deleteViewedState(filepath);
        }
    }
    return didDelete;
}

- (void)symbolicate {
    if (![self isSymbolicated]) {
        NSString *filepath = [self filepath];

        // Check if file is readable.
        NSString *actualFilepath = nil;
        NSFileManager *fileMan = [NSFileManager defaultManager];
        if (![fileMan isReadableFileAtPath:filepath]) {
            // Copy file to temporary directory.
            char tempFilepath[strlen(kTempFilepath) + 1 ];
            memcpy(tempFilepath, kTempFilepath, sizeof(tempFilepath));
            if (mktemp(tempFilepath) == NULL) {
                NSLog(@"ERROR: Unable to create temporary filepath.");
                return;
            }
            if (!copy_as_root([filepath UTF8String], tempFilepath)) {
                NSLog(@"ERROR: Failed to move file to temorary filepath.");
                return;
            }

            actualFilepath = filepath;
            filepath = [NSString stringWithCString:tempFilepath encoding:NSUTF8StringEncoding];
        }

        // Load crash report.
        CRCrashReport *report = [[CRCrashReport alloc] initWithFile:filepath];

        // Symbolicate.
        if ([report symbolicate]) {
            // Process blame.
            NSDictionary *filters = [[NSDictionary alloc] initWithContentsOfFile:@"/etc/symbolicate/blame_filters.plist"];
            if ([report blameUsingFilters:filters]) {
                // Write output to file.
                NSString *outputFilepath = [NSString stringWithFormat:@"%@.symbolicated.%@",
                        [filepath stringByDeletingPathExtension], [filepath pathExtension]];
                NSError *error = nil;
                if ([[report stringRepresentation] writeToFile:outputFilepath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
                    // Delete input file.
                    if (!deleteFileAtPath(filepath)) {
                        NSLog(@"ERROR: Failed to delete original log file.\n");
                    }

                    if (actualFilepath != nil) {
                        // Move symbolicated file to actual directory.
                        NSString *actualOutputFilepath = [NSString stringWithFormat:@"%@.symbolicated.%@",
                                 [actualFilepath stringByDeletingPathExtension], [actualFilepath pathExtension]];
                        if (move_as_root([outputFilepath UTF8String], [actualOutputFilepath UTF8String])) {
                            // Delete actual file.
                            if (!delete_as_root([actualFilepath UTF8String])) {
                                NSLog(@"ERROR: Failed to delete original root-owned log file.\n");
                            }
                        } else {
                            NSLog(@"ERROR: Failed to move symbolicated log file back to original directory.\n");
                        }

                        // Update name used for determining viewed state.
                        if ([self isViewed]) {
                            deleteViewedState(actualFilepath);
                            saveViewedState(actualOutputFilepath);
                        }

                        // Update path for this crash log instance.
                        filepath_ = [actualOutputFilepath retain];
                    } else {
                        // Update name used for determining viewed state.
                        if ([self isViewed]) {
                            deleteViewedState(filepath);
                            saveViewedState(outputFilepath);
                        }

                        // Update path for this crash log instance.
                        filepath_ = [outputFilepath retain];
                    }

                    // Record list of suspects.
                    suspects_ = [[[report properties] objectForKey:@"blame"] retain];
                } else {
                    NSLog(@"ERROR: Unable to write to file \"%@\": %@.", outputFilepath, [error localizedDescription]);
                }
            } else {
                NSLog(@"ERROR: Failed to process blame.");
            }
            [filters release];
        } else {
            NSLog(@"ERROR: Unable to symbolicate file \"%@\".", filepath);
        }

        [report release];
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
