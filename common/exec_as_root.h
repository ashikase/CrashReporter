/**
 * Desc: Collection of utility functions for calling as_root command line tool.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

BOOL chmod_as_root(const char *filepath, mode_t mode);
BOOL chown_as_root(const char *filepath, uid_t owner, gid_t group);
BOOL copy_as_root(const char *from_filepath, const char *to_filepath);
BOOL delete_as_root(const char *filepath);
BOOL move_as_root(const char *from_filepath, const char *to_filepath);

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
