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

static char as_root_path$[64];

static const char *as_root_path() {
    if (as_root_path$[0] == '\0') {
        [[[NSBundle mainBundle] pathForResource:@"as_root" ofType:nil]
            getCString:as_root_path$ maxLength:sizeof(as_root_path$)
            encoding:NSUTF8StringEncoding];
    }
    return as_root_path$;
}

static BOOL as_root(const char *action, const char *filepath1, const char *filepath2) {
    BOOL succeeded = NO;

    pid_t pid = fork();
    const char *path = as_root_path();
    if (pid == 0) {
        // Execute the process.
        if ((strcmp(action, "copy") == 0) || (strcmp(action, "move") == 0)) {
            execl(path, path, action, filepath1, filepath2, NULL);
        } else if (strcmp(action, "delete") == 0) {
            execl(path, path, action, filepath1, NULL);
        }
        _exit(0);
    } else if (pid != -1) {
        // Wait for process to finish.
        int stat_loc;
        waitpid(pid, &stat_loc, 0);

        // Check the exit status to determine if the operation was successful.
        if (WIFEXITED(stat_loc)) {
            printf("%d", WEXITSTATUS(stat_loc));
            if (WEXITSTATUS(stat_loc) == 0) {
                succeeded = YES;
            }
        }
    }

    return succeeded;
}

BOOL copy_as_root(const char *from_filepath, const char *to_filepath) {
    return as_root("copy", from_filepath, to_filepath);
}

BOOL move_as_root(const char *from_filepath, const char *to_filepath) {
    return as_root("move", from_filepath, to_filepath);
}

BOOL delete_as_root(const char *filepath) {
    return as_root("delete", filepath, NULL);
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
