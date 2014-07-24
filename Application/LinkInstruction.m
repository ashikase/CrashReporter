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

#import "LinkInstruction.h"

#import <RegexKitLite/RegexKitLite.h>
#import "NSString+CrashReporter.h"
#import "Package.h"

@interface Instruction (Private)
@property(nonatomic, copy) NSString *title;
@end

@implementation LinkInstruction

@synthesize recipients = recipients_;
@synthesize unlocalizedTitle = unlocalizedTitle_;
@synthesize url = url_;
@synthesize isEmail = isEmail_;
@synthesize isSupport = isSupport_;

+ (NSArray *)linkInstructionsForPackage:(Package *)package {
    NSMutableArray *result = [NSMutableArray array];

    if (package != nil) {
        BOOL hasSupportLink = NO;

        // Load optional link commands.
        // NOTE: This is done first in order to determine if package provides
        //       own support link(s).
        NSMutableArray *instructions = [NSMutableArray new];
        for (NSString *line in package.config) {
            if ([line hasPrefix:@"link"]) {
                LinkInstruction *instruction = [self instructionWithLine:line];
                if (instruction != nil) {
                    if (instruction.isSupport) {
                        hasSupportLink = YES;
                    }
                    [instructions addObject:instruction];
                }
            }
        }

        if (package.isAppStore) {
            // Add App Store link.
            // NOTE: Must use long long here as there are over 2 billion apps on the App Store.
            long long item = [package.storeIdentifier longLongValue];
            NSString *line = [NSString stringWithFormat:
                @"link url \"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=%lld&mt=8\" as \"%@\"",
                item, NSLocalizedString(@"VIEW_IN_APP_STORE", nil)];
            LinkInstruction *instruction = [self instructionWithLine:line];
            if (instruction != nil) {
                [result addObject:instruction];
            }
        } else {
            if (!hasSupportLink) {
                // Add email link to contact author.
                NSString *author = package.author;
                if (author != nil) {
                    NSRange leftAngleRange = [author rangeOfString:@"<" options:NSBackwardsSearch];
                    if (leftAngleRange.location != NSNotFound) {
                        NSRange rightAngleRange = [author rangeOfString:@">" options:NSBackwardsSearch];
                        if (rightAngleRange.location != NSNotFound) {
                            if (leftAngleRange.location < rightAngleRange.location) {
                                NSRange range = NSMakeRange(leftAngleRange.location + 1, rightAngleRange.location - leftAngleRange.location - 1);
                                NSString *emailAddress = [author substringWithRange:range];
                                NSString *line = [NSString stringWithFormat:@"link email %@ as \"%@\" is_support",
                                    emailAddress, NSLocalizedString(@"CONTACT_AUTHOR", nil)];
                                LinkInstruction *instruction = [self instructionWithLine:line];
                                if (instruction != nil) {
                                    [result addObject:instruction];
                                }
                            }
                        }
                    }
                }
            }

            // Add Cydia link.
            NSString *line = [NSString stringWithFormat:@"link url \"cydia://package/%@\" as \"%@\"",
                package.storeIdentifier, NSLocalizedString(@"VIEW_IN_CYDIA", nil)];
            LinkInstruction *instruction = [self instructionWithLine:line];
            if (instruction != nil) {
                [result addObject:instruction];
            }
        }

        // Add optional link commands.
        [result addObjectsFromArray:instructions];
        [instructions release];
    }

    // Add an email link to send to an arbitrary address.
    NSString *line = [NSString stringWithFormat:@"link email \"\" as \"%@\" is_support", NSLocalizedString(@"FORWARD_TO", nil)];
    LinkInstruction *instruction = [self instructionWithLine:line];
    if (instruction != nil) {
        [result addObject:instruction];
    }

    return result;
}

// NOTE: Format is:
//
//       link [as "<title>"] [is_support] url <URL>
//       link [as "<title>"] [is_support] email <comma-separated email addresses>
//
- (instancetype)initWithTokens:(NSArray *)tokens {
    self = [super initWithTokens:tokens];
    if (self != nil) {
        enum {
            ModeAttribute,
            ModeRecipients,
            ModeTitle,
            ModeURL
        } mode = ModeAttribute;

        for (NSString *token in tokens) {
            switch (mode) {
                case ModeAttribute:
                    if ([token isEqualToString:@"as"]) {
                        mode = ModeTitle;
                    } else if ([token isEqualToString:@"email"]) {
                        isEmail_ = YES;
                        mode = ModeRecipients;
                    } else if ([token isEqualToString:@"is_support"]) {
                        isSupport_ = YES;
                    } else if ([token isEqualToString:@"url"]) {
                        mode = ModeURL;
                    }
                    break;
                case ModeRecipients:
                    // TODO: Consider adding a proper check for email addresses.
                    if ([token rangeOfString:@"@"].location != NSNotFound) {
                        recipients_ = [[token componentsSeparatedByRegex:@",\\s*"] retain];
                    }
                    mode = ModeAttribute;
                    break;
                case ModeTitle:
                    unlocalizedTitle_ = [[token stripQuotes] retain];
                    mode = ModeAttribute;
                    break;
                case ModeURL:
                    url_ = [[NSURL alloc] initWithString:[token stripQuotes]];
                    mode = ModeAttribute;
                    break;
                default:
                    break;
            }
        }

        if (unlocalizedTitle_ == nil) {
            unlocalizedTitle_ = [(isEmail_ ? recipients_ : [url_ absoluteString]) copy];
        }
        [self setTitle:NSLocalizedString(unlocalizedTitle_, nil)];
    }
    return self;
}

- (void)dealloc {
    [recipients_ release];
    [unlocalizedTitle_ release];
    [url_ release];
    [super dealloc];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
