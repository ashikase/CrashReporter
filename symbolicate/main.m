/*

main.m ... Main for CrashReporter
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

#import <UIKit/UIKit.h>
#import "symbolicate.h"
#include <string.h>

int main (int argc, char* argv[]) {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	int rv = 0;

#if !TARGET_IPHONE_SIMULATOR
	if (argc > 2 && strcmp(argv[1], "-s") == 0) {

		NSString* file = [NSString stringWithUTF8String:argv[2]];
		NSString* res = symbolicate(file, nil);

		printf("Result written to %s.\n", [res UTF8String]);

	}
#endif

	[pool drain];
	return rv;
}
