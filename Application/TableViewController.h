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

#import <UIKit/UIKit.h>

@interface TableViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, assign) BOOL supportsRefreshControl;
- (void)presentHelpForName:(NSString *)name;
- (void)refresh:(NSNotification *)notification;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
