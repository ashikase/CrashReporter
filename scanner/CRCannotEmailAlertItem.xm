/**
 * Name: scanner
 * Type: iOS extension
 * Desc: Scans tweaks for known issues.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import "CRCannotEmailAlertItem.h"

%hook CRCannotEmailAlertItem

#pragma mark - Overrides

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require {

    NSString *title = @"CrashReporter";
    NSString *message = @"Cannot send email from this device.";
    NSString *buttonTitle = @"Dismiss";

    if (IOS_LT(10_0)) {
        UIAlertView *alertView = [self alertSheet];
        [alertView setTitle:title];
        [alertView setMessage:message];
        [alertView addButtonWithTitle:buttonTitle];
    } else {
        UIAlertController *alertController = [self alertController];
        [alertController setTitle:title];
        [alertController setMessage:message];
        [alertController addAction:[objc_getClass("UIAlertAction") actionWithTitle:buttonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self deactivateForButton];
        }]];
    }
}

%end

%ctor {
    @autoreleasepool {
        // Initialize super class, if necessary.
        init_CRAlertItem();

        // Register new subclass.
        Class $SuperClass = objc_getClass("CRAlertItem");
        if ($SuperClass != Nil) {
            Class klass = objc_allocateClassPair($SuperClass, "CRCannotEmailAlertItem", 0);
            if (klass != Nil) {
                objc_registerClassPair(klass);

                %init();
            }
        }
    }
}

/* vim: set ft=logos ff=unix sw=4 ts=4 expandtab tw=80: */
