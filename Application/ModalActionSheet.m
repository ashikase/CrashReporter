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

#import "ModalActionSheet.h"

#include <CoreFoundation/CoreFoundation.h>

@interface UIProgressHUD : UIView
- (void)setText:(id)text;
- (void)showInView:(id)view;
@end

@implementation ModalActionSheet {
    UIProgressHUD *hud_;
    UIWindow *window_;
}

- (id)init {
    self = [super init];
    if (self != nil) {

        UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        window.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
        window.windowLevel = UIWindowLevelAlert;
        window_ = window;

        UIProgressHUD *hud = [UIProgressHUD new];
        [hud showInView:window];
        hud_ = hud;
    }
    return self;
}

- (void)dealloc {
    [window_ release];
    [hud_ release];
    [super dealloc];
}

- (void)show {
    window_.hidden = NO;
}

- (void)hide {
    window_.hidden = YES;
}

- (void)updateText:(NSString *)text {
    [hud_ setText:text];
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
