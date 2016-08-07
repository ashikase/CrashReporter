/**
 * Name: monitor
 * Type: iOS extension
 * Desc: Detects when ReportCrash writes a crash log file and launches
 *       notifier in order to send a local notification to the user.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#include <substrate.h>

#include "paths.h"

@interface NSTask : NSObject
+ (NSTask *)launchedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)arguments;
@end

static void launchNotifierWithPath(NSString *filepath) {
    // NOTE: Must be done via a separate binary as a certain entitlement
    //       is required for sending local notifications by proxy.
    NSString *launchPath = @"/Applications/CrashReporter.app/notifier_";
    if ([[NSFileManager defaultManager] isExecutableFileAtPath:launchPath]) {
        NSArray *arguments = [NSArray arrayWithObject:filepath];
        if ([NSTask launchedTaskWithLaunchPath:launchPath arguments:arguments] == nil) {
            NSLog(@"ERROR: Unable to launch notifier task.");
        }
    } else {
        NSLog(@"ERROR: notifier binary is missing or is not executable.");
    }
}

static BOOL crashLogFound$ = NO;
static BOOL crashLogWritten$ = NO;
static NSString *filepath$ = nil;
static int fd$ = -1;

static void cleanup() {
    [filepath$ release];
    filepath$ = nil;
}

static BOOL hasPrefix(const char *string, const char *suffix) {
    return (strncmp(string, suffix, strlen(suffix)) == 0);
}

static BOOL hasSuffix(const char *string, const char *suffix) {
    if ((string != NULL) && (suffix != NULL)) {
        size_t lenString = strlen(string);
        size_t lenSuffix = strlen(suffix);
        if (lenSuffix <= lenString) {
            return (strncmp(string + lenString - lenSuffix, suffix, lenSuffix) == 0);
        }
    }

    return NO;
}

// NOTE: Third parameter is technically variadic (...), but the only time when
//       more than two parameters are passed is when oflag includes O_CREAT,
//       in which case three parameters are passed (the third being mode_t).
int (*_open)(const char *, int, mode_t) = NULL;
int $open(const char *path, int oflag, mode_t mode) {
    int fd = _open(path, oflag, mode);
    if (fd >= 0) {
        if (!crashLogFound$) {
            if ((hasPrefix(path, kCrashLogDirectoryForMobile) || hasPrefix(path, kCrashLogDirectoryForRoot)) &&
                    (hasSuffix(path, "plist") || hasSuffix(path, "ips"))) {
                crashLogFound$ = YES;
                filepath$ = [[NSString alloc] initWithCString:path encoding:NSUTF8StringEncoding];
                fd$ = fd;
            }
        }
    }
    return fd;
}

ssize_t (*_write)(int, const void *, size_t) = NULL;
ssize_t $write(int fildes, const void *buf, size_t nbyte) {
    ssize_t bytesWritten = _write(fildes, buf, nbyte);
    if ((fd$ != -1) && (fd$ == fildes)) {
        if (bytesWritten == nbyte) {
            crashLogWritten$ = YES;
        }
    }
    return bytesWritten;
}

int (*_close)(int) = NULL;
int $close(int fildes) {
    int result = _close(fildes);
    if ((fd$ != -1) && (fd$ == fildes)) {
        if (result != -1) {
            // NOTE: Must reset file descriptor befoure launching task.
            //       Failure to do so results in infinite recursion of the
            //       close() method (for a yet unresearched reason).
            fd$ = -1;

            // NOTE: As of iOS 9.3, ReportCrash (CrashReporterSupport) writes
            //       the log file to a temporary file, which is then renamed
            //       at a later point.
            if (IOS_LT(9_3)) {
                if (crashLogWritten$) {
                    launchNotifierWithPath(filepath$);
                }
                cleanup();
            }
        }
    }
    return result;
}

%hook NSFileManager %group GFirmware_GTE_93

- (BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError * _Nullable *)error {
    BOOL moved = %orig();

    if ([[srcURL path] isEqualToString:filepath$]) {
        if (moved) {
            launchNotifierWithPath([dstURL path]);
        }
        cleanup();
    }

    return moved;
}

%end %end

__attribute__((constructor)) static void init() {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    // Lookup and hook symbol.
    // NOTE: The dynamic lookup is not necessary, but better safe than sorry.
    void *handle = dlopen("/usr/lib/system/libsystem_kernel.dylib", (RTLD_LAZY | RTLD_NOLOAD));
    if (handle != NULL) {
        int (*openPtr)(const char *, int, mode_t) = reinterpret_cast<int (*)(const char *, int, mode_t)>(dlsym(handle, "open"));
        if (openPtr != NULL) {
            MSHookFunction(openPtr, &$open, &_open);
        }
        ssize_t (*writePtr)(int, const void *, size_t) = reinterpret_cast<ssize_t  (*)(int, const void *, size_t)>(dlsym(handle, "write"));
        if (writePtr != NULL) {
            MSHookFunction(writePtr, &$write, &_write);
        }
        int (*closePtr)(int) = reinterpret_cast<int (*)(int)>(dlsym(handle, "close"));
        if (closePtr != NULL) {
            MSHookFunction(closePtr, &$close, &_close);
        }

        if ((openPtr == NULL) || (writePtr == NULL) || (closePtr == NULL)) {
            fprintf(stderr, "ERROR: Was unable to find symbols for required functions.\n");
        }

        dlclose(handle);
    }

    if (IOS_GTE(9_3)) {
        %init(GFirmware_GTE_93);
    }

    [pool release];
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
