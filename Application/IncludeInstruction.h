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
