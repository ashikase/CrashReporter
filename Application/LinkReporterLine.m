#import "LinkReporterLine.h"

#import "NSString+CrashReporter.h"

@interface ReporterLine (Private)
@property(nonatomic, copy) NSString *title;
@end

@implementation LinkReporterLine

@synthesize isEmail = isEmail_;
@synthesize unlocalizedTitle = unlocalizedTitle_;
@synthesize urlString = urlString_;

- (instancetype)initWithTokens:(NSArray *)tokens {
    self = [super initWithTokens:tokens];
    if (self != nil) {
        enum {
            PLL_Link,
            PLL_Command,
            PLL_Title,
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

                case PLL_URL:
                    urlString_ = [[command stripQuotes] retain];
                    mode = PLL_Command;
                    break;

                default:
                    mode = PLL_Command;
                    break;
            }
        }

        if (unlocalizedTitle_ == nil) {
            unlocalizedTitle_ = [urlString_ retain];
        }
        [self setTitle:[[NSBundle mainBundle] localizedStringForKey:unlocalizedTitle_ value:nil table:nil]];
    }
    return self;
}

- (void)dealloc {
    [unlocalizedTitle_ release];
    [urlString_ release];
    [super dealloc];
}

- (UITableViewCell *)format:(UITableViewCell *)cell {
    cell = [super format:cell];
    cell.detailTextLabel.text = [self urlString];
    return cell;
}

- (NSComparisonResult)compare:(ReporterLine *)reporter {
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
