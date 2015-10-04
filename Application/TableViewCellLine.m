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

#import "TableViewCellLine.h"

#define kColorIconLabel [UIColor blackColor]
#define kColorLabel [UIColor grayColor]

static const CGFloat kFontSizeIconLabel = 11.0;
static const CGFloat kFontSizeLabel = 12.0;

@implementation TableViewCellLine

@synthesize iconLabel = iconLabel_;
@synthesize label = label_;

+ (CGFloat)defaultHeight {
    return kFontSizeLabel + 4.0;
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self != nil) {
        self.clipsToBounds = YES;

        UILabel *label;

        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.backgroundColor  = [UIColor clearColor];
        label.font = [UIFont fontWithName:@"FontAwesome" size:kFontSizeIconLabel];
        if (IOS_LT(5_0)) {
            // NOTE: For reasons unknown, center alignment on iOS 4 causes
            //       certain icon font images to be cut off on the right side.
            label.textAlignment = NSTextAlignmentLeft;
        } else {
            label.textAlignment = NSTextAlignmentCenter;
        }
        label.textColor = kColorIconLabel;
        [self addSubview:label];
        iconLabel_ = label;

        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        label.backgroundColor  = [UIColor clearColor];
        label.textColor = kColorLabel;
        label.font = [UIFont systemFontOfSize:kFontSizeLabel];
        [self addSubview:label];
        label_ = label;
    }
    return self;
}

- (void)dealloc {
    [iconLabel_ release];
    [label_ release];
    [super dealloc];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    const CGSize size = self.bounds.size;

    UILabel *iconLabel = self.iconLabel;
    CGFloat iconLabelWidth;
    CGFloat labelX;
    if ([iconLabel.text length] > 0) {
        iconLabelWidth = kFontSizeIconLabel;
        labelX = iconLabelWidth + 3.0;
    } else {
        iconLabelWidth = 0.0;
        labelX = 0.0;
    }
    iconLabel.frame = CGRectMake(0.0, 0.0, iconLabelWidth, size.height);
    self.label.frame = CGRectMake(labelX, 0.0, size.width - labelX, size.height);
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
