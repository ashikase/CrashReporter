#import "DenyReporterLine.h"

#import "NSString+CrashReporter.h"

@interface ReporterLine (Private)
@property(nonatomic, copy) NSString *title;
@end

@implementation DenyReporterLine

- (instancetype)initWithTokens:(NSArray *)tokens {
    self = [super initWithTokens:tokens];
    if (self != nil) {
        NSUInteger count = [tokens count];
        NSString *string = [[tokens subarrayWithRange:NSMakeRange(1, count - 1)] componentsJoinedByString:@" "];
        [self setTitle:[string stripQuotes]];
    }
    return self;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
