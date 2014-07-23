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

#ifndef CR_MOVE_AS_ROOT_H
#define CR_MOVE_AS_ROOT_H

BOOL move_as_root(const char *from_filepath, const char *to_filepath);
BOOL delete_as_root(const char *filepath);

#endif

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
