/**
 * Desc: Collection of misc. crash log related functions used by both
 *       CrashReporter app and notifier.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import "crashlog_util.h"

#import <libcrashreport/libcrashreport.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "exec_as_root.h"

static const char * const kTemporaryFilepath = "/tmp/CrashReporter.temp.XXXXXX";

BOOL fileIsSymbolicated(NSString *filepath, CRCrashReport *report) {
    BOOL isSymbolicated = NO;

    // NOTE: Marking and checking for symbolication status via a filename is
    //       not the best method; however, the filename is checked first
    //       because:
    //       * It allows checking without having to load the crash log file.
    //       * Earlier versions of libsymbolicate did not include the
    //         "symbolicated" property.
    // XXX: Checking the filename may lead to incorrectly marking a file as
    //      symbolicated if the name of the crashed process includes the text
    //      ".symbolicated.". The chance of such a process existing, though, is
    //      considered to be low enough that code for this has not been added.
    NSString *pathExtension = nil;
    do {
        // NOTE: This assumes that symbolicated files have a specific extension,
        //       which may not be the case if the file was symbolicated by a
        //       tool other than CrashReporter.
        pathExtension = [filepath pathExtension];
        if ([pathExtension isEqualToString:@"symbolicated"]) {
            isSymbolicated = YES;
            break;
        }
        filepath = [filepath stringByDeletingPathExtension];
    } while ([pathExtension length] > 0);

    if (!isSymbolicated) {
        // Load crash report if necessary.
        BOOL needsRelease = NO;
        if (report == nil) {
            // Get data for crash log file.
            NSData *data = dataForFile(filepath);
            if (data != nil) {
                // Load crash report.
                report = [[CRCrashReport alloc] initWithData:data filterType:CRCrashReportFilterTypePackage];
                if (report != nil) {
                    needsRelease = YES;
                }
            }
        }

        // Check for "symbolicated" key.
        isSymbolicated = [report isSymbolicated];

        // Cleanup.
        if (needsRelease) {
            [report release];
        }
    }

    return isSymbolicated;
}

NSData *dataForFile(NSString *filepath) {
    NSData *data = nil;

    // If filepath is not readable, copy to temporary file.
    NSString *tempFilepath = nil;
    NSFileManager *fileMan = [NSFileManager defaultManager];
    if (![fileMan isReadableFileAtPath:filepath]) {
        // Copy file to temporary file.
        char path[strlen(kTemporaryFilepath) + 1 ];
        memcpy(path, kTemporaryFilepath, sizeof(path));
        if (mktemp(path) == NULL) {
            fprintf(stderr, "ERROR: Unable to create temporary filepath.\n");
            return nil;
        }

        if (!copy_as_root([filepath UTF8String], path)) {
            fprintf(stderr, "ERROR: Failed to move file to temorary filepath.\n");
            return nil;
        }

        tempFilepath = [[NSString alloc] initWithCString:path encoding:NSUTF8StringEncoding];
    }

    // Load file data.
    NSError *error = nil;
    data = [[NSData alloc] initWithContentsOfFile:(tempFilepath ?: filepath) options:0 error:&error];
    if (data == nil) {
        fprintf(stderr, "ERROR: Unable to load data from \"%s\": \"%s\".\n",
                [(tempFilepath ?: filepath) UTF8String], [[error localizedDescription] UTF8String]);
    }

    // Delete temporary file, if necessary.
    if (tempFilepath != nil) {
        deleteFile(tempFilepath);
        [tempFilepath release];
    }

    return data;
}

BOOL deleteFile(NSString *filepath) {
    BOOL didDelete = YES;

    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:filepath error:&error]) {
        // Try again using as_root tool.
        if (!delete_as_root([filepath UTF8String])) {
            fprintf(stderr, "WARNING: Unable to delete file \"%s\": \"%s\".\n",
                    [filepath UTF8String], [[error localizedDescription] UTF8String]);
            didDelete = NO;
        }
    }

    return didDelete;
}

BOOL fixFileOwnershipAndPermissions(NSString *filepath) {
    BOOL didFix = NO;

    // Determine ownership of containing directory.
    NSString *directory = [filepath stringByDeletingLastPathComponent];
    NSError *error = nil;
    NSDictionary *attrib = [[NSFileManager defaultManager] attributesOfItemAtPath:directory error:&error];
    if (attrib != nil) {
        // Determine owner of filepath.
        BOOL isMobile = [[attrib fileOwnerAccountName] isEqualToString:@"mobile"];

        // Apply same ownership to the filepath.
        const char *path = [filepath UTF8String];
        uid_t owner = isMobile ? 501 : 0;
        gid_t group = owner;

        if (lchown(path, owner, group) != 0) {
            // Try again using as_root tool.
            if (!chown_as_root(path, owner, group)) {
                fprintf(stderr, "WARNING: Failed to change ownership of file: %s, errno = %d.\n", path, errno);
            }
        }

        // Update permissions using known values.
        mode_t mode = isMobile ? 0644 : 0640;
        if (chmod(path, mode) != 0) {
            // Try again using as_root tool.
            if (!chmod_as_root(path, mode)) {
                fprintf(stderr, "WARNING: Failed to change mode of file: %s, errno = %d.\n", path, errno);
            }
        }
    } else {
        fprintf(stderr, "ERROR: Unable to determine attributes for file: %s, %s.\n",
            [filepath UTF8String], [[error localizedDescription] UTF8String]);
    }

    return didFix;
}

static void replaceSymbolicLink(NSString *linkPath, NSString *oldDestPath, NSString *newDestPath) {
    // NOTE: Must check the destination of the links, as the links may have
    //       been updated since this tool began executing.
    NSFileManager *fileMan = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString *destPath = [fileMan destinationOfSymbolicLinkAtPath:linkPath error:&error];
    if (destPath != nil) {
        if ([destPath isEqualToString:oldDestPath]) {
            // Remove old link.
            if (deleteFile(linkPath)) {
                // Create new link.
                if ([fileMan createSymbolicLinkAtPath:linkPath withDestinationPath:newDestPath error:&error]) {
                    fixFileOwnershipAndPermissions(linkPath);
                } else {
                    fprintf(stderr, "ERROR: Failed to create \"%s\" symbolic link: %s.\n",
                        [[linkPath lastPathComponent] UTF8String], [[error localizedDescription] UTF8String]);
                }
            }
        }
    } else {
        fprintf(stderr, "ERROR: Failed to determine destination of \"%s\" symbolic link: %s.\n",
            [[linkPath lastPathComponent] UTF8String], [[error localizedDescription] UTF8String]);
    }
}

NSString *symbolicateFile(NSString *filepath, CRCrashReport *report) {
    NSString *outputFilepath = nil;

    // Load crash report if necessary.
    BOOL needsRelease = NO;
    if (report == nil) {
        // Get data for crash log file.
        NSData *data = dataForFile(filepath);
        if (data != nil) {
            // Load crash report.
            report = [[CRCrashReport alloc] initWithData:data filterType:CRCrashReportFilterTypePackage];
            if (report != nil) {
                needsRelease = YES;
            }
        }
    }

    // Symbolicate.
    if (!fileIsSymbolicated(filepath, report)) {
        if ([report symbolicate]) {
            // Process blame.
            // NOTE: The below plist is included in the "symbolicate" package.
            NSString *filtersFilepath = @"/etc/symbolicate/blame_filters.plist";
            if (![[NSFileManager defaultManager] isReadableFileAtPath:filtersFilepath]) {
                // Use bundled list of filters.
                filtersFilepath = [[NSBundle mainBundle] pathForResource:@"blame_filters" ofType:@"plist"];
            }
            NSDictionary *filters = [[NSDictionary alloc] initWithContentsOfFile:filtersFilepath];
            if ([report blameUsingFilters:filters]) {
                // Write output to file.
                NSString *pathExtension = [filepath pathExtension];
                NSString *path = [NSString stringWithFormat:@"%@.symbolicated.%@",
                        [filepath stringByDeletingPathExtension], pathExtension];
                if (writeToFile([report stringRepresentation], path)) {
                    // Fix any "LatestCrash-*" symbolic links for this file.
                    NSString *oldDestPath = [filepath lastPathComponent];
                    NSString *newDestPath = [path lastPathComponent];
                    NSString *linkPath;
                    linkPath = [NSString stringWithFormat:@"%@/LatestCrash.%@",
                        [filepath stringByDeletingLastPathComponent], pathExtension];
                    replaceSymbolicLink(linkPath, oldDestPath, newDestPath);

                    NSString *processName = [[report properties] objectForKey:@"name"];
                    linkPath = [NSString stringWithFormat:@"%@/LatestCrash-%@.%@",
                        [filepath stringByDeletingLastPathComponent], processName, pathExtension];
                    replaceSymbolicLink(linkPath, oldDestPath, newDestPath);

                    // Delete the original (non-symbolicated) crash log file.
                    if (!deleteFile(filepath)) {
                        fprintf(stderr, "WARNING: Failed to delete original log file \"%s\".\n", [filepath UTF8String]);
                    }

                    // Update file ownership and permissions.
                    fixFileOwnershipAndPermissions(path);

                    // Save write path.
                    outputFilepath = path;
                }
            } else {
                fprintf(stderr, "ERROR: Failed to process blame.\n");
            }
            [filters release];
        } else {
            fprintf(stderr, "ERROR: Unable to symbolicate file \"%s\"\n.", [filepath UTF8String]);
        }
    } else {
        // Already symbolicated.
        outputFilepath = filepath;
    }

    // Cleanup.
    if (needsRelease) {
        [report release];
    }

    return outputFilepath;
}

NSString *syslogPathForFile(NSString *filepath) {
    NSString *syslogPath = filepath;

    // Strip known path extensions.
    NSString *pathExtension = [syslogPath pathExtension];
    while (
            [pathExtension isEqualToString:@"ips"] ||
            [pathExtension isEqualToString:@"plist"] ||
            [pathExtension isEqualToString:@"symbolicated"] ||
            [pathExtension isEqualToString:@"synced"]
          ) {
        syslogPath = [syslogPath stringByDeletingPathExtension];
        pathExtension = [syslogPath pathExtension];
    }

    return [syslogPath stringByAppendingPathExtension:@"syslog"];
}

BOOL writeToFile(NSString *string, NSString *outputFilepath) {
    BOOL didWrite = NO;

    NSString *outputDirectory = [outputFilepath stringByDeletingLastPathComponent];
    NSFileManager *fileMan = [NSFileManager defaultManager];

    // If filepath is not writable, will write to temporary file.
    NSString *tempFilepath = nil;
    if (![fileMan isWritableFileAtPath:outputDirectory]) {
        // Copy file to temporary file.
        char path[strlen(kTemporaryFilepath) + 1 ];
        memcpy(path, kTemporaryFilepath, sizeof(path));
        if (mktemp(path) == NULL) {
            fprintf(stderr, "ERROR: Unable to create temporary filepath.\n");
            return NO;
        }
        tempFilepath = [[NSString alloc] initWithCString:path encoding:NSUTF8StringEncoding];
    }

    // Write to file.
    NSError *error = nil;
    if ([string writeToFile:(tempFilepath ?: outputFilepath) atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        // Delete temporary file, if necessary.
        if (tempFilepath != nil) {
            // Move symbolicated file to actual directory.
            if (!move_as_root([tempFilepath UTF8String], [outputFilepath UTF8String])) {
                fprintf(stderr, "ERROR: Failed to move symbolicated log file back to original directory.\n");
                goto exit;
            }
        }

        // Note that write succeeded.
        didWrite = YES;
    } else {
        fprintf(stderr, "ERROR: Unable to write to file \"%s\": %s.\n",
                [(tempFilepath ?: outputFilepath) UTF8String], [[error localizedDescription] UTF8String]);
    }

exit:
    [tempFilepath release];
    return didWrite;
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
