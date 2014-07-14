/*

   reporter.h ... Data structure representing lines of blame scripts.
   Copyright (C) 2009  KennyTM~ <kennytm@gmail.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

 */

/*
   Reporter syntax:

   include [as <title>] file <filename>
   include [as <title>] command <command>

   deny <link title>

   link [as <title>] url <URL>
   link [as <title>] email <comma-separated Email addresses>

 */

#import <UIKit/UIKit.h>
#import "find_dpkg.h"

@interface ReporterLine : NSObject
@property(nonatomic, readonly) NSString *title;
@property(nonatomic, readonly) NSArray *tokens;
+ (ReporterLine *)reporterWithLine:(NSString *)line;
- (instancetype)initWithTokens:(NSArray *)tokens;
+ (void)flushReporters;
+ (NSString *)formatSyslogTime:(NSDate *)date;
+ (NSArray *)reportersWithSuspect:(NSString *)suspectPath appendReporters:(NSArray *)reporters package:(struct Package *)pPackage isAppStore:(BOOL *)pIsAppStore;
- (NSComparisonResult)compare:(ReporterLine *)other;
- (UITableViewCell *)format:(UITableViewCell *)cell;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
