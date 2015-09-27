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

#import "RootCell.h"

#import "UIImage+CrashReporter.h"
#include "font-awesome.h"

#define kColorName                 [UIColor blackColor]
#define kColorCrashDate            [UIColor grayColor]
#define kColorNewer                [UIColor lightGrayColor]
#define kColorRecent               [UIColor redColor]
#define kColorFromUnofficialSource [UIColor colorWithRed:0.8 green:0.2 blue:0.3 alpha:1.0]

static const UIEdgeInsets kContentInset = (UIEdgeInsets){6.0, 15.0, 6.0, 15.0};
static const CGFloat kFontSizeName = 18.0;
static const CGFloat kFontSizeCrashDate = 12.0;
static const CGSize kMenuButtonImageSize = (CGSize){11.0, 15.0};

static UIImage *crashDateImage$ = nil;

@implementation RootCell {
    UILabel *nameLabel_;
    UILabel *latestCrashDateLabel_;
    UIImageView *latestCrashDateImageView_;
}

@synthesize newer = newer_;
@synthesize recent = recent_;
@synthesize fromUnofficialSource = fromUnofficialSource_;

#pragma mark - Creation & Destruction

+ (void)initialize {
    [super initialize];

    if (self == [RootCell self]) {
        // Create and cache icon font images.
        UIFont *imageFont = [UIFont fontWithName:@"FontAwesome" size:11.0];
        UIColor *imageColor = [UIColor blackColor];

        crashDateImage$ = [[UIImage imageWithText:@kFontAwesomeClockO font:imageFont color:imageColor imageSize:kMenuButtonImageSize] retain];
    }
}

+ (CGFloat)cellHeight {
    // FIXME: The (+ x.0) values added to the font sizes are only valid for the
    //        current font sizes (18.0 and 12.0). Determine proper calculation.
    return kContentInset.top + kContentInset.bottom + (kFontSizeName + 4.0) + kFontSizeCrashDate;
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
    if (self != nil) {
        UIView *contentView = [self contentView];

        UIFont *font;
        UILabel *label;

        font = [UIFont systemFontOfSize:kFontSizeName];
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        [label setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [label setTextColor:kColorName];
        [label setFont:font];
        [contentView addSubview:label];
        nameLabel_ = label;

        font = [UIFont systemFontOfSize:kFontSizeCrashDate];
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        [label setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [label setTextColor:kColorCrashDate];
        [label setFont:font];
        [contentView addSubview:label];
        latestCrashDateLabel_ = label;

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [imageView setImage:crashDateImage$];
        [contentView addSubview:imageView];
        latestCrashDateImageView_ = imageView;
    }
    return self;
}

- (void)dealloc {
    [nameLabel_ release];
    [latestCrashDateLabel_ release];
    [latestCrashDateImageView_ release];
    [super dealloc];
}

#pragma mark - View (Layout)

- (void)layoutSubviews {
    [super layoutSubviews];

    const CGSize contentSize = [[self contentView] bounds].size;
    CGSize maxSize = CGSizeMake(contentSize.width - kContentInset.left - kContentInset.right, 10000.0);

    // Name.
    CGRect nameLabelFrame = CGRectZero;
    if ([[nameLabel_ text] length] > 0) {
        nameLabelFrame = [nameLabel_ frame];
        nameLabelFrame.origin.x = kContentInset.left;
        nameLabelFrame.origin.y = kContentInset.top;
        nameLabelFrame.size = [nameLabel_ sizeThatFits:maxSize];
    }
    [nameLabel_ setFrame:nameLabelFrame];

    maxSize.width -= 2.0;

    // Latest crash date.
    const CGFloat x = kContentInset.left + 2.0;
    const CGFloat y = (nameLabelFrame.origin.y + nameLabelFrame.size.height);
    CGRect latestCrashDateLabelFrame = CGRectZero;
    CGRect latestCrashDateImageViewFrame = CGRectZero;
    if ([[latestCrashDateLabel_ text] length] > 0) {
        // Latest crash date icon.
        [latestCrashDateImageView_ sizeToFit];
        latestCrashDateImageViewFrame = [latestCrashDateImageView_ frame];
        latestCrashDateImageViewFrame.origin.x = x;
        latestCrashDateImageViewFrame.origin.y = y;

        // Latest crash date label.
        latestCrashDateLabelFrame = [latestCrashDateLabel_ frame];
        latestCrashDateLabelFrame.origin.x = x + latestCrashDateImageViewFrame.size.width + 2.0;
        latestCrashDateLabelFrame.origin.y = y;
        latestCrashDateLabelFrame.size = [latestCrashDateLabel_ sizeThatFits:maxSize];
    }
    [latestCrashDateImageView_ setFrame:latestCrashDateImageViewFrame];
    [latestCrashDateLabel_ setFrame:latestCrashDateLabelFrame];
}

#pragma mark - Properties

- (void)setText:(NSString *)text forLabel:(UILabel *)label {
    const NSUInteger oldLength = [[label text] length];
    const NSUInteger newLength = [text length];

    [label setText:text];

    if (((oldLength == 0) && (newLength != 0)) || ((oldLength != 0) && (newLength == 0))) {
        [self setNeedsLayout];
    }
}

- (void)setName:(NSString *)name {
    [self setText:name forLabel:nameLabel_];
}

- (void)setLatestCrashDate:(NSString *)latestCrashDate {
    if ([latestCrashDate length] != 0) {
        latestCrashDate = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"LATEST", nil), latestCrashDate];
    }
    [self setText:latestCrashDate forLabel:latestCrashDateLabel_];
}

- (void)setNewer:(BOOL)newer {
    if (newer_ != newer) {
        newer_ = newer;
        [latestCrashDateLabel_ setTextColor:(newer_ ? kColorNewer : kColorCrashDate)];
    }
}

- (void)setRecent:(BOOL)recent {
    if (recent_ != recent) {
        recent_ = recent;
        [latestCrashDateLabel_ setTextColor:(recent_ ? kColorRecent : kColorCrashDate)];
    }
}

- (void)setFromUnofficialSource:(BOOL)fromUnofficialSource {
    if (fromUnofficialSource_ != fromUnofficialSource) {
        fromUnofficialSource_ = fromUnofficialSource;
        [[self contentView] setBackgroundColor:(fromUnofficialSource_ ? kColorFromUnofficialSource : [UIColor whiteColor])];
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
