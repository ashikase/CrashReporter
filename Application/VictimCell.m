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

@implementation VictimCell

+ (NSDateFormatter *)timeFormatter {
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss (yyyy MMM d)"];
    }
    return formatter;
}

#pragma mark - Overrides (TableViewCell)

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self != nil) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)configureWithObject:(id)object {
    NSAssert([object isKindOfClass:[CrashLog class]], @"ERROR: Incorrect class type: Expected CrashLog, received %@.", [object class]);

    CrashLog *crashLog = object;
    [self setName:[[[self class] timeFormatter] stringFromDate:[crashLog logDate]]];
    [self setViewed:[crashLog isViewed]];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
