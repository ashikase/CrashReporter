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

#import <Foundation/Foundation.h>

@interface CrashLog : NSObject
@property(nonatomic, readonly) NSString *filepath;
@property(nonatomic, readonly) NSString *processName;
@property(nonatomic, readonly) NSString *processPath;
@property(nonatomic, readonly) NSArray *suspects;
@property(nonatomic, readonly) NSDate *date;
@property(nonatomic, readonly, getter = isSymbolicated) BOOL symbolicated;
- (instancetype)initWithFilepath:(NSString *)filepath;
- (void)delete;
- (void)symbolicate;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
