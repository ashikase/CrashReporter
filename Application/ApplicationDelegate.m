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

#import <TechSupport/TechSupport.h>
#import "CrashLog.h"
#import "RootViewController.h"
#import "ScriptViewController.h"
#import "SuspectsViewController.h"

#include <errno.h>
#include "paths.h"
#include "preferences.h"

NSString * const kNotificationCrashLogsChanged = @"notificationCrashLogsChanged";

static void resetIconBadgeNumber() {
    // Reset preference used for tracking count.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:0 forKey:@kCrashesSinceLastLaunch];
    [defaults synchronize];

    // Reset icon badge number to zero.
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
}

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
    if (IOS_LT(4_0)) {
        [window_ addSubview:[navigationController_ view]];
    } else {
        [window_ setRootViewController:navigationController_];
    }
    [window_ makeKeyAndVisible];

    // If launched via notification, handle the notification.
    UILocalNotification *notification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (notification != nil) {
        NSString *filepath = [[notification userInfo] objectForKey:@"filepath"];
        if (filepath != nil) {
            [self showDetailsForLogAtPath:filepath animated:NO];
        }
    }

    // Reset icon badge number.
    resetIconBadgeNumber();

    return YES;
}

- (void)dealloc {
    [notificationFilepaths_ release];
    [navigationController_ release];
    [window_ release];
    [super dealloc];
}

// FIXME: Attempt to call Base64 method will cause a crash on iOS < 4.0.
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    BOOL didOpenURL = NO;

    NSString *command = [url host];
    if ([command isEqualToString:@"script"]) {
        ScriptViewController *viewController = nil;

        // NOTE: Script command must include either a "data" or "url" parameter.
        //       The "data" parameter takes precedence.
        for (NSString *param in [[url query] componentsSeparatedByString:@"&"]) {
            if ([param hasPrefix:@"data="]) {
                NSString *value = [param substringFromIndex:5];
                NSData *data = nil;
                if (IOS_LT(7_0)) {
                    data = [[NSData alloc] initWithBase64Encoding:value];
                } else {
                    data = [[NSData alloc] initWithBase64EncodedString:value options:0];
                }
                if (data != nil) {
                    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    if (string != nil) {
                        viewController = [[ScriptViewController alloc] initWithString:string];
                        [string release];
                    } else {
                        NSLog(@"ERROR: Failed to interpret decoded data as UTF8 string.");
                    }
                    [data release];
                } else {
                    NSLog(@"ERROR: Failed to decode provided data.");
                }
                break;
            } else if ([param hasPrefix:@"url="]) {
                NSString *urlString = [[param substringFromIndex:4] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSURL *url = [[NSURL alloc] initWithString:urlString];
                if (url != nil) {
                    viewController = [[ScriptViewController alloc] initWithURL:url];
                    [url release];
                } else {
                    NSLog(@"ERROR: Provided url string is invalid: %@", urlString);
                }
                break;
            }
        }

        if (viewController != nil) {
            [navigationController_ popToRootViewControllerAnimated:NO];
            [navigationController_ pushViewController:viewController animated:YES];
            [viewController release];

            didOpenURL = YES;
        } else {
            NSLog(@"ERROR: Command \"script\" requires a valid \"data\" or \"url\" parameter.");
        }
    } else {
        NSLog(@"ERROR: URL did not contain a supported command.");
    }

    return didOpenURL;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    NSString *filepath = [[notification userInfo] objectForKey:@"filepath"];

    // NOTE: This method is call if a notification is received while
    //       CrashReporter is running (foreground/background).
    //
    UIApplicationState state = [application applicationState];
    if (state == UIApplicationStateActive) {
        // CrashReporter is in the foreground.
        NSString *title = NSLocalizedString(@"CRASH_DETECTED", nil);
        NSString *viewTitle = NSLocalizedString(@"VIEW", nil);
        NSString *ignoreTitle = NSLocalizedString(@"IGNORE", nil);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:[notification alertBody]
            delegate:self cancelButtonTitle:ignoreTitle otherButtonTitles:viewTitle, nil];

        if (filepath != nil) {
            NSString *key = [NSString stringWithFormat:@"%p", alert];
            [notificationFilepaths_ setObject:filepath forKey:key];
        }

        [alert show];
        [alert release];

        // Reset icon badge number.
        resetIconBadgeNumber();
    } else {
        // CrashReporter was in the background.
        if (filepath != nil) {
            [self showDetailsForLogAtPath:filepath animated:NO];
        }
    }

    // Post notification to update views.
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCrashLogsChanged object:self];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [TSInstruction flushInstructions];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Recreate the "is_running" file.
    FILE *f = fopen(kIsRunningFilepath, "w");
    if (f != NULL) {
        fclose(f);
    } else {
        fprintf(stderr, "ERROR: Failed to recreate \"is running\" file, errno = %d.\n", errno);
    }

    // Reset icon badge count.
    resetIconBadgeNumber();

    // Post notification to update views.
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCrashLogsChanged object:self];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // NOTE: Although the app has not technically shutdown, this may be our last
    //       chance to do any processing, as once the app is suspended in the
    //       background, it will be shutdown via SIGKILL.
    // NOTE: If a tweak causes an issue after this point, we will not be able to
    //       detect it and will not be able to enable Safe Mode on next start-up.
    if (unlink(kIsRunningFilepath) != 0) {
        fprintf(stderr, "ERROR: Failed to delete \"is running\" file, errno = %d.\n", errno);
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // NOTE: As this app supports background suspension (as opposed to
    //       termination), this method will only be called if the user manually
    //       terminates the app.
    if (unlink(kIsRunningFilepath) != 0) {
        fprintf(stderr, "ERROR: Failed to delete \"is running\" file, errno = %d.\n", errno);
    }
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
    // Is local notification alert.
    NSString *key = [NSString stringWithFormat:@"%p", alertView];
    if (buttonIndex != 0) {
        NSString *filepath = [notificationFilepaths_ objectForKey:key];
        if (filepath != nil) {
            [self showDetailsForLogAtPath:filepath animated:YES];
        }
    }
    [notificationFilepaths_ removeObjectForKey:key];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
