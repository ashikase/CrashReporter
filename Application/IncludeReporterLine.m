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
                IncludeReporterLine *reporter = [self reporterWithLine:line];
                if (reporter != nil) {
                    [result addObject:reporter];
                }
            }
        }
    }

    return result;
}

// NOTE: Format is:
//
//       include [as <title>] file <filename>
//       include [as <title>] command <command>
//       include [as <title>] plist <filename>
//
- (instancetype)initWithTokens:(NSArray *)tokens {
    self = [super initWithTokens:tokens];
    if (self != nil) {
        NSString *title = nil;

        enum {
            ModeAttribute,
            ModeFilepath,
            ModeTitle
        } mode = ModeAttribute;

        NSUInteger count = [tokens count];
        NSUInteger index;
        for (index = 0; index < count; ++index) {
            NSString *token = [tokens objectAtIndex:index];
            switch (mode) {
                case ModeAttribute:
                    if ([token isEqualToString:@"as"]) {
                        mode = ModeTitle;
                    } else if ([token isEqualToString:@"file"]) {
                        commandType_ = IncludeReporterLineCommandTypeFile;
                        mode = ModeFilepath;
                    } else if ([token isEqualToString:@"command"]) {
                        commandType_ = IncludeReporterLineCommandTypeCommand;
                        mode = ModeFilepath;
                    } else if ([token isEqualToString:@"plist"]) {
                        commandType_ = IncludeReporterLineCommandTypePlist;
                        mode = ModeFilepath;
                    }
                    break;
                case ModeTitle:
                    title = token;
                    mode = ModeAttribute;
                    break;
                case ModeFilepath:
                    goto loop_exit;
                default:
                    break;
            }
        }

loop_exit:
        filepath_ = [[[tokens subarrayWithRange:NSMakeRange(index, (count - index))] componentsJoinedByString:@" "] retain];
        NSLog(@"filepath = %@", filepath_);
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
            NSLog(@"1:FILEPATH: %@", filepath);
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
            NSLog(@"2:FILEPATH: %@", filepath);
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
            NSLog(@"CONTENT: %@", content_);
        }
    }
    return content_;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
