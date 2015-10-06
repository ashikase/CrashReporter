/**
 * Name: scanner
 * Type: iOS extension
 * Desc: Scans tweaks for known issues.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import <CommonCrypto/CommonDigest.h>
#import <libpackageinfo/libpackageinfo.h>
#include <sys/stat.h>
#include <objc/runtime.h>

#import "CRMissingFilterAlertItem.h"

#ifdef PKG_ID
#undef PKG_ID
#endif
#define PKG_ID "jp.ashikase.crashreporter"
#define TWEAK_ID PKG_ID".scanner"

static const char * const kDefaultTweakPath = "/Library/MobileSubstrate/DynamicLibraries";

CFArrayRef substrate_createListOfDylibs() {
    CFArrayRef dylibs = NULL;

    // Create URL for default path that Substrate searches for tweaks.
    CFURLRef libraries =
        CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8 *)kDefaultTweakPath, strlen(kDefaultTweakPath), TRUE);

    // Create a bundle representing said path.
    CFBundleRef folder = CFBundleCreate(kCFAllocatorDefault, libraries);
    CFRelease(libraries);

    if (folder != NULL) {
        // Get a list of dylibs at said path.
        dylibs = CFBundleCopyResourceURLsOfType(folder, CFSTR("dylib"), NULL);
        CFRelease(folder);
    }

    return dylibs;
}

static NSString *md5(NSString *path) {
    NSMutableString *string = nil;

    NSData *data = [[NSData alloc] initWithContentsOfFile:path];
    if (data != nil) {
        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        CC_MD5(data.bytes, data.length, digest);

        // Convert unsigned char buffer to NSString of hex values
        string = [NSMutableString stringWithCapacity:(CC_MD5_DIGEST_LENGTH * 2)];
        for (unsigned i = 0; i < CC_MD5_DIGEST_LENGTH; ++i) {
            [string appendFormat:@"%02x", digest[i]];
        }

        [data release];
    }

    return string;
}

static void processDylibs() {
    static NSString * const kCrashReporterScanned = @"scanned";

    // Retrieve list of dylib files.
    CFArrayRef dylibs = substrate_createListOfDylibs();
    if (dylibs != NULL) {
        // Create list to track which dylibs have been scanned.
        // NOTE: This list is recreated each time so that only tweaks that are
        //       currently installed are remembered. If a user uninstalls a
        //       tweak and then reinstalls that same version at a later point,
        //       they should be reminded again of any issues with said tweak.
        NSMutableDictionary *scannedDylibs = [[NSMutableDictionary alloc] init];

        // Retrieve list of previously-scanned dylibs.
        // NOTE: Must synchronize preferences in case they have changed on disk.
        NSDictionary *prevScannedDylibs = nil;
        CFPreferencesAppSynchronize(CFSTR(TWEAK_ID));
        CFPropertyListRef propList = CFPreferencesCopyAppValue((CFStringRef)kCrashReporterScanned, CFSTR(TWEAK_ID));
        if (propList != NULL) {
            if (CFGetTypeID(propList) == CFDictionaryGetTypeID()) {
                // NOTE: Don't forget to release when finished using.
                prevScannedDylibs = (NSDictionary *)propList;
            } else {
                CFRelease(propList);
            }
        }

        for (NSURL *url in (NSArray *)dylibs) {
            NSString *path = [url path];
            if (path != nil) {
                NSString *filename = [path lastPathComponent];

                // Determine MD5 digest for dylib file.
                // NOTE: This is used to differentiate the file from other
                //       versions (or other dylibs with the same filename).
                NSString *digest = md5(path);
                if (digest == nil) {
                    // Failed to calculate MD5 digest.
                    // NOTE: This can occur if the dylib is a dead symbolic link.
                    // TODO: Consider displaying a notification about the dead link.
                    NSLog(@"WARNING: Possible dead symbolic link: %@", path);
                    continue;
                }

                // Record that dylib has been scanned.
                [scannedDylibs setObject:digest forKey:filename];

                // Determine if dylib was previously scanned.
                id object = [prevScannedDylibs objectForKey:filename];
                if ([object isKindOfClass:[NSString class]]) {
                    if ([object isEqualToString:digest]) {
                        // Previously scanned.
                        continue;
                    }
                }

                // Determine if dylib is missing filter file.
                NSString *filterPath = [NSString stringWithFormat:@"%s/%@.plist", kDefaultTweakPath, [filename stringByDeletingPathExtension]];
                struct stat st;
                if (stat([filterPath UTF8String], &st) != 0) {
                    // Filter is missing.
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [objc_getClass("CRMissingFilterAlertItem") showForPath:path];
                    });
                }
            } else {
                NSLog(@"ERROR: Failed to obtain path for dylib URL: %@", [url relativeString]);
            }
        }

        // Update stored list of scanned dylibs.
        CFPreferencesSetAppValue((CFStringRef)kCrashReporterScanned, scannedDylibs, CFSTR(TWEAK_ID));
        CFPreferencesAppSynchronize(CFSTR(TWEAK_ID));

        // Clean-up.
        [scannedDylibs release];
        [prevScannedDylibs release];
        CFRelease(dylibs);
    }
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig();

    dispatch_queue_t queue;
    if (IOS_LT(5_0)) {
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    } else {
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    }

    dispatch_async(queue, ^{
        processDylibs();
    });
}

%end

%ctor {
    @autoreleasepool {
        // Make certain that hooks are installed only when loaded into SpringBoard.
        NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
        if ([identifier isEqualToString:@"com.apple.springboard"]) {
            if (IOS_GTE(6_0)) {
                %init();
            }
        }
    }
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
