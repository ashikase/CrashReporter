#import "IncludeReporterLine.h"

#import "Package.h"

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

+ (NSArray *)includeReportersForPackage:(Package *)package {
    NSMutableArray *result = [NSMutableArray array];

    if (package != nil) {
        // Add (optional) include commands.
        for (NSString *line in package.config) {
            if ([line hasPrefix:@"include"]) {
                IncludeReporterLine *reporter = [IncludeReporterLine reporterWithLine:line];
                if (reporter != nil) {
                    [result addObject:reporter];
                }
            }
        }
    }

    return result;
}

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
            title = [tokens objectAtIndex:2];
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

        filepath_ = [[[tokens subarrayWithRange:NSMakeRange(filepathIndex, (count - filepathIndex))] componentsJoinedByString:@" "] retain];

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
        NSString *filepath = [self filepath];
        if (commandType_ == IncludeReporterLineCommandTypeFile) {
            content_ = [[NSString alloc] initWithContentsOfFile:filepath usedEncoding:NULL error:NULL];
        } else if (commandType_ == IncludeReporterLineCommandTypePlist) {
            NSData *data = [NSData dataWithContentsOfFile:filepath];
            id plist = nil;
            if ([NSPropertyListSerialization respondsToSelector:@selector(propertyListWithData:options:format:error:)]) {
                plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
            } else {
                plist = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:0 format:NULL errorDescription:NULL];
            }
            content_ = [[plist description] retain];
        } else {
            fflush(stdout);
            FILE *f = popen([filepath UTF8String], "r");
            if (f == NULL) {
                return nil;
            }

            NSMutableString *string = [NSMutableString new];
            while (!feof(f)) {
                char buf[1024];
                size_t charsRead = fread(buf, 1, sizeof(buf), f);
                [string appendFormat:@"%.*s", (int)charsRead, buf];
            }
            pclose(f);
            content_ = string;
        }
    }
    return content_;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
