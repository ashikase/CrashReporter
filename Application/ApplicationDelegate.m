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
#import "CrashLog.h"
#import "SuspectsViewController.h"
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

    NSMutableDictionary *notificationFilepaths_;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Create dictionary to hold filepaths for any incoming notifications.
    notificationFilepaths_ = [NSMutableDictionary new];

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
            value:@"Crash reports without syslog are often useless. Please install \"Syslog Flipswitch\" or \"syslogd\" and reproduce a new crash report."
            table:nil]; //Use Syslog Flipswitch instead of Syslog Toggle because SBSettings is currently incompatible with iOS 7
        NSString *installSyslogToggleTitle = [mainBundle localizedStringForKey:@"Install Syslog Flipswitch" value:nil table:nil];
        NSString *installSyslogdTitle = [mainBundle localizedStringForKey:@"Install syslogd" value:nil table:nil];
        NSString *ignoreOnceTitle = [mainBundle localizedStringForKey:@"Ignore once" value:nil table:nil];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self
            cancelButtonTitle:ignoreOnceTitle otherButtonTitles:installSyslogToggleTitle, installSyslogdTitle, nil];
        [alert setNumberOfRows:3];
        [alert show];
        [alert release];
    }

    // If launched via notification, handle the notification.
    UILocalNotification *notification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (notification != nil) {
        NSString *filepath = [[notification userInfo] objectForKey:@"filepath"];
        if (filepath != nil) {
            [self showDetailsForLogAtPath:filepath animated:NO];
        }
    }

    // Reset icon badge number to zero.
    [application setApplicationIconBadgeNumber:0];

    return YES;
}

- (void)dealloc {
    [notificationFilepaths_ release];
    [navigationController_ release];
    [window_ release];
    [super dealloc];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    NSString *filepath = [[notification userInfo] objectForKey:@"filepath"];

    // NOTE: This method is call if a notification is received while
    //       CrashReporter is running (foreground/background).
    //
    UIApplicationState state = [application applicationState];
    if (state == UIApplicationStateActive) {
        // CrashReporter is in the foreground.
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *title = [mainBundle localizedStringForKey:@"Crash Detected" value:nil table:nil];
        NSString *viewTitle = [mainBundle localizedStringForKey:@"View" value:nil table:nil];
        NSString *ignoreTitle = [mainBundle localizedStringForKey:@"Ignore" value:nil table:nil];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:[notification alertBody]
            delegate:self cancelButtonTitle:ignoreTitle otherButtonTitles:viewTitle, nil];
        [alert setTag:1];

        if (filepath != nil) {
            NSString *key = [NSString stringWithFormat:@"%p", alert];
            [notificationFilepaths_ setObject:filepath forKey:key];
        }

        [alert show];
        [alert release];
    } else {
        // CrashReporter was in the background.
        if (filepath != nil) {
            [self showDetailsForLogAtPath:filepath animated:NO];
        }
    }

    // Reset icon badge number to zero.
    [application setApplicationIconBadgeNumber:0];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [Instruction flushInstructions];
}

#pragma mark - Other

- (void)showDetailsForLogAtPath:(NSString *)filepath animated:(BOOL)animated {
    NSError *error = nil;
    NSFileManager *fileMan = [NSFileManager defaultManager];
    NSDictionary *attrib = [fileMan attributesOfItemAtPath:filepath error:&error];
    if (attrib != nil) {
        if ([[attrib fileType] isEqualToString:NSFileTypeSymbolicLink]) {
            filepath = [fileMan destinationOfSymbolicLinkAtPath:filepath error:&error];
            if (filepath == nil) {
                NSLog(@"ERROR: Unable to determine destination of symbolic link: %@", [error localizedDescription]);
            }
        }

        CrashLog *crashLog = [[CrashLog alloc] initWithFilepath:filepath];
        if (crashLog != nil) {
            SuspectsViewController *controller = [[SuspectsViewController alloc] initWithCrashLog:crashLog];
            [navigationController_ pushViewController:controller animated:animated];
            [controller release];
        }
    } else {
        NSLog(@"ERROR: Unable to retrieve attributes for file: %@", [error localizedDescription]);
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([alertView tag] == 1) {
        // Is local notification alert.
        NSString *key = [NSString stringWithFormat:@"%p", alertView];
        if (buttonIndex != 0) {
            NSString *filepath = [notificationFilepaths_ objectForKey:key];
            if (filepath != nil) {
                [self showDetailsForLogAtPath:filepath animated:YES];
            }
        }

        [notificationFilepaths_ removeObjectForKey:key];
    } else {
        // Is missing syslog alert.
        if (buttonIndex != 0) {
            NSString *url = buttonIndex == 1 ? @"cydia://package/de.j-gessner.syslogflipswitch" : @"cydia://package/syslogd";
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
        }
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
