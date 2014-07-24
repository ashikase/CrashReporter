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

#import <UIKit/UIKit.h>

@class Package;

@interface Instruction : NSObject
@property(nonatomic, copy) NSString *title;
@property(nonatomic, readonly) NSArray *tokens;
+ (instancetype)instructionWithLine:(NSString *)line;
+ (void)flushInstructions;
- (instancetype)initWithTokens:(NSArray *)tokens;
- (NSComparisonResult)compare:(Instruction *)other;
- (UITableViewCell *)format:(UITableViewCell *)cell;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
