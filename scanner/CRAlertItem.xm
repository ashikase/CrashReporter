/**
 * Name: scanner
 * Type: iOS extension
 * Desc: Scans tweaks for known issues.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import "CRAlertItem.h"

%hook CRAlertItem

// Prevent alert from showing on lock screen.
- (BOOL)shouldShowInLockScreen { return NO; }

// Prevent automatic dismissal of alert due to locking device.
// NOTE: Requires different hooks for different firmware versions.
%group GFirmware_GTE_60
- (BOOL)behavesSuperModally { return YES; }
%end

%group GFirmware_GTE_50_LT_60
- (BOOL)reappearsAfterLock { return YES; }
%end

%group GFirmware_GTE_40_LT_50

- (void)didDeactivateForReason:(int)reason {
    %orig();

    if (reason == 0) {
        // Was deactivated due to lock, not user interaction
        // FIXME: Is there no better way to get the alert to reappear?
        [[objc_getClass("SBAlertItemsController") sharedInstance] activateAlertItem:self];
    }
}

%end

%end

void init_CRAlertItem() {
    @autoreleasepool {
        // Make sure class has not already been initialized
        if (objc_getClass("CRAlertItem") != Nil) return;

        // Register new subclass
        Class $SuperClass = objc_getClass("SBAlertItem");
        if ($SuperClass != Nil) {
            Class klass = objc_allocateClassPair($SuperClass, "CRAlertItem", 0);
            if (klass != Nil) {
                objc_registerClassPair(klass);

                %init();

                if (IOS_LT(5_0)) {
                    %init(GFirmware_GTE_40_LT_50);
                } else if (IOS_LT(6_0)) {
                    %init(GFirmware_GTE_50_LT_60);
                } else {
                    %init(GFirmware_GTE_60);
                }
            }
        }
    }
}

/* vim: set ft=logos ff=unix sw=4 ts=4 expandtab tw=80: */
