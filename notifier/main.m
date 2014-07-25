/**
 * Name: notifier
 * Type: iOS command line tool
 * Desc: Given a crash log filepath, will send a local notification stating
 *       what has crashed and what might be to blame.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import <libsymbolicate/CRCrashReport.h>

#include <asl.h>
#include <dlfcn.h>
#include <errno.h>
#include <objc/runtime.h>
#include <time.h>
#include <unistd.h>

#import "crashlog_util.h"

extern mach_port_t SBSSpringBoardServerPort();

@interface SBSLocalNotificationClient : NSObject
+ (void)scheduleLocalNotification:(id)notification bundleIdentifier:(id)bundleIdentifier;
@end

int main(int argc, char **argv, char **envp) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    if (IOS_LT(5_0)) {
        fprintf(stderr, "WARNING: CrashReporter notifications require iOS 5.0 or higher.\n");
        return 0;
    }

    // Get arguments.
    if (argc != 2) {
        fprintf(stderr, "ERROR: Must specify path to crash log.\n");
        return 1;
    }
    NSString *filepath = [NSString stringWithFormat:@"%s", argv[1]];

    // Load and parse the crash log.
    CRCrashReport *report = [[CRCrashReport alloc] initWithFile:filepath];
    if (report == nil) {
        fprintf(stderr, "ERROR: Could not load or parse crash log.\n");
        return 1;
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
    NSString *syslogPath = [[filepath stringByDeletingPathExtension] stringByAppendingPathExtension:@"syslog"];
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
                (strcmp(facility, "Crash Reporter") == 0) ||
                (strcmp(facility, bundleIDStr) == 0) ||
                (strcmp(sender, processNameStr) == 0)
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

        // Write syslog to file.
        // NOTE: Syslog may be empty.
        NSError *error = nil;
        if (writeToFile(syslog, syslogPath)) {
            fixFileOwnership(syslogPath);
        } else {
            fprintf(stderr, "WARNING: Failed to save syslog information to file: %s.\n", [[error localizedDescription] UTF8String]);
        }
        [syslog release];
    }

    // Symbolicate and determine blame.
    NSArray *suspects = nil;
    NSString *outputFilepath = symbolicateFile(filepath, report);
    if  (outputFilepath != nil) {
        // Update path for this crash log instance.
        filepath = outputFilepath;

        // Retrieve list of suspects.
        suspects = [properties objectForKey:@"blame"];
    }

    // Determine the bundle name.
    NSString *bundleName = [properties objectForKey:@"app_name"];
    if (bundleName == nil) {
        bundleName = [properties objectForKey:@"displayName"];
    }

    // Create notification message.
    NSMutableString *body = [NSMutableString stringWithFormat:NSLocalizedString(@"NOTIFY_CRASHED", nil), bundleName];
    [body appendString:@"\n"];
    if ([suspects count] > 0) {
        [body appendFormat:NSLocalizedString(@"NOTIFY_MAIN_SUSPECT", nil), [[suspects objectAtIndex:0] lastPathComponent]];
    } else {
        [body appendString:NSLocalizedString(@"NOTIFY_NO_SUSPECTS", nil)];
    }
    [report release];

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

    // Send the notification.
    UILocalNotification *notification = [objc_getClass("UILocalNotification") new];
    [notification setAlertBody:body];
    [notification setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:filepath, @"filepath", nil]];

    // FIXME: Determine how to increase the current badge number.
    [notification setApplicationIconBadgeNumber:1];

    // NOTE: Passing nil as the action will cause iOS to display "View" (localized).
    [notification setHasAction:YES];
    [notification setAlertAction:nil];

    // NOTE: Notification will be shown immediately as no fire date was set.
    [SBSLocalNotificationClient scheduleLocalNotification:notification bundleIdentifier:@"crash-reporter"];
    [notification release];

    // Must execute the run loop once so the above is processed.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);

    dlclose(handle);
    [pool release];
    return 0;
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
