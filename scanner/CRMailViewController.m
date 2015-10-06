/**
 * Name: scanner
 * Type: iOS extension
 * Desc: Scans tweaks for known issues.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import "CRMailViewController.h"

#import <MessageUI/MessageUI.h>
#import <libpackageinfo/libpackageinfo.h>
#include <objc/runtime.h>
#import "CRCannotEmailAlertItem.h"

static NSString *addressFromString(NSString *string) {
    NSString *address = nil;

    if (string != nil) {
        NSRange leftAngleRange = [string rangeOfString:@"<" options:NSBackwardsSearch];
        if (leftAngleRange.location != NSNotFound) {
            NSRange rightAngleRange = [string rangeOfString:@">" options:NSBackwardsSearch];
            if (rightAngleRange.location != NSNotFound) {
                if (leftAngleRange.location < rightAngleRange.location) {
                    NSRange range = NSMakeRange(leftAngleRange.location + 1, rightAngleRange.location - leftAngleRange.location - 1);
                    address = [string substringWithRange:range];
                }
            }
        }
    }

    return address;
}

@interface CRMailViewController () <MFMailComposeViewControllerDelegate>
@property (nonatomic, retain) UIWindow *window;
@end

@implementation CRMailViewController {
    PIPackage *package_;
    CRMailReason reason_;

    BOOL hasAlreadyAppeared_;
}

@synthesize window = window_;

+ (void)showWithPackage:(PIPackage *)package reason:(CRMailReason)reason {
    BOOL canSendMail = [MFMailComposeViewController canSendMail];
    if (canSendMail) {
        CRMailViewController *viewController = [[CRMailViewController alloc] initWithPackage:package reason:reason];

        UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        window.rootViewController = viewController;
        [window makeKeyAndVisible];

        viewController.window = window;
        [viewController release];
        [window release];
    } else {
        [objc_getClass("CRCannotEmailAlertItem") show];
    }
}

- (instancetype)initWithPackage:(PIPackage *)package reason:(CRMailReason)reason {
    self = [super init];
    if (self != nil) {
        package_ = [package retain];
        reason_ = reason;
    }
    return self;
}

- (void)dealloc {
    [package_ release];
    [window_ release];
    [super dealloc];
}

- (void)viewDidAppear:(BOOL)animated {
    if (!hasAlreadyAppeared_) {
        // Setup mail controller.
        MFMailComposeViewController *controller = [[MFMailComposeViewController alloc] init];
        [controller setMailComposeDelegate:self];
        [controller setMessageBody:[self body] isHTML:NO];
        [controller setSubject:[self subject]];

        NSString *author = addressFromString(package_.author);
        if (author != nil) {
            [controller setToRecipients:[NSArray arrayWithObject:author]];
        }
        NSString *maintainer = addressFromString(package_.maintainer);
        if (maintainer != nil) {
            [controller setCcRecipients:[NSArray arrayWithObject:maintainer]];
        }

        // Present the mail controller for confirmation.
        if (IOS_LT(5_0)) {
            [self presentModalViewController:controller animated:YES];
        } else {
            [self presentViewController:controller animated:YES completion:nil];
        }
        [controller release];

        hasAlreadyAppeared_ = YES;
    }
}

- (NSString *)subject {
    NSString *string = nil;
    switch (reason_) {
        case CRMailReasonMissingFilter:
            string = @"Missing Filter File";
            break;
        default:
            string = @"";
            break;
    }
    return [NSString stringWithFormat:@"CrashReporter: %@: %@", package_.name, string];
}

- (NSString *)body {
    NSString *string = nil;
    switch (reason_) {
        case CRMailReasonMissingFilter:
            string = [NSString stringWithFormat:
                @"Your tweak, \"%@\" (%@, version %@) is missing a filter file.\n\n"
                "Without a filter file, your tweak will be loaded into *every* process controlled by launchd, not only apps but daemons as well. This can lead to crashing and other issues.\n\n"
                "Even if you absolutely require that your tweak be loaded into all processes, please do so via an appropriately-constructed filter file.\n\n"
                "Note that even if your tweak operates properly when loaded into daemons, it may cause other tweaks to also be loaded, and those other tweaks may *not* be designed to work with daemons. This is especially a problem if your tweak links to UIKit. If your tweak uses UIKit, be sure to either avoid targetting non-apps (e.g. daemons), or avoid directly linking to UIKit (use dlopen() instead, making sure to do so outside of the tweak's constructor).",
                package_.name, package_.identifier, package_.version];
            break;
        default:
            string = @"";
            break;
    }
    return [string stringByAppendingString:@"\n\n/* Generated by CrashReporter - cydia://package/crash-reporter */"];
}

#pragma mark - Delegate (MFMailComposeViewControllerDelegate)

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    // Dismiss controller and presenting window.
    if (IOS_LT(5_0)) {
        [self dismissModalViewControllerAnimated:NO];
        UIWindow *window = self.window;
        window.hidden = YES;
        window.rootViewController = nil;
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            UIWindow *window = self.window;
            window.hidden = YES;
            window.rootViewController = nil;
        }];
    }
}

@end

/* vim: set ft=logos ff=unix sw=4 ts=4 expandtab tw=80: */
