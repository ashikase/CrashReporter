/*

   CrashReporterDelegate ... Crash Reporter's AppDelegate.
   Copyright (C) 2009  KennyTM~ <kennytm@gmail.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#import "ApplicationDelegate.h"

#import "RootViewController.h"
#import "ReporterLine.h"

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
    RootViewController *rootController = [[RootViewController alloc] initWithStyle:UITableViewStylePlain];
    rootController.title = [[NSBundle mainBundle] localizedStringForKey:@"Crash Reporter" value:nil table:nil];
    navigationController_ = [[UINavigationController alloc] initWithRootViewController:rootController];
    [rootController release];

    // Create window.
    window_ = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [window_ addSubview:[navigationController_ view]];
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

        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self
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
    [ReporterLine flushReporters];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != 0) {
        NSString* url = buttonIndex == 1 ? @"cydia://package/sbsettingssyslogd" : @"cydia://package/syslogd";
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }
}
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
