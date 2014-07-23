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

// Referenced from searchfiles() of query.c of the dpkg source package.

#import "Package.h"

#include <stdio.h>

@implementation Package

@synthesize identifier = identifier_;
@synthesize storeIdentifier = storeIdentifier_;
@synthesize name = name_;
@synthesize author = author_;
@synthesize version = version_;
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
            f = popen([[NSString stringWithFormat:@"dpkg-query -p %@ | grep -E \"^(Name|Author|Version):\"", identifier_] UTF8String], "r");
            if (f != NULL) {
                // Determine name, author and version.
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
                                    NSString *value = [string substringFromIndex:firstNonSpace];
                                    if ([string hasPrefix:@"Name:"]) {
                                        name_ = [value retain];
                                    } else if ([string hasPrefix:@"Author:"]) {
                                        author_ = [value retain];
                                    } else {
                                        version_ = [value retain];
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
