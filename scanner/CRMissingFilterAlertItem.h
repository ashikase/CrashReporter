/**
 * Name: scanner
 * Type: iOS extension
 * Desc: Scans tweaks for known issues.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import "CRAlertItem.h"

@interface CRMissingFilterAlertItem : CRAlertItem
+ (void)showForPath:(NSString *)path;
@end

/* vim: set ft=logos ff=unix sw=4 ts=4 expandtab tw=80: */
