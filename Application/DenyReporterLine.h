#import "ReporterLine.h"

@interface DenyReporterLine : ReporterLine
+ (NSArray *)denyReportersForPackage:(Package *)package;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
