/**
 * Desc: Collection of utility functions for calling as_root command line tool.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#include "exec_as_root.h"

static char as_root_path$[64];

static const char *as_root_path() {
    if (as_root_path$[0] == '\0') {
        [[[NSBundle mainBundle] pathForResource:@"as_root" ofType:nil]
            getCString:as_root_path$ maxLength:sizeof(as_root_path$)
            encoding:NSUTF8StringEncoding];
    }
    return as_root_path$;
}

static BOOL as_root(const char *action, const char *param1, const char *param2, const char *param3) {
    BOOL succeeded = NO;

    pid_t pid = fork();
    const char *path = as_root_path();
    if (pid == 0) {
        // Execute the process.
        if (strcmp(action, "chown") == 0) {
            execl(path, path, action, param1, param2, param3, NULL);
        } else if ((strcmp(action, "chmod") == 0) || (strcmp(action, "copy") == 0) || (strcmp(action, "move") == 0)) {
            execl(path, path, action, param1, param2, NULL);
        } else if (strcmp(action, "delete") == 0) {
            execl(path, path, action, param1, NULL);
        }
        _exit(0);
    } else if (pid != -1) {
        // Wait for process to finish.
        int stat_loc;
        waitpid(pid, &stat_loc, 0);

        // Check the exit status to determine if the operation was successful.
        if (WIFEXITED(stat_loc)) {
            if (WEXITSTATUS(stat_loc) == 0) {
                succeeded = YES;
            }
        }
    }

    return succeeded;
}

BOOL chmod_as_root(const char *filepath, mode_t mode) {
    char mode_buf[5];
    snprintf(mode_buf, 5, "%o", mode);
    return as_root("chmod", filepath, mode_buf, NULL);
}

BOOL chown_as_root(const char *filepath, uid_t owner, gid_t group) {
    char owner_buf[17];
    char group_buf[17];
    snprintf(owner_buf, 17, "%u", owner);
    snprintf(group_buf, 17, "%u", owner);
    return as_root("chown", filepath, owner_buf, group_buf);
}

BOOL copy_as_root(const char *from_filepath, const char *to_filepath) {
    return as_root("copy", from_filepath, to_filepath, NULL);
}

BOOL delete_as_root(const char *filepath) {
    return as_root("delete", filepath, NULL, NULL);
}

BOOL move_as_root(const char *from_filepath, const char *to_filepath) {
    return as_root("move", from_filepath, to_filepath, NULL);
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
