/**
 * Name: scanner
 * Type: iOS extension
 * Desc: Scans tweaks for known issues.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

@interface SBAlertItem : NSObject <UIAlertViewDelegate>
@property(readonly, retain) UIAlertView *alertSheet;
- (void)dismiss;
@end

@interface SBAlertItemsController : NSObject
+ (id)sharedInstance;
- (void)activateAlertItem:(id)item;
@end

@interface CRAlertItem : SBAlertItem @end

void init_CRAlertItem();

/* vim: set ft=logos ff=unix sw=4 ts=4 expandtab tw=80: */
