#import "ReporterLine.h"

typedef enum {
    IncludeReporterLineCommandTypeFile,
    IncludeReporterLineCommandTypePlist,
    IncludeReporterLineCommandTypeCommand
} IncludeReporterLineCommandType;

@interface IncludeReporterLine : ReporterLine
@property(nonatomic, readonly) NSString *content;
@property(nonatomic, readonly) NSString *filepath;
@property(nonatomic, readonly) IncludeReporterLineCommandType type;
+ (NSArray *)includeReportersForPackage:(Package *)package;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
