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

#include <dlfcn.h>
#include <objc/runtime.h>

extern "C" mach_port_t SBSSpringBoardServerPort();

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

    // Symbolicate the report.
    // FIXME: Save the result with the "symbolicated" suffix so that CrashReporter
    //        will detect it and not symbolicate it again.
    [report symbolicate];

    // Determine possible cause of the crash.
    NSDictionary *filters = [[NSDictionary alloc] initWithContentsOfFile:@"/etc/symbolicate/blame_filters.plist"];
    if (![report blameUsingFilters:filters]) {
        fprintf(stderr, "WARNING: Failed to process blame.\n");
    }
    NSDictionary *properties = [report properties];
    NSArray *suspects = [properties objectForKey:@"blame"];
    [filters release];

    // Determine the name of the process.
    NSString *name = [properties objectForKey:@"app_name"];
    if (name == nil) {
        name = [properties objectForKey:@"name"];
    }

    NSMutableString *body = [NSMutableString stringWithFormat:@"\"%@\" has crashed.\n", name];
    if ([suspects count] > 0) {
        [body appendFormat:@"\"%@\" is main suspect.", [[suspects objectAtIndex:0] lastPathComponent]];
    } else {
        [body appendString:@"There are no suspects."];
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

// vim:ft=objc
