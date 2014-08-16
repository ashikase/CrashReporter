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

extern NSString * const kViewedCrashLogs;

#import <Foundation/Foundation.h>

@interface CrashLog : NSObject
@property(nonatomic, readonly) NSString *filepath;
@property(nonatomic, readonly) NSString *logName;
@property(nonatomic, readonly) NSDate *logDate;
@property(nonatomic, readonly) NSString *processPath;
@property(nonatomic, readonly) NSArray *blamableBinaries;
@property(nonatomic, readonly) NSArray *suspects;
@property(nonatomic, readonly, getter = isSymbolicated) BOOL symbolicated;
@property(nonatomic, assign, getter = isViewed) BOOL viewed;
- (instancetype)initWithFilepath:(NSString *)filepath;
- (BOOL)delete;
- (BOOL)symbolicate;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
