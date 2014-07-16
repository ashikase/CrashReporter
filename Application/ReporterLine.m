/*

   reporter.m ... Data structure representing lines of blame scripts.
   Copyright (C) 2009  KennyTM~ <kennytm@gmail.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#import "ReporterLine.h"

#import "IncludeReporterLine.h"
#import "LinkReporterLine.h"
#import "Package.h"

static NSArray *tokenize(NSString *string) {
    NSMutableArray *result = [NSMutableArray array];

    NSScanner *scanner = [NSScanner scannerWithString:string];
    [scanner setCharactersToBeSkipped:nil];
    NSCharacterSet *tabQuoteSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\""];
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];

    BOOL inQuote = NO;
    NSString *token;
    while (![scanner isAtEnd]) {
        token = nil;
        if (inQuote) {
            // Scan and capture the quoted text.
            [scanner scanUpToString:@"\"" intoString:&token];
            token = [NSString stringWithFormat:@"%@", token];
            [scanner scanString:@"\"" intoString:NULL];
            inQuote = NO;
        } else {
            // Scan and capture the unquoted text, up to the next space/tab/quote.
            [scanner scanUpToCharactersFromSet:tabQuoteSet intoString:&token];
        }

        if (token != nil) {
            [result addObject:token];

            // Remove any whitespace between this and the next token.
            [scanner scanCharactersFromSet:whitespaceSet intoString:NULL];
            if ([scanner scanString:@"\"" intoString:NULL]) {
                inQuote = YES;
            }
        } else {
            break;
        }
    }

    return result;
}

static NSMutableDictionary *reporters$ = nil;

@implementation ReporterLine

@synthesize title = title_;
@synthesize tokens = tokens_;

+ (instancetype)reporterWithLine:(NSString *)line {
    if (reporters$ == nil) {
        reporters$ = [NSMutableDictionary new];
    }

    ReporterLine *reporter = [reporters$ objectForKey:line];
    if (reporter == nil) {
        NSArray *tokens = tokenize(line);
        NSUInteger count = [tokens count];
        if (count > 0) {
            Class klass = Nil;

            NSString *firstToken = [tokens objectAtIndex:0];
            if ([firstToken isEqualToString:@"include" ]) {
                klass = [IncludeReporterLine class];
            } else if ([firstToken isEqualToString:@"link"]) {
                klass = [LinkReporterLine class];
            }

            if (klass != Nil) {
                reporter = [[klass alloc] initWithTokens:tokens];
                if (reporter != nil) {
                    [reporters$ setObject:reporter forKey:line];
                    [reporter release];
                }
            }
        }
    }
    return reporter;
}

+ (void)flushReporters {
    [reporters$ release];
    reporters$ = nil;
}

static NSCalendar *calendar$ = nil;

// FIXME: Does this belong in this class?
+ (NSString *)formatSyslogTime:(NSDate *)date {
    if (calendar$ == nil) {
        calendar$ = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    }

    static const char * const months[] = {"", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
    NSDateComponents *components = [calendar$ components:(
            NSMonthCalendarUnit | NSDayCalendarUnit |
            NSHourCalendarUnit | NSMinuteCalendarUnit
            )
        fromDate:date];
    return [NSString stringWithFormat:@"%s %2ld %02ld:%02ld", months[[components month]],
           (long)[components day], (long)[components hour], (long)[components minute]];
}

- (instancetype)initWithTokens:(NSArray *)tokens {
    self = [super init];
    if (self != nil) {
        tokens_ = [tokens copy];
    }
    return self;
}

- (void)dealloc {
    [title_ release];
    [tokens_ release];
    [super dealloc];
}

- (NSComparisonResult)compare:(ReporterLine *)reporter {
    Class thisClass = [self class];
    Class thatClass = [reporter class];
    if (thisClass == thatClass) {
        return [[self title] compare:[reporter title]];
    } else {
        return (thisClass == [LinkReporterLine class]) ? NSOrderedAscending : NSOrderedDescending;
    }
}

- (UITableViewCell *)format:(UITableViewCell *)cell {
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"."] autorelease];
    }

    UILabel *textLabel = cell.textLabel;
    textLabel.text = [self title];
    textLabel.textColor = [UIColor blackColor];

    UILabel *detailTextLabel = cell.detailTextLabel;
    detailTextLabel.font = [UIFont systemFontOfSize:9.0];
    detailTextLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
    detailTextLabel.numberOfLines = 2;

    return cell;
}

@end
