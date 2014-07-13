#import <Foundation/Foundation.h>

@interface CrashLog : NSObject
@property(nonatomic, readonly) NSString *filepath;
@property(nonatomic, readonly) NSString *processName;
@property(nonatomic, readonly) NSDate *date;
@property(nonatomic, readonly, getter = isSymbolicated) BOOL symbolicated;
- (instancetype)initWithFilepath:(NSString *)filepath;
- (void)symbolicate;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
