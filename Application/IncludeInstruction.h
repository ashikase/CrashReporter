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

#import "Instruction.h"

typedef enum {
    IncludeInstructionTypeFile,
    IncludeInstructionTypePlist,
    IncludeInstructionTypeCommand
} IncludeInstructionType;

@interface IncludeInstruction : Instruction
@property(nonatomic, readonly) NSString *content;
@property(nonatomic, readonly) NSString *filepath;
@property(nonatomic, readonly) IncludeInstructionType type;
+ (NSArray *)includeInstructionsForPackage:(Package *)package;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
