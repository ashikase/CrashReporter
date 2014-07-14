/*

   ModalActionSheet.h ... Modal UIActionSheet for progress report.
   Copyright (C) 2009  KennyTM~ <kennytm@gmail.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
