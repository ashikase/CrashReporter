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

#import "VictimCell.h"

#import "CrashLog.h"

#define kColorName                 [UIColor blackColor]

static const UIEdgeInsets kContentInset = (UIEdgeInsets){6.0, 15.0, 6.0, 15.0};
static const CGFloat kFontSizeName = 18.0;

@implementation VictimCell {
    UILabel *nameLabel_;
}

+ (NSDateFormatter *)timeFormatter {
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss (yyyy MMM d)"];
    }
    return formatter;
}

#pragma mark - Overrides (TableViewCell)

+ (CGFloat)cellHeight {
    // FIXME: The (+ x.0) values added to the font sizes are only valid for the
    //        current font sizes (18.0 and 12.0). Determine proper calculation.
    return kContentInset.top + kContentInset.bottom + (kFontSizeName + 4.0);
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self != nil) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

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
    }
    return self;
}

- (void)dealloc {
    [nameLabel_ release];
    [super dealloc];
}

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
}

- (void)configureWithObject:(id)object {
    NSAssert([object isKindOfClass:[CrashLog class]], @"ERROR: Incorrect class type: Expected CrashLog, received %@.", [object class]);

    CrashLog *crashLog = object;

    // FIXME: Date formatter - shared, or use existing.
    UILabel *label = self.textLabel;
    label.text = [[[self class] timeFormatter] stringFromDate:[crashLog logDate]];
    label.textColor = [crashLog isViewed] ? [UIColor grayColor] : [UIColor blackColor];
    [formatter release];
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

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
