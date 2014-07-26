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

#import "IncludeInstruction.h"

#import "NSString+CrashReporter.h"
#import "Package.h"
#import "crashlog_util.h"

@interface Instruction (Private)
@property(nonatomic, copy) NSString *title;
@end

@implementation IncludeInstruction

@synthesize content = content_;
@synthesize filepath = filepath_;
@synthesize type = type_;

+ (NSArray *)includeInstructionsForPackage:(Package *)package {
    NSMutableArray *result = [NSMutableArray array];

    if (package != nil) {
        // Add (optional) include commands.
        for (NSString *line in package.config) {
            if ([line hasPrefix:@"include"]) {
                IncludeInstruction *instruction = [self instructionWithLine:line];
                if (instruction != nil) {
                    [result addObject:instruction];
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
                        type_ = IncludeInstructionTypeFile;
                        mode = ModeFilepath;
                    } else if ([token isEqualToString:@"command"]) {
                        type_ = IncludeInstructionTypeCommand;
                        mode = ModeFilepath;
                    } else if ([token isEqualToString:@"plist"]) {
                        type_ = IncludeInstructionTypePlist;
                        mode = ModeFilepath;
                    }
                    break;
                case ModeTitle:
                    title = [token stripQuotes];
                    mode = ModeAttribute;
                    break;
                case ModeFilepath:
                    goto loop_exit;
                default:
                    break;
            }
        }

loop_exit:
        filepath_ = [[[[tokens subarrayWithRange:NSMakeRange(index, (count - index))] componentsJoinedByString:@" "] stripQuotes] retain];
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
        if (type_ == IncludeInstructionTypeFile) {
            NSData *data = dataForFile(filepath);
            if (data != nil) {
                content_ = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
        } else if (type_ == IncludeInstructionTypePlist) {
            NSData *data = dataForFile(filepath);
            if (data != nil) {
                id plist = nil;
                if ([NSPropertyListSerialization respondsToSelector:@selector(propertyListWithData:options:format:error:)]) {
                    plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
                } else {
                    plist = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:0 format:NULL errorDescription:NULL];
                }
                content_ = [[plist description] retain];
            }
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
