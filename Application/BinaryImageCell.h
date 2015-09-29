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

typedef enum : NSUInteger {
    BinaryImageCellPackageTypeUnknown,
    BinaryImageCellPackageTypeApple,
    BinaryImageCellPackageTypeDebian
} BinaryImageCellPackageType;

@interface BinaryImageCell : UITableViewCell
@property(nonatomic, assign, getter = isNewer) BOOL newer;
@property(nonatomic, assign, getter = isRecent) BOOL recent;
@property(nonatomic, assign, getter = isFromUnofficialSource) BOOL fromUnofficialSource;
@property(nonatomic, assign) BinaryImageCellPackageType packageType;
@property(nonatomic, assign) BOOL showsTopSeparator;
+ (CGFloat)heightForPackageRowCount:(NSUInteger)rowCount;
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;
- (void)setName:(NSString *)name;
- (void)setPackageName:(NSString *)packageName;
- (void)setPackageIdentifier:(NSString *)packageIdentifier;
- (void)setPackageInstallDate:(NSString *)packageInstallDate;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
