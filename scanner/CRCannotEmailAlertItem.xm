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
    UIAlertView *alertView = [self alertSheet];
    alertView.title = @"CrashReporter";
    alertView.message = @"Cannot send email from this device.";
    [alertView addButtonWithTitle:@"Dismiss"];
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
