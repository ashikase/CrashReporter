/**
 * Name: scanner
 * Type: iOS extension
 * Desc: Scans tweaks for known issues.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import "CRMissingFilterAlertItem.h"

#import <libpackageinfo/libpackageinfo.h>
#import "CRMailViewController.h"

@interface CRMissingFilterAlertItem ()
@property (nonatomic, copy) NSString *path;
@end

static void presentEmailForPath(NSString *path) {
    PIDebianPackage *package = [PIDebianPackage packageForFile:path];
    [CRMailViewController showWithPackage:package reason:CRMailReasonMissingFilter];
}

%hook CRMissingFilterAlertItem

%new
+ (void)showForPath:(NSString *)path {
    CRMissingFilterAlertItem *alert = [[self alloc] init];
    alert.path = path;
    [[objc_getClass("SBAlertItemsController") sharedInstance] activateAlertItem:alert];
    [alert release];
}

#pragma mark - Overrides

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1) {
        if (buttonIndex == 0) {
            presentEmailForPath(self.path);
        }
    }

    // Call original implementation to dismiss the alert item.
    %orig();
}

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require {
    NSString *title = @"CrashReporter";
    NSString *message = nil;
    NSString *buttonTitle = @"Dismiss";
    NSString *otherButtonTitle = @"Contact Developer";

    NSString *path = self.path;
    PIDebianPackage *package = [PIDebianPackage packageForFile:path];
    if (package != nil) {
        message = [NSString stringWithFormat:
            @"The following tweak has no filter file:\n\n"
            "%@\n\n"
            "This can lead to crashing and other issues on your device.\n\n"
            "It is strongly recommended that you report this to the developer of the tweak.",
            package.name];
    } else {
        message = [NSString stringWithFormat:
            @"The following tweak has no filter file:\n\n"
            "%@\n\n"
            "This can lead to crashing and other issues on your device.\n\n"
            "It is strongly recommended that you report this to the developer of the tweak.\n\n"
            "(The package that this tweak is from cannot be found or is no longer installed. You will need to determine for yourself whom to contact.)",
            [path lastPathComponent]];
    }

    if (IOS_LT(10_0)) {
        UIAlertView *alertView = [self alertSheet];
        [alertView setDelegate:self];
        [alertView setTitle:title];
        [alertView setMessage:message];

        if (package != nil) {
            [alertView setTag:1];
            [alertView addButtonWithTitle:otherButtonTitle];
        }

        [alertView addButtonWithTitle:buttonTitle];
    } else {
        UIAlertController *alertController = [self alertController];
        [alertController setTitle:title];
        [alertController setMessage:message];

        if (package != nil) {
            [alertController addAction:[objc_getClass("UIAlertAction") actionWithTitle:otherButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                presentEmailForPath(self.path);
                [self deactivateForButton];
            }]];
        }

        [alertController addAction:[objc_getClass("UIAlertAction") actionWithTitle:buttonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self deactivateForButton];
        }]];
    }
}

- (void)dealloc {
    NSString *path_ = nil;
    (void)object_getInstanceVariable(self, "path_", (void **)&path_);
    [path_ release];

    %orig();
}

#pragma mark - Properties

%new
- (NSString *)path {
    NSString *path_ = nil;
    (void)object_getInstanceVariable(self, "path_", (void **)&path_);
    return path_;
}

%new
- (void)setPath:(NSString *)path {
    NSString *path_ = nil;
    (void)object_getInstanceVariable(self, "path_", (void **)&path_);
    if (path_ != path) {
        [path_ release];
        [path copy];
        (void)object_setInstanceVariable(self, "path_", path);
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
            Class klass = objc_allocateClassPair($SuperClass, "CRMissingFilterAlertItem", 0);
            if (klass != Nil) {
                // Add instance variables.
                const char *type = "@";
                NSUInteger size, align;
                NSGetSizeAndAlignment(type, &size, &align);
                class_addIvar(klass, "path_", size, align, type);

                // Finish registering subclass.
                objc_registerClassPair(klass);

                %init();
            }
        }
    }
}

/* vim: set ft=logos ff=unix sw=4 ts=4 expandtab tw=80: */
