/**
 * Name: notifier
 * Type: iOS command line tool
 * Desc: Given a crash log filepath, will send a local notification stating
 *       what has crashed and what might be to blame.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import <libcrashreport/libcrashreport.h>

#include <asl.h>
#include <dlfcn.h>
#include <errno.h>
#include <notify.h>
#include <objc/runtime.h>
#include <time.h>
#include <unistd.h>

#import "crashlog_util.h"
#include "preferences.h"

#define kNotifyExcessiveCPU "notifyExcessiveCPU"
#define kNotifyExcessiveMemory "notifyExcessiveMemory"
#define kNotifyExcessiveWakeups "notifyExcessiveWakeups"
#define kNotifyExecutionTimeouts "notifyExecutionTimeouts"
#define kNotifyLowMemory "notifyLowMemory"
#define kNotifySandboxViolations "notifySandboxViolations"

extern mach_port_t SBSSpringBoardServerPort();

// Firmware < 9.0
@interface SBSLocalNotificationClient : NSObject
+ (void)scheduleLocalNotification:(id)notification bundleIdentifier:(id)bundleIdentifier;
@end

// Firmware >= 9.0
@interface UNSNotificationSchedulerConnection : NSObject
+ (instancetype)sharedInstance;
- (void)addScheduledLocalNotifications:(NSArray *)notifications forBundleIdentifier:(NSString *)bundleIdentifier withCompletion:(id)completion;
@end

int main(int argc, char **argv, char **envp) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    if (IOS_LT(5_0)) {
        fprintf(stderr, "WARNING: CrashReporter notifications require iOS 5.0 or higher.\n");
        return 0;
    }

    // Get arguments.
    BOOL isDebugMode = NO;
    if (argc < 2) {
        fprintf(stderr, "ERROR: Must specify path to crash log.\n");
        return 1;
    }
    if ((argc > 2)) {
        if (strcmp(argv[1], "-d") == 0) {
            isDebugMode = YES;
        } else {
            fprintf(stderr, "ERROR: Unknown parameter.\n");
            return 1;
        }
    }
    NSString *filepath = [NSString stringWithFormat:@"%s", (isDebugMode ? argv[2] : argv[1])];

    // Load and parse the crash log.
    CRCrashReport *report = nil;
    NSData *data = dataForFile(filepath);
    if (data != nil) {
        report = [[CRCrashReport alloc] initWithData:data filterType:CRCrashReportFilterTypePackage];
        if (report == nil) {
            fprintf(stderr, "ERROR: Could not parse crash log file \"%s\".\n", [filepath UTF8String]);
            return 1;
        }
    } else {
        fprintf(stderr, "ERROR: Could not load crash log file \"%s\".\n", [filepath UTF8String]);
        return 1;
    }
    
    CRException *exception = [report exception];
    if ([[exception type] integerValue] == 20) {
        //Simulated Crash No Need To Report
        return 0;
    }

    if (!isDebugMode) {
        // Check freshness of crash log.
        // NOTE: This tool is only meant to be used with newly created crash log
        //       files; symbolication of older files should be done with the
        //       "symbolicate" tool.
        BOOL isTooOld = fileIsSymbolicated(filepath, report);
        if (!isTooOld) {
            // Check the date and time that the crash occurred.
            NSString *dateTime = [[report processInfo] objectForKey:@"Date/Time"];
            if (dateTime != nil) {
                NSDateFormatter *formatter = [NSDateFormatter new];
                [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS Z"];
                NSDate *date = [formatter dateFromString:dateTime];
                [formatter release];
                if ([date timeIntervalSinceNow] < -(2 * 60)) {
                    // Occurred more than two minutes ago.
                    isTooOld = YES;
                }
            }
        }
        if (isTooOld) {
            // Is already symbolicated or occurred too long ago.
            fprintf(stderr, "ERROR: This tool is only meant for use with recently-created, unsymbolicated crash reports.\n");
            return 1;
        }
    }

    // Determine the bundle identifier.
    // NOTE: This information is not available for versions of iOS prior to 7.0.
    NSDictionary *properties = [report properties];
    NSString *bundleID = [properties objectForKey:@"bundleID"];

    // Determine the name of the process.
    NSString *processName = [properties objectForKey:@"name"];

    // Capture syslog output via ASL (Apple System Log).
    // NOTE: Make sure not to overwrite file if it already exists.
    // NOTE: This should only be a concern if someone were to later manually
    //       call notifier on the same crash log file.
    NSFileManager *fileMan = [NSFileManager defaultManager];
    NSString *syslogPath = syslogPathForFile(filepath);
    if (![fileMan fileExistsAtPath:syslogPath]) {
        // NOTE: Do this here as the following symbolication may take some time,
        //       during which the syslog could change.
        NSMutableString *syslog = [NSMutableString new];
        aslmsg query = asl_new(ASL_TYPE_QUERY);
        aslresponse response = asl_search(NULL, query);
        aslmsg msg;
        while ((msg = aslresponse_next(response)) != NULL) {
            // NOTE: We could use asl_set_query() to filter the results with a
            //       regular expression, but it seems that ASL_QUERY_OP_REGEX does
            //       not work properly on older versions of iOS.
            const char *facility = asl_get(msg, ASL_KEY_FACILITY);
            const char *sender = asl_get(msg, ASL_KEY_SENDER);
            const char *bundleIDStr = (bundleID != nil) ? [bundleID UTF8String] : "";
            const char *processNameStr = (processName != nil) ? [processName UTF8String] : "";
            if (
                ((facility != NULL) && ((strcmp(facility, "Crash Reporter") == 0) || (strcmp(facility, bundleIDStr) == 0))) ||
                ((sender != NULL) && (strcmp(sender, processNameStr) == 0))
            ) {
                char time[25];
                time_t clock = atol(asl_get(msg, ASL_KEY_TIME));
                struct tm *timeptr = localtime(&clock);
                strftime(time, 25, "%c", timeptr);

                const char *message = asl_get(msg, ASL_KEY_MSG);
                [syslog appendFormat:@"%s: %s (%s): %s\n", time, sender, facility, message];
            }
        }
        aslresponse_free(response);
        asl_free(query);

        // If no syslog data is available, add a message stating such.
        if ([syslog length] == 0) {
            [syslog appendString:@"Syslog did not contain any relevant information."];
        }

        // Write syslog to file (if syslog data exists).
        NSError *error = nil;
        if (writeToFile(syslog, syslogPath)) {
            fixFileOwnershipAndPermissions(syslogPath);
        } else {
            fprintf(stderr, "WARNING: Failed to save syslog information to file: %s.\n", [[error localizedDescription] UTF8String]);
        }
        [syslog release];
    }

    // Determine the type of crash.
    NSDictionary *processInfo = [report processInfo];
    BOOL isSandboxViolation = ([processInfo objectForKey:@"Sandbox Violation"] != nil);

    // Symbolicate and determine blame.
    NSArray *suspects = nil;
    if (!isSandboxViolation) {
        NSString *outputFilepath = symbolicateFile(filepath, report);
        if (outputFilepath != nil) {
            // Update path for this crash log instance.
            filepath = outputFilepath;

            // Retrieve updated properties.
            properties = [report properties];

            // Retrieve list of suspects.
            suspects = [properties objectForKey:@"blame"];
        }
    }

    // Switch effective user to mobile (if not already mobile).
    // NOTE: Must do this in order to access mobile's preference settings.
    // TODO: Consider running all of notifier as mobile.
    seteuid(501);

    // Determine the bundle name.
    NSString *bundleName = [properties objectForKey:@"app_name"];
    if (bundleName == nil) {
        bundleName = [properties objectForKey:@"displayName"];
        if (bundleName == nil) {
            // NOTE: For sandbox violations, at least, bundle info is not
            //       included in the report.
            bundleName = [[processInfo objectForKey:@"Path"] lastPathComponent];
        }
    }

    // Create notification message, based on crash type.
    NSMutableString *body = nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (isSandboxViolation) {
        if ([defaults boolForKey:@kNotifySandboxViolations]) {
            body = [NSMutableString stringWithFormat:NSLocalizedString(@"NOTIFY_SANDBOX_VIOLATION", nil), bundleName];
        }
    } else {
        // Determine exception type.
        NSString *exceptionType = [processInfo objectForKey:@"Exception Type"];
        NSString *exceptionCode = [processInfo objectForKey:@"Exception Code"];
        if (exceptionCode == nil) {
            exceptionCode = [processInfo objectForKey:@"Exception Codes"];
        }
        if ([exceptionType isEqualToString:@"EXC_RESOURCE"]) {
            NSString *exceptionSubtype = [processInfo objectForKey:@"Exception Subtype"];
            if ([exceptionSubtype isEqualToString:@"CPU"]) {
                if ([defaults boolForKey:@kNotifyExcessiveCPU]) {
                    body = [NSMutableString stringWithFormat:NSLocalizedString(@"NOTIFY_EXCESS_CPU", nil), bundleName];
                }
            } else if ([exceptionSubtype isEqualToString:@"MEMORY"]) {
                if ([defaults boolForKey:@kNotifyExcessiveMemory]) {
                    body = [NSMutableString stringWithFormat:NSLocalizedString(@"NOTIFY_EXCESS_MEMORY", nil), bundleName];
                }
            } else if ([exceptionSubtype isEqualToString:@"WAKEUPS"]) {
                if ([defaults boolForKey:@kNotifyExcessiveWakeups]) {
                    body = [NSMutableString stringWithFormat:NSLocalizedString(@"NOTIFY_EXCESS_WAKEUPS", nil), bundleName];
                }
            }
        } else if ((exceptionCode != nil) && [exceptionCode rangeOfString:@"8badf00d"].location != NSNotFound) {
            // Execution timeout.
            if ([defaults boolForKey:@kNotifyExecutionTimeouts]) {
                body = [NSMutableString stringWithFormat:NSLocalizedString(@"NOTIFY_EXECUTION_TIMEOUT_TASK", nil), bundleName];
            }
        } else {
            NSInteger bugType = [[properties objectForKey:@"bug_type"] integerValue];
            switch (bugType) {
                case 198:
                    // Low memory.
                    if ([defaults boolForKey:@kNotifyLowMemory]) {
                        body = [NSMutableString stringWithString:NSLocalizedString(@"NOTIFY_LOW_MEMORY", nil)];
                        NSString *largestProcess = [processInfo objectForKey:@"Largest process"];
                        if (largestProcess != nil) {
                            [body appendString:@"\n"];
                            [body appendFormat:NSLocalizedString(@"NOTIFY_LARGEST_PROCESS", nil), largestProcess];
                        }
                    }
                    break;
                case 109:
                    // Crash.
                    body = [NSMutableString stringWithFormat:NSLocalizedString(@"NOTIFY_CRASHED", nil), bundleName];
                    [body appendString:@"\n"];
                    if ([suspects count] > 0) {
                        [body appendFormat:NSLocalizedString(@"NOTIFY_MAIN_SUSPECT", nil), [[suspects objectAtIndex:0] lastPathComponent]];
                    } else {
                        [body appendString:NSLocalizedString(@"NOTIFY_NO_SUSPECTS", nil)];
                    }
                    break;
                default:
                    break;
            }
        }
    }

    __block BOOL notificationHasCompleted = YES;
    if (body != nil) {
        // Make sure that SpringBoard's local notification server is up.
        // NOTE: If SpringBoard is not running (i.e. it is what crashed), will
        //       not be able to register a local notification.
        // FIXME: Even if port is non-zero, it does not mean that SpringBoard is
        //        ready to handle notifications.
        BOOL shouldDelay = NO;
        mach_port_t port;
        while ((port = SBSSpringBoardServerPort()) == 0) {
            [NSThread sleepForTimeInterval:1.0];
            shouldDelay = YES;
        }

        if (shouldDelay) {
            // Wait serveral seconds to give time for SpringBoard to finish launching.
            // FIXME: This is needed due to issue mentioned above. The time
            //        interval was chosen arbitrarily and may not be long enough
            //        in some cases.
            [NSThread sleepForTimeInterval:20.0];
        }

        // Load UIKit framework.
        void *handle = dlopen("/System/Library/Frameworks/UIKit.framework/UIKit", RTLD_LAZY);
        if (handle != NULL) {
            // Send the notification.
            UILocalNotification *notification = [objc_getClass("UILocalNotification") new];
            [notification setAlertBody:body];
            [notification setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:filepath, @"filepath", nil]];

            // Increment and request update of icon badge number.
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSInteger crashesSinceLastLaunch = 1 + [defaults integerForKey:@kCrashesSinceLastLaunch];
            [defaults setInteger:crashesSinceLastLaunch forKey:@kCrashesSinceLastLaunch];
            [defaults synchronize];
            [notification setApplicationIconBadgeNumber:crashesSinceLastLaunch];

            // NOTE: Passing nil as the action will cause iOS to display "View" (localized).
            [notification setHasAction:YES];
            [notification setAlertAction:nil];

            // NOTE: Notification will be shown immediately as no fire date was set.
            if (IOS_LT(9_0)) {
                [SBSLocalNotificationClient scheduleLocalNotification:notification bundleIdentifier:@"crash-reporter"];
            } else {
                notificationHasCompleted = NO;

                void *handle = dlopen("/System/Library/PrivateFrameworks/UserNotificationServices.framework/UserNotificationServices", RTLD_LAZY);
                if (handle != NULL) {
                    [[objc_getClass("UNSNotificationSchedulerConnection") sharedInstance] addScheduledLocalNotifications:
                        [NSArray arrayWithObject:notification] forBundleIdentifier:@"crash-reporter" withCompletion:^(){ notificationHasCompleted = YES; }];
                    dlclose(handle);
                }
            }
            [notification release];

            dlclose(handle);
        }
    }

    // Post a Darwin notification.
    notify_post("jp.ashikase.crashreporter.notifier.crash");

    // Must execute the run loop once so the above is processed.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);

    // Must wait for local notification scheduler to complete (iOS 9+).
    while (!notificationHasCompleted) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
    }

    [report release];
    [pool release];
    return 0;
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
