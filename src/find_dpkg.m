/*

find_dpkg.m ... Find the package owning that file via dpkg-query.
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
#import "find_dpkg.h"
#include <stdio.h>

struct Package findPackage(NSString* file) {
	// We need the slow way or we need to compile the whole dpkg. Not worth it for a minor feature like this.
	struct Package res;
	memset(&res, 0, sizeof(res));

	char res_cstr[1025];
	FILE* f = popen([[NSString stringWithFormat:@"dpkg-query -S %@ | head -1", file] UTF8String], "r");
	NSMutableData* pkg_data = [[NSMutableData alloc] init];

	if (f != NULL) {
		// since there's only 1 line, we can read until a , or : is hit.
		while (!feof(f)) {
			size_t actual_size = fread(res_cstr, 1, sizeof(res_cstr)-1, f);
			res_cstr[actual_size] = '\0';
			size_t pkg_len_0 = strcspn(res_cstr, ",:");
			[pkg_data appendBytes:res_cstr length:pkg_len_0];
			if (pkg_len_0 != sizeof(res_cstr)-1)
				break;
		}
		if ([pkg_data length] > 0) {
			res.identifier = [[[NSString alloc] initWithData:pkg_data encoding:NSUTF8StringEncoding] autorelease];
			[pkg_data setLength:0];
		}
		pclose(f);
	}

	if (res.identifier != nil) {
		f = popen([[NSString stringWithFormat:@"dpkg-query -p %@ | grep -E \"^(Name|Author):\"", res.identifier] UTF8String], "r");
		if (f != NULL) {
			while (!feof(f)) {
				if (fgets(res_cstr, sizeof(res_cstr)-1, f)) {
					res_cstr[sizeof(res_cstr)-1] = '\0';
					char* nlloc = strrchr(res_cstr, '\n');

					[pkg_data appendBytes:res_cstr length:(nlloc ? (NSUInteger)(nlloc-res_cstr) : sizeof(res_cstr)-1)];
					if (nlloc != NULL) {
						NSString* s = [[NSString alloc] initWithData:pkg_data encoding:NSUTF8StringEncoding];
						NSString** whereToStore = [s hasPrefix:@"Name:"] ? &(res.name) : &(res.author);
						NSUInteger firstColon = [s rangeOfString:@":"].location;
						NSUInteger sLen = [s length];
						if (firstColon != NSNotFound && sLen > firstColon+1) {
							NSUInteger firstNonSpace = [s rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]
																		  options:0 range:NSMakeRange(firstColon+1, sLen-firstColon-1)].location;
							*whereToStore = [s substringFromIndex:firstNonSpace];
						}
						[s release];
						[pkg_data setLength:0];
					}
				}
			}
			pclose(f);
		}

		NSString* blameConfigFile = [NSString stringWithFormat:@"/var/lib/dpkg/info/%@.crash_reporter", res.identifier];
		NSString* blameConfigContent = [[NSString alloc] initWithContentsOfFile:blameConfigFile usedEncoding:NULL error:NULL];
		res.blameConfig = [blameConfigContent componentsSeparatedByString:@"\n"];
		[blameConfigContent release];
	}

	[pkg_data release];

#if 0
	struct filenamenode* namenode = findnamenode([file UTF8String], 0);
	if (namenode) {
		struct filepackages* packageslump = namenode->packages;
		if (packageslump) {
			struct pkginfo* info = packageslump->pkgs[0];
			if (info) {
				res.identifier = [NSString stringWithUTF8String:info->name];
//				res.name = res.identifier;
				struct arbitraryfield* arb = info->installed.arbs;
				while (arb != NULL) {
//					if (strcmp(arb->name, "Name") == 0)
//						res.name = [NSString stringWithUTF8String:arb->value];
/*					else*/ if (strcmp(arb->name, "Author") == 0) {
						res.author = [NSString stringWithUTF8String:arb->value];
						break;
					}
					arb = arb->next;
				}

				// Wha?
				NSString* blameConfigFile = [NSString stringWithFormat:@"/var/lib/dpkg/info/%s.crash_reporter", info->name];
				NSString* blameConfigContent = [[NSString alloc] initWithContentsOfFile:blameConfigFile usedEncoding:NULL error:NULL];
				res.blameConfig = [blameConfigContent componentsSeparatedByString:@"\n"];
				[blameConfigContent release];
			}
		}
	}
#endif

	return res;
}
