#import <libsymbolicate/CRCrashReport.h>

@interface SBSLocalNotificationClient : NSObject
+ (void)scheduleLocalNotification:(id)arg1 bundleIdentifier:(id)arg2;
+ (id)scheduledLocalNotifications;
@end

int main(int argc, char **argv, char **envp) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

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
    // FIXME: Save the result with the "synced" suffix so that CrashReporter
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
        [body appendFormat:@"\"%@\" is the most likely suspect.", [[suspects objectAtIndex:0] lastPathComponent]];
    } else {
        [body appendString:@"There are no suspects."];
    }
    [report release];

    // Create and send a local notification to CrashReporter.
    UILocalNotification *notification = [UILocalNotification new];
    [notification setAlertBody:body];
    [notification setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:filepath, @"filepath", nil]];

    [notification setApplicationIconBadgeNumber:1];

    // NOTE: Passing nil as the action will cause iOS to display "View" (localized).
    [notification setHasAction:YES];
    [notification setAlertAction:nil];

    // NOTE: Notification will be shown immediately as no fire date was set.
    [SBSLocalNotificationClient scheduleLocalNotification:notification bundleIdentifier:@"crash-reporter"];
    [notification release];

    // Must execute the run loop once so the above is processed.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);

    [pool release];
    return 0;
}

// vim:ft=objc
