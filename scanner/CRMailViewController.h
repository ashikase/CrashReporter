/**
 * Name: scanner
 * Type: iOS extension
 * Desc: Scans tweaks for known issues.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    CRMailReasonMissingFilter
} CRMailReason;

@class PIPackage;

@interface CRMailViewController : UIViewController
+ (void)showWithPackage:(PIPackage *)package reason:(CRMailReason)reason;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 expandtab tw=80: */
