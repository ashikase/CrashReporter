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

#define kColorLabel [UIColor grayColor]

static const CGFloat kFontSizeLine = 12.0;

@implementation TableViewCellLine

@synthesize imageView = imageView_;
@synthesize label = label_;

+ (CGFloat)defaultHeight {
    return kFontSizeLine + 4.0;
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self != nil) {
        self.clipsToBounds = YES;

        UIImageView *imageView;
        imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self addSubview:imageView];
        imageView_ = imageView;

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        label.textColor = kColorLabel;
        label.font = [UIFont systemFontOfSize:kFontSizeLine];
        [self addSubview:label];
        label_ = label;
    }
    return self;
}

- (void)dealloc {
    [imageView_ release];
    [label_ release];
    [super dealloc];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    const CGSize size = self.bounds.size;

    UIImageView *imageView = self.imageView;
    [imageView sizeToFit];
    CGRect imageViewFrame = imageView.frame;
    imageViewFrame.origin.y = 0.5 * (size.height - imageViewFrame.size.height);
    imageView.frame = imageViewFrame;

    const CGFloat x = imageViewFrame.size.width + 2.0;
    self.label.frame = CGRectMake(x, 0.0, size.width - x, size.height);
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
