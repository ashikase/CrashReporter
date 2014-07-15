/*

find_dpkg.h ... Find the package owning that file via dpkg-query.
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

// Referenced from searchfiles() of query.c of the dpkg source package.

#import <Foundation/Foundation.h>

@interface Package : NSObject
@property(nonatomic, readonly) NSString *identifier;
@property(nonatomic, readonly) NSString *storeIdentifier;
@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) NSString *author;
@property(nonatomic, readonly) NSArray *config;
@property(nonatomic, readonly) BOOL isAppStore;
+ (instancetype)packageForFile:(NSString *)path;
@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
