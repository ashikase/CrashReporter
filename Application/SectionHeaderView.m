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

#import "SectionHeaderView.h"

@implementation SectionHeaderView

@synthesize textLabel = textLabel_;
@synthesize helpButton = helpButton_;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        label.textColor = [UIColor colorWithRed:(109.0 / 255.0) green:(109.0 / 255.0) blue:(114.0 / 255.0) alpha:1.0];
        label.font = [UIFont boldSystemFontOfSize:15.0];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.backgroundColor = [UIColor colorWithRed:(36.0 / 255.0) green:(132.0 / 255.0) blue:(232.0 / 255.0) alpha:1.0];
        button.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
        [button setTitle:@"?" forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        CALayer *layer = button.layer;
        layer.masksToBounds = YES;

        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:label];
        [self addSubview:button];

        textLabel_ = label;
        helpButton_ = [button retain];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    UIScreen *mainScreen = [UIScreen mainScreen];
    const CGRect screenBounds = [mainScreen bounds];

    UIButton *button = self.helpButton;
    const CGSize buttonSize = CGSizeMake(21.0, 21.0);
    const CGRect buttonFrame = CGRectMake(screenBounds.size.width - buttonSize.width - 10.0, 15.0, buttonSize.width, buttonSize.height);
    button.frame = buttonFrame;
    button.layer.cornerRadius = buttonSize.width / 2.0;

    UILabel *label = self.textLabel;
    const CGRect labelFrame = CGRectMake(15.0, 17.0, buttonFrame.origin.x, textLabel_.font.pointSize + 4.0);
    label.frame = labelFrame;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
