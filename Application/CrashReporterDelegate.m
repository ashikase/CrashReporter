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

#import <UIKit/UIKit.h>
#import <UIKit/UIAlertView.h>
#import "CrashLogsTableController.h"
#import "reporter.h"

@interface UIAlertView ()
- (void)setNumberOfRows:(int)rows;
@end

@interface CrashReporterDelegate : NSObject<UIApplicationDelegate, UIAlertViewDelegate> {
	UIWindow* _win;
	UINavigationController* _navCtrler;
}
@end

int canEmailAuthor = 0;

@implementation CrashReporterDelegate
-(void)applicationDidFinishLaunching:(UIApplication*)app {
	_win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	[_win makeKeyAndVisible];

	CrashLogsTableController* firstCtrler = [[CrashLogsTableController alloc] initWithStyle:UITableViewStylePlain];
	/*
	CrashLogViewController* firstCtrler = [[CrashLogViewController alloc] init];
	firstCtrler.file = @"/Users/kennytm/Downloads/Untitled2.plist";
	 */
	firstCtrler.title = [[NSBundle mainBundle] localizedStringForKey:@"Crash Reporter" value:nil table:nil];
	_navCtrler = [[UINavigationController alloc] initWithRootViewController:firstCtrler];
	[firstCtrler release];

	[_win addSubview:_navCtrler.view];

	// Check if syslog is present. Alert the user if not.
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/etc/syslog.conf"]) {
		NSBundle* selfBundle = [NSBundle mainBundle];
		NSString* title = [selfBundle localizedStringForKey:@"syslog not found!" value:nil table:nil];
		NSString* message = [selfBundle localizedStringForKey:@"SYSLOG_NOT_FOUND_DETAIL" value:@"Crash reports without syslog is often useless. Please install “Syslog Toggle” or “syslogd”, and reproduce a new crash report." table:nil];
		NSString* installSyslogToggleButton = [selfBundle localizedStringForKey:@"Install Syslog Toggle" value:nil table:nil];
		NSString* installSyslogdButton = [selfBundle localizedStringForKey:@"Install syslogd" value:nil table:nil];
		NSString* ignoreOnceButton = [selfBundle localizedStringForKey:@"Ignore once" value:nil table:nil];

		UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:ignoreOnceButton otherButtonTitles:installSyslogToggleButton, installSyslogdButton, nil];
		[alert setNumberOfRows:3];
		[alert show];
		[alert release];
	}

	canEmailAuthor = [[NSUserDefaults standardUserDefaults] boolForKey:@"canEmailAuthor"];
}
-(void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex != 0) {
		NSString* url = buttonIndex == 1 ? @"cydia://package/sbsettingssyslogd" : @"cydia://package/syslogd";
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
	}
}

-(void)applicationWillTerminate:(UIApplication*)application {
	[_win release];
	[_navCtrler release];
}
-(void)applicationDidReceiveMemoryWarning:(UIApplication*)application {
	[ReporterLine flushReporters];
}
@end
