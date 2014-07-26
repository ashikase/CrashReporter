/**
 * Desc: Collection of misc. crash log related functions used by both
 *       CrashReporter app and notifier.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

@class CRCrashReport;

BOOL fileIsSymbolicated(NSString *filepath, CRCrashReport *report);
NSData *dataForFile(NSString *filepath);
BOOL deleteFile(NSString *filepath);
BOOL fixFileOwnership(NSString *filepath);
NSString *symbolicateFile(NSString *filepath, CRCrashReport *report);
BOOL writeToFile(NSString *string, NSString *outputFilepath);

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
