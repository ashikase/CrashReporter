/*

   CrashLogFolderReader.m ... Data structures representing groups of crash logs.
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

#import "CrashLogGroup.h"

@implementation NSDate (ReverseCompare)
- (NSComparisonResult)reverseCompare:(NSDate *)date {
    return -[self compare:date];
}
@end

@implementation CrashLogGroup {
    NSMutableDictionary *datesAndFiles_;
}

@synthesize name = name_;
@synthesize logDirectory = logDirectory_;

+ (instancetype)groupWithName:(NSString *)name logDirectory:(NSString *)logDirectory {
    return [[[self alloc] initWithName:name logDirectory:logDirectory] autorelease];
}

- (instancetype)initWithName:(NSString *)name logDirectory:(NSString *)logDirectory {
    self = [super init];
    if (self != nil) {
        name_ = [name copy];
        logDirectory_ = [logDirectory copy];
        datesAndFiles_ = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc {
    [name_ release];
    [logDirectory_ release];
    [datesAndFiles_ release];
    [super dealloc];
}


- (void)addFilename:(NSString *)filename forDate:(NSDate *)date {
    [datesAndFiles_ setObject:filename forKey:date];
}

- (NSArray *)dates {
    return [[datesAndFiles_ allKeys] sortedArrayUsingSelector:@selector(reverseCompare:)];
}

- (NSArray *)files {
    NSMutableArray *files = [NSMutableArray array];
    for (NSDate *date in [self dates]) {
        [files addObject:[datesAndFiles_ objectForKey:date]];
    }
    return files;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
