/**
 * Name: scanner
 * Type: iOS extension
 * Desc: Scans tweaks for known issues.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

@interface SBAlertItem : NSObject <UIAlertViewDelegate>
- (void)dismiss;
@end

@interface SBAlertItem (Firmware_LT_100)
- (UIAlertView *)alertSheet;
@end

@interface SBAlertItem (Firmware_GTE_100)
- (id)alertController;
- (void)deactivateForButton;
@end

@interface SBAlertItemsController : NSObject
+ (id)sharedInstance;
- (void)activateAlertItem:(id)item;
@end

typedef NS_ENUM(NSInteger, UIAlertActionStyle) {
    UIAlertActionStyleDefault = 0,
    UIAlertActionStyleCancel,
    UIAlertActionStyleDestructive
};

@interface UIAlertAction : NSObject <NSCopying>
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler;
@end

@interface UIAlertController : UIViewController
- (void)addAction:(UIAlertAction *)action;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@end

@interface CRAlertItem : SBAlertItem @end

void init_CRAlertItem();

/* vim: set ft=logos ff=unix sw=4 ts=4 expandtab tw=80: */
