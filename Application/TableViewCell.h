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

@class TableViewCellLine;

@interface TableViewCell : UITableViewCell
@property(nonatomic, readonly) UILabel *nameLabel;
@property(nonatomic, retain) NSDate *referenceDate;
@property(nonatomic, assign) BOOL showsTopSeparator;
@property(nonatomic, assign, getter = isViewed) BOOL viewed;
+ (CGFloat)cellHeight;
+ (NSDateFormatter *)dateFormatter;
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;
- (void)configureWithObject:(id)object;
- (void)setName:(NSString *)name;
- (TableViewCellLine *)addLine;
- (void)setText:(NSString *)text forLabel:(UILabel *)label;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
