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

#import <UIKit/UIKit.h>

int main (int argc, char *argv[]) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int ret = UIApplicationMain(argc, argv, nil, @"ApplicationDelegate");
    [pool drain];
    return ret;
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
