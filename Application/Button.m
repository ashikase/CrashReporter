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

#import "Button.h"

#import "UIImage+CrashReporter.h"

@interface UIImage (UIImagePrivate)
+ (id)kitImageNamed:(NSString *)name;
@end

@implementation Button

+ (instancetype)button {
    Button *button = [Button buttonWithType:UIButtonTypeCustom];
    [button setAutoresizingMask:UIViewAutoresizingFlexibleWidth];

    CALayer *layer = button.layer;
    [layer setBorderWidth:1.0];

    if (IOS_LT(7_0)) {
        [button setAdjustsImageWhenHighlighted:YES];

        [layer setBorderColor:[[UIColor colorWithRed:(171.0 / 255.0) green:(171.0 / 255.0) blue:(171.0 / 255.0) alpha:1.0] CGColor]];
        [layer setCornerRadius:8.0];
        [layer setMasksToBounds:YES];

        UILabel *label = [button titleLabel];
        [label setFont:[UIFont boldSystemFontOfSize:18.0]];

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UIImage *image = [UIImage kitImageNamed:@"UINavigationBarSilverTallBackground.png"];
            [button setBackgroundImage:[image stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor colorWithRed:(114.0 / 255.0) green:(121.0 / 255.0) blue:(130.0 / 255.0) alpha:1.0] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
            [button setTitleShadowColor:[UIColor colorWithRed:(230.0 / 255.0) green:(230.0 / 255.0) blue:(230.0 / 255.0) alpha:1.0] forState:UIControlStateNormal];
            [button setTitleShadowColor:[UIColor blackColor] forState:UIControlStateHighlighted];
            [label setShadowOffset:CGSizeMake(0.0, 1.0)];
        } else {
            UIImage *image = [UIImage kitImageNamed:@"UINavigationBarDefaultBackground.png"];
            [button setBackgroundImage:[image stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0] forState:UIControlStateNormal];
            [label setShadowOffset:CGSizeMake(0.0, -1.0)];
        }
    } else {
        UIColor *buttonColor = [UIColor colorWithRed:(36.0 / 255.0) green:(132.0 / 255.0) blue:(232.0 / 255.0) alpha:1.0];
        UIImage *image = [[UIImage imageWithColor:buttonColor] stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0];
        [button setBackgroundImage:image forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

        buttonColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0];
        image = [[UIImage imageWithColor:buttonColor] stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0];
        [button setBackgroundImage:image forState:UIControlStateDisabled];
        [button setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];

        layer.borderColor = [[UIColor blackColor] CGColor];
    }

    return button;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
