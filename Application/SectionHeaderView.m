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

static const CGFloat kSectionHeaderHeight = 38.0;

@implementation SectionHeaderView

@synthesize textLabel = textLabel_;
@synthesize helpButton = helpButton_;

+ (CGFloat)defaultHeight {
    return kSectionHeaderHeight;
}

- (instancetype)initWithDefaultSize {
    const CGRect screenBounds = [[UIScreen mainScreen] bounds];
    const CGRect frame = CGRectMake(0.0, 0.0, screenBounds.size.width, kSectionHeaderHeight);
    self = [super initWithFrame:frame];
    if (self != nil) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor colorWithRed:(109.0 / 255.0) green:(109.0 / 255.0) blue:(114.0 / 255.0) alpha:1.0];
        label.font = [UIFont boldSystemFontOfSize:15.0];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setImage:[UIImage imageNamed:@"help_button"] forState:UIControlStateNormal];

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
    const CGSize buttonSize = CGSizeMake(kSectionHeaderHeight + 2.0, kSectionHeaderHeight);
    const CGRect buttonFrame = CGRectMake(screenBounds.size.width - buttonSize.width, 0.0, buttonSize.width, buttonSize.height);
    button.frame = buttonFrame;
    button.imageEdgeInsets = UIEdgeInsetsMake(5.0, 0.0, 0.0, 0.0);

    UILabel *label = self.textLabel;
    const CGRect labelFrame = CGRectMake(10.0, 13.0, buttonFrame.origin.x, textLabel_.font.pointSize + 4.0);
    label.frame = labelFrame;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
