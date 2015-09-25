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

extern NSString * const kViewedCrashLogs;

typedef enum : NSUInteger {
    CrashLogTypeUnknown,
    CrashLogTypeApp,
    CrashLogTypeAppExtension,
    CrashLogTypeService
} CrashLogType;

@class CRBinaryImage;

@interface CrashLog : NSObject
@property(nonatomic, readonly) NSString *filepath;
@property(nonatomic, readonly) NSString *logName;
@property(nonatomic, readonly) NSDate *logDate;
@property(nonatomic, readonly) CrashLogType type;
@property(nonatomic, readonly) CRBinaryImage *victim;
@property(nonatomic, readonly) NSArray *suspects;
@property(nonatomic, readonly) NSArray *potentialSuspects;
@property(nonatomic, readonly, getter = isLoaded) BOOL loaded;
@property(nonatomic, readonly, getter = isSymbolicated) BOOL symbolicated;
@property(nonatomic, assign, getter = isViewed) BOOL viewed;
- (instancetype)initWithFilepath:(NSString *)filepath;
- (BOOL)delete;
- (BOOL)load;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
