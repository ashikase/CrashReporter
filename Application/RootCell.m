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

#import "CrashLog.h"
#import "CrashLogGroup.h"
#import "TableViewCellLine.h"
#include "font-awesome.h"

#define kColorCrashDate            [UIColor grayColor]
#define kColorNewer                [UIColor lightGrayColor]
#define kColorRecent               [UIColor redColor]
#define kColorFromUnofficialSource [UIColor colorWithRed:0.8 green:0.2 blue:0.3 alpha:1.0]

static const CGFloat kFontSizeCrashDate = 12.0;

@implementation RootCell {
    TableViewCellLine *latestCrashDateLine_;
    UIImageView *latestCrashDateImageView_;
}

@synthesize newer = newer_;
@synthesize recent = recent_;
@synthesize fromUnofficialSource = fromUnofficialSource_;

#pragma mark - Overrides (TableViewCell)

+ (CGFloat)cellHeight {
    // FIXME: The (+ x.0) values added to the font sizes are only valid for the
    //        current font sizes (18.0 and 12.0). Determine proper calculation.
    return [super cellHeight] + kFontSizeCrashDate;
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self != nil) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        latestCrashDateLine_ = [[self addLine] retain];
        latestCrashDateLine_.iconLabel.text = @kFontAwesomeClockO;
    }
    return self;
}

- (void)dealloc {
    [latestCrashDateLine_ release];
    [latestCrashDateImageView_ release];
    [super dealloc];
}

- (void)configureWithObject:(id)object {
    NSAssert([object isKindOfClass:[CrashLogGroup class]], @"ERROR: Incorrect class type: Expected CrashLogGroup, received %@.", [object class]);

    CrashLogGroup *group = object;
    NSArray *crashLogs = [group crashLogs];
    CrashLog *crashLog = [crashLogs objectAtIndex:0];

    // Name of crashed process.
    [self setName:group.name];

    // Date of latest crash.
    NSString *string = nil;
    BOOL isRecent = NO;
    NSDate *logDate = [crashLog logDate];
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:logDate];
    if (interval < 86400.0) {
        if (interval < 3600.0) {
            string = NSLocalizedString(@"CRASH_LESS_THAN_HOUR", nil);
        } else {
            string = [NSString stringWithFormat:NSLocalizedString(@"CRASH_LESS_THAN_HOURS", nil), (unsigned)ceil(interval / 3600.0)];
        }
        isRecent = YES;
    } else {
        string = [[[self class] dateFormatter] stringFromDate:logDate];
    }
    [self setLatestCrashDate:string];
    [self setRecent:isRecent];

    // Number of unviewed logs and total logs.
    const unsigned long totalCount = [crashLogs count];
    unsigned long unviewedCount = 0;
    for (CrashLog *crashLog in crashLogs) {
        if (![crashLog isViewed]) {
            ++unviewedCount;
        }
    }
    self.detailTextLabel.text = [NSString stringWithFormat:@"%lu/%lu", unviewedCount, totalCount];
}

#pragma mark - Properties

- (void)setLatestCrashDate:(NSString *)latestCrashDate {
    if ([latestCrashDate length] != 0) {
        latestCrashDate = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"LATEST", nil), latestCrashDate];
    }
    [self setText:latestCrashDate forLabel:latestCrashDateLine_.label];
}

- (void)setNewer:(BOOL)newer {
    if (newer_ != newer) {
        newer_ = newer;
        [latestCrashDateLine_.label setTextColor:(newer_ ? kColorNewer : kColorCrashDate)];
    }
}

- (void)setRecent:(BOOL)recent {
    if (recent_ != recent) {
        recent_ = recent;
        [latestCrashDateLine_.label setTextColor:(recent_ ? kColorRecent : kColorCrashDate)];
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
