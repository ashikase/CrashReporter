#import "NSString+CrashReporter.h"

@implementation NSString (CrashReporter)

- (NSString *)stripQuotes {
    NSUInteger length = [self length];
    if (length >= 2) {
        if (([self characterAtIndex:0] == '"') && ([self characterAtIndex:(length - 1)] == '"')) {
            return [self substringWithRange:NSMakeRange(1, (length - 2))];
        }
    }
    return [[self copy] autorelease];
}

@end
