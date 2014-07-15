#import "LinkReporterLine.h"

#import "NSString+CrashReporter.h"
#import "Package.h"

@interface ReporterLine (Private)
@property(nonatomic, copy) NSString *title;
@end

@implementation LinkReporterLine

@synthesize recipients = recipients_;
@synthesize unlocalizedTitle = unlocalizedTitle_;
@synthesize url = url_;
@synthesize isEmail = isEmail_;

+ (NSArray *)linkReportersForPackage:(Package *)package {
    NSMutableArray *result = [NSMutableArray array];

    if (package != nil) {
        if (package.isAppStore) {
            // Add AppStore link.
            long long item = [package.storeIdentifier longLongValue]; // we need long long here because there are 2 billion apps on AppStore already... :)
            NSString *line = [NSString stringWithFormat:@"link url \"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=%lld&mt=8\" as \"View package in AppStore\"", item];
            LinkReporterLine *reporter = [LinkReporterLine reporterWithLine:line];
            if (reporter != nil) {
                [result addObject:reporter];
            }
        } else {
            // Add email link.
            NSString *author = package.author;
            if (author != nil) {
                NSString *line = [NSString stringWithFormat:@"link email \"%@\" as \"Email author\"", author];
                LinkReporterLine *reporter = [LinkReporterLine reporterWithLine:line];
                if (reporter != nil) {
                    [result addObject:reporter];
                }
            }

            // Add Cydia link.
            NSString *line = [NSString stringWithFormat:@"link url \"cydia://package/%@\" as \"View package in Cydia\"", package.storeIdentifier];
            LinkReporterLine *reporter = [LinkReporterLine reporterWithLine:line];
            if (reporter != nil) {
                [result addObject:reporter];
            }
        }

        // Add other (optional) link commands.
        for (NSString *line in package.config) {
            if ([line hasPrefix:@"link"]) {
                LinkReporterLine *reporter = [LinkReporterLine reporterWithLine:line];
                if (reporter != nil) {
                    [result addObject:reporter];
                }
            }
        }

        // Sort the lines.
        [result sortUsingSelector:@selector(compare:)];
    }

    return result;
}

- (instancetype)initWithTokens:(NSArray *)tokens {
    self = [super initWithTokens:tokens];
    if (self != nil) {
        enum {
            PLL_Link,
            PLL_Command,
            PLL_Title,
            PLL_Recipients,
            PLL_URL
        } mode = PLL_Link;

        for (NSString *command in tokens) {
            switch (mode) {
                case PLL_Command:
                    if ([command isEqualToString:@"as"]) {
                        mode = PLL_Title;
                    } else if ([command isEqualToString:@"url"]) {
                        mode = PLL_URL;
                    } else if ([command isEqualToString:@"email"]) {
                        mode = PLL_URL;
                        isEmail_ = YES;
                    }
                    break;

                case PLL_Title:
                    unlocalizedTitle_ = [[command stripQuotes] retain];
                    mode = PLL_Command;
                    break;

                case PLL_Recipients:
                    recipients_ = [[command stripQuotes] retain];
                    mode = PLL_Command;
                    break;

                case PLL_URL:
                    url_ = [[NSURL alloc] initWithString:[command stripQuotes]];
                    mode = PLL_Command;
                    break;

                default:
                    mode = PLL_Command;
                    break;
            }
        }

        if (unlocalizedTitle_ == nil) {
            unlocalizedTitle_ = [([url_ absoluteString] ?: recipients_) copy];
        }
        [self setTitle:[[NSBundle mainBundle] localizedStringForKey:unlocalizedTitle_ value:nil table:nil]];
    }
    return self;
}

- (void)dealloc {
    [unlocalizedTitle_ release];
    [recipients_ release];
    [url_ release];
    [super dealloc];
}

- (UITableViewCell *)format:(UITableViewCell *)cell {
    cell = [super format:cell];
    cell.detailTextLabel.text = [[self url] absoluteString];
    return cell;
}

- (NSComparisonResult)compare:(ReporterLine *)reporter {
    // Sort so that email links come first.
    if ([self class] == [reporter class]) {
        BOOL isEmail = [self isEmail];
        if (isEmail != [((LinkReporterLine *)reporter) isEmail]) {
            return isEmail ? NSOrderedAscending : NSOrderedDescending;
        }
    }
    return [super compare:reporter];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
