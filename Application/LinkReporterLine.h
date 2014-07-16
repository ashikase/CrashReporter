#import "ReporterLine.h"

@interface LinkReporterLine : ReporterLine
@property(nonatomic, readonly) NSString *recipients;
@property(nonatomic, readonly) NSString *unlocalizedTitle;
@property(nonatomic, readonly) NSURL *url;
@property(nonatomic, readonly) BOOL isEmail;
@property(nonatomic, readonly) BOOL isSupport;
+ (NSArray *)linkReportersForPackage:(Package *)package;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
