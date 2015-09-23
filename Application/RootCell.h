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

@interface RootCell : UITableViewCell
@property(nonatomic, assign, getter = isNewer) BOOL newer;
@property(nonatomic, assign, getter = isRecent) BOOL recent;
@property(nonatomic, assign, getter = isFromUnofficialSource) BOOL fromUnofficialSource;
+ (CGFloat)cellHeight;
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;
- (void)setName:(NSString *)name;
- (void)setLatestCrashDate:(NSString *)date;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
