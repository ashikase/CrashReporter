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

@interface Package : NSObject
@property(nonatomic, readonly) NSString *identifier;
@property(nonatomic, readonly) NSString *storeIdentifier;
@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) NSString *author;
@property(nonatomic, readonly) NSString *version;
@property(nonatomic, readonly) NSArray *config;
@property(nonatomic, readonly) BOOL isAppStore;
+ (instancetype)packageForFile:(NSString *)path;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
