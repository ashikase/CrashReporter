#import "ReporterLine.h"

@interface LinkReporterLine : ReporterLine
@property(nonatomic, readonly) NSString *unlocalizedTitle;
@property(nonatomic, readonly) NSString *urlString;
@property(nonatomic, readonly) BOOL isEmail;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
