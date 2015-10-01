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

#import "TableViewCell.h"

@implementation TableViewCell {
    UIView *topSeparatorView_;
    UIView *bottomSeparatorView_;
}

@synthesize referenceDate = referenceDate_;
@dynamic showsTopSeparator;

+ (CGFloat)cellHeight {
    return 0.0;
}

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *dateFormatter = nil;
    if (dateFormatter == nil ) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    }
    return dateFormatter;
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
    if (self != nil) {
        // Provide our own separator views for more control.
        UIView *separatorView;

        separatorView = [[UIView alloc] initWithFrame:CGRectZero];
        separatorView.backgroundColor = [UIColor colorWithRed:(200.0 / 255.0) green:(199.0 / 255.0) blue:(204.0 / 255.0) alpha:1.0];
        separatorView.hidden = YES;
        [self addSubview:separatorView];
        topSeparatorView_ = separatorView;

        separatorView = [[UIView alloc] initWithFrame:CGRectZero];
        separatorView.backgroundColor = [UIColor colorWithRed:(200.0 / 255.0) green:(199.0 / 255.0) blue:(204.0 / 255.0) alpha:1.0];
        [self addSubview:separatorView];
        bottomSeparatorView_ = separatorView;
    }
    return self;
}

- (void)dealloc {
    [referenceDate_ release];
    [topSeparatorView_ release];
    [bottomSeparatorView_ release];
    [super dealloc];
}

#pragma mark - View (Layout)

- (void)layoutSubviews {
    [super layoutSubviews];

    // Separators.
    const CGFloat scale = [[UIScreen mainScreen] scale];
    const CGFloat separatorHeight = 1.0 / scale;
    const CGSize size = self.bounds.size;
    [topSeparatorView_ setFrame:CGRectMake(0.0, 0.0, size.width, separatorHeight)];
    [bottomSeparatorView_ setFrame:CGRectMake(0.0, size.height - separatorHeight, size.width, separatorHeight)];
}

#pragma mark - Configuration

- (void)configureWithObject:(id)object {
}

#pragma mark - Properties

- (BOOL)showsTopSeparator {
    return topSeparatorView_.hidden;
}

- (void)setShowsTopSeparator:(BOOL)shows {
    topSeparatorView_.hidden = !shows;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
