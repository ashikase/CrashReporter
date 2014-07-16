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

#ifndef CR_COMMON_H
#define CR_COMMON_H

unsigned char nibble(char c);

int convertStringToInteger(const char* str, int len);
unsigned long long convertHexStringToLongLong(const char* str, int len);

#endif

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
