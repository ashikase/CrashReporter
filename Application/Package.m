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

#import "Package.h"

#include <stdio.h>

@implementation Package

@synthesize identifier = identifier_;
@synthesize storeIdentifier = storeIdentifier_;
@synthesize name = name_;
@synthesize author = author_;
@synthesize config = config_;
@synthesize isAppStore = isAppStore_;

+ (instancetype)packageForFile:(NSString *)path {
    return [[[self alloc] initForFile:path] autorelease];
}

- (instancetype)initForFile:(NSString *)path {
    self = [super init];
    if (self != nil) {
        // Determine identifier of the package that contains the specified file.
        // NOTE: We need the slow way or we need to compile the whole dpkg.
        //       Not worth it for a minor feature like this.
        FILE *f = popen([[NSString stringWithFormat:@"dpkg-query -S %@ | head -1", path] UTF8String], "r");
        if (f != NULL) {
            // NOTE: Since there's only 1 line, we can read until a , or : is hit.
            NSMutableData *data = [NSMutableData new];
            char buf[1025];
            size_t maxSize = (sizeof(buf) - 1);
            while (!feof(f)) {
                size_t actualSize = fread(buf, 1, maxSize, f);
                buf[actualSize] = '\0';
                size_t identifierSize = strcspn(buf, ",:");
                [data appendBytes:buf length:identifierSize];

                // TODO: What is the purpose of this line?
                if (identifierSize != maxSize) {
                    break;
                }
            }
            if ([data length] > 0) {
                identifier_ = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            [data release];
            pclose(f);
        }

        // Determine package type, name and author, and load optional config.
        if (identifier_ != nil) {
            // Is a dpkg.
            f = popen([[NSString stringWithFormat:@"dpkg-query -p %@ | grep -E \"^(Name|Author):\"", identifier_] UTF8String], "r");
            if (f != NULL) {
                // Determine name and author.
                NSMutableData *data = [NSMutableData new];
                char buf[1025];
                size_t maxSize = (sizeof(buf) - 1);
                while (!feof(f)) {
                    if (fgets(buf, maxSize, f)) {
                        buf[maxSize] = '\0';

                        char *newlineLocation = strrchr(buf, '\n');
                        if (newlineLocation != NULL) {
                            [data appendBytes:buf length:(NSUInteger)(newlineLocation - buf)];

                            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                            NSUInteger firstColon = [string rangeOfString:@":"].location;
                            if (firstColon != NSNotFound) {
                                NSUInteger length = [string length];
                                if (length > (firstColon + 1)) {
                                    NSCharacterSet *set = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
                                    NSRange range = NSMakeRange((firstColon + 1), (length - firstColon - 1));
                                    NSUInteger firstNonSpace = [string rangeOfCharacterFromSet:set options:0 range:range].location;
                                    if ([string hasPrefix:@"Name:"]) {
                                        name_ = [[string substringFromIndex:firstNonSpace] retain];
                                    } else {
                                        author_ = [[string substringFromIndex:firstNonSpace] retain];
                                    }
                                }
                            }
                            [string release];
                            [data setLength:0];
                        } else {
                            [data appendBytes:buf length:maxSize];
                        }
                    }
                }
                [data release];
                pclose(f);
            }

            // Ensure that package has a name.
            if (name_ == nil) {
                // Use name of contained file.
                name_ = [[path lastPathComponent] retain];
            }

            // Determine store identifier.
            storeIdentifier_ = [identifier_ copy];

            // Add preferences file include command (if file exists).
            NSMutableArray *config = [NSMutableArray new];
            NSString *filepath = [[NSString alloc] initWithFormat:@"/var/mobile/Library/Preferences/%@.plist", identifier_];
            if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
                NSString *string = [[NSString alloc] initWithFormat:@"include as Preferences plist \"%@\"", filepath];
                [config addObject:string];
                [string release];
            }
            [filepath release];

            // Load commands from optional config file.
            NSString *configFile = [NSString stringWithFormat:@"/var/lib/dpkg/info/%@.crash_reporter", identifier_];
            NSString *configString = [[NSString alloc] initWithContentsOfFile:configFile usedEncoding:NULL error:NULL];
            if ([configString length] > 0) {
                [config addObjectsFromArray:[configString componentsSeparatedByString:@"\n"]];
            }
            [configString release];

            config_ = config;
        } else {
            // Not a dpkg package. Check if it's an AppStore app.
            if ([path hasPrefix:@"/var/mobile/Applications/"]) {
                // Check if any component in the path has a .app suffix.
                NSString *appBundlePath = path;
                do {
                    appBundlePath = [appBundlePath stringByDeletingLastPathComponent];
                    if ([appBundlePath length] == 0) {
                        [self release];
                        return nil;
                    }
                } while (![appBundlePath hasSuffix:@".app"]);

                // If we made it this far, this is an AppStore package.
                isAppStore_ = YES;

                // Determine identifier, store identifier, name and author.
                NSString *metadataPath = [[appBundlePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"];
                NSDictionary *metadata = [[NSDictionary alloc] initWithContentsOfFile:metadataPath];
                identifier_ = [[metadata objectForKey:@"softwareVersionBundleId"] retain];
                storeIdentifier_ = [[metadata objectForKey:@"itemId"] retain];
                name_ = [[metadata objectForKey:@"itemName"] retain];
                author_ = [[metadata objectForKey:@"artistName"] retain];
                [metadata release];

                // Add preferences file include command (if file exists).
                NSMutableArray *config = [NSMutableArray new];
                NSString *filepath = [[NSString alloc] initWithFormat:@"%@/Library/Preferences/%@.plist",
                         [appBundlePath stringByDeletingLastPathComponent], identifier_];
                if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
                    NSString *string = [[NSString alloc] initWithFormat:@"include as Preferences plist \"%@\"", filepath];
                    [config addObject:string];
                    [string release];
                }
                [filepath release];

                // Load commands from optional config file.
                NSString *configPath = [appBundlePath stringByAppendingPathComponent:@"crash_reporter"];
                NSString *configString = [[NSString alloc] initWithContentsOfFile:configPath usedEncoding:NULL error:NULL];
                if ([configString length] > 0) {
                    [config addObjectsFromArray:[configString componentsSeparatedByString:@"\n"]];
                }
                [configString release];

                config_ = config;
            } else {
                // Was not installed via either Cydia (dpkg) or AppStore; unsupported.
                [self release];
                return nil;
            }
        }
    }
    return self;
}

- (void)dealloc {
    [identifier_ release];
    [storeIdentifier_ release];
    [name_ release];
    [author_ release];
    [config_ release];
    [super dealloc];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
