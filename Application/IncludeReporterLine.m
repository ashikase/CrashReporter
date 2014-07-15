#import "IncludeReporterLine.h"

#import "NSString+CrashReporter.h"

@interface ReporterLine (Private)
@property(nonatomic, copy) NSString *title;
@end

typedef enum {
    IncludeReporterLineCommandTypeFile,
    IncludeReporterLineCommandTypePlist,
    IncludeReporterLineCommandTypeCommand
} IncludeReporterLineCommandType;

@implementation IncludeReporterLine {
    IncludeReporterLineCommandType commandType_;
}

@synthesize content = content_;
@synthesize filepath = filepath_;

- (instancetype)initWithTokens:(NSArray *)tokens {
    self = [super initWithTokens:tokens];
    if (self != nil) {
        NSUInteger count = [tokens count];
        if (count < 3) {
            [self release];
            return nil;
        }

        NSString *title = nil;
        NSUInteger filepathIndex = 2;
        NSString *command = [tokens objectAtIndex:1];
        if ([command isEqualToString:@"as"]) {
            if (count < 5) {
                [self release];
                return nil;
            }
            title = [[tokens objectAtIndex:2] stripQuotes];
            command = [tokens objectAtIndex:3];
            filepathIndex = 4;
        }

        if ([command isEqualToString:@"command"]) {
            commandType_ = IncludeReporterLineCommandTypeCommand;
        } else if ([command isEqualToString:@"plist"]) {
            commandType_ = IncludeReporterLineCommandTypePlist;
        } else {
            commandType_ = IncludeReporterLineCommandTypeFile;
        }

        filepath_ = [[[[tokens subarrayWithRange:NSMakeRange(filepathIndex, (count - filepathIndex))] componentsJoinedByString:@" "] stripQuotes] retain];

        [self setTitle:(title ?: filepath_)];
    }
    return self;
}

- (void)dealloc {
    [content_ release];
    [filepath_ release];
    [super dealloc];
}

- (UITableViewCell *)format:(UITableViewCell *)cell {
    cell = [super format:cell];
    cell.detailTextLabel.text = filepath_;
    return cell;
}

- (NSString *)content {
    if (content_ == nil) {
        NSMutableString *result = nil;
        if (commandType_ == IncludeReporterLineCommandTypeFile) {
            result = [[NSMutableString alloc] initWithContentsOfFile:filepath_ usedEncoding:NULL error:NULL];
        } else if (commandType_ == IncludeReporterLineCommandTypePlist) {
            NSData *data = [NSData dataWithContentsOfFile:filepath_];
            id prop = [NSPropertyListSerialization propertyListFromData:data
                mutabilityOption:NSPropertyListImmutable
                format:NULL errorDescription:NULL];
            result = [[prop description] mutableCopy];
        } else {
            fflush(stdout);
            FILE *f = popen([filepath_ UTF8String], "r");
            if (f == NULL) {
                return nil;
            }

            result = [NSMutableString new];
            while (!feof(f)) {
                char buf[1024];
                size_t charsRead = fread(buf, 1, sizeof(buf), f);
                [result appendFormat:@"%.*s", (int)charsRead, buf];
            }
            pclose(f);
        }
        [result insertString:[NSString stringWithFormat:@"## %@\n", [self title]] atIndex:0];
        [result appendString:@"\n"];
        content_ = result;
    }
    return content_;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
