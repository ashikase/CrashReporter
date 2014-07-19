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

#import "ApplicationDelegate.h"

#import "RootViewController.h"
#import "Instruction.h"

#ifndef kCFCoreFoundationVersionNumber_iOS_4_0
#define kCFCoreFoundationVersionNumber_iOS_4_0 550.32
#endif

@interface UIAlertView ()
- (void)setNumberOfRows:(int)rows;
@end

@interface ApplicationDelegate () <UIApplicationDelegate, UIAlertViewDelegate>
@end

@implementation ApplicationDelegate {
    UIWindow *window_;
    UINavigationController *navigationController_;
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    // Create root view controller.
    RootViewController *rootController = [RootViewController new];
    navigationController_ = [[UINavigationController alloc] initWithRootViewController:rootController];
    [rootController release];

    // Create window.
    window_ = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_4_0) {
        [window_ addSubview:[navigationController_ view]];
    } else {
        [window_ setRootViewController:navigationController_];
    }
    [window_ makeKeyAndVisible];

    // Check if syslog is present. Alert the user if not.
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/etc/syslog.conf"]) {
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *title = [mainBundle localizedStringForKey:@"syslog not found!" value:nil table:nil];
        NSString *message = [mainBundle localizedStringForKey:@"SYSLOG_NOT_FOUND_DETAIL"
            value:@"Crash reports without syslog is often useless. Please install \"Syslog Toggle\" or \"syslogd\" and reproduce a new crash report."
            table:nil];
        NSString *installSyslogToggleTitle = [mainBundle localizedStringForKey:@"Install Syslog Toggle" value:nil table:nil];
        NSString *installSyslogdTitle = [mainBundle localizedStringForKey:@"Install syslogd" value:nil table:nil];
        NSString *ignoreOnceTitle = [mainBundle localizedStringForKey:@"Ignore once" value:nil table:nil];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self
            cancelButtonTitle:ignoreOnceTitle otherButtonTitles:installSyslogToggleTitle, installSyslogdTitle, nil];
        [alert setNumberOfRows:3];
        [alert show];
        [alert release];
    }
}

- (void)dealloc {
    [window_ release];
    [navigationController_ release];
    [super dealloc];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [Instruction flushInstructions];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != 0) {
        NSString* url = buttonIndex == 1 ? @"cydia://package/sbsettingssyslogd" : @"cydia://package/syslogd";
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }
}
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
