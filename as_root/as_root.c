/**
 * Name: as_root
 * Type: iOS command line tool
 * Desc: Tool for moving and deleting specific sets of files as root.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

const char * const kLogPath = "/Library/Logs/CrashReporter/";
const char * const kTempPath = "/tmp/";

static void print_usage() {
    fprintf(stderr,
            "Usage: as_root copy <from_filepath> <to_filepath>\n"
            "       as_root move <from_filepath> <to_filepath>\n"
            "       as_root delete <filepath>\n"
            "\n"
            "       Note that only filepaths with the following prefixes are permitted:\n"
            "       * \"%s\"\n"
            "       * \"%s\"\n",
            kLogPath, kTempPath
           );
}

int is_valid_filepath(const char *filepath) {
    return
        (strncmp(filepath, kLogPath, strlen(kLogPath)) == 0) ||
        (strncmp(filepath, kTempPath, strlen(kTempPath)) == 0);
}

int main(int argc, const char *argv[]) {
    // Run as root.
    if (setuid(geteuid()) != 0) {
        fprintf(stderr, "ERROR: Unable to assume root powers, errno = %d.\n", errno);
        return EXIT_FAILURE;
    }

    if ((argc == 4) && (strcasecmp(argv[1], "copy") == 0)) {
        // Check files at filepaths.
        if (!is_valid_filepath(argv[2]) || !is_valid_filepath(argv[3])) {
            fprintf(stderr, "ERROR: At least one of the specified filepaths is not allowed.\n");
            return EXIT_FAILURE;
        }

        // Copy from_filepath to to_filepath.
        char buffer[BUFSIZ];
        size_t nitems;
        FILE *from_file = fopen(argv[2], "r");;
        if (from_file != NULL) {
            FILE *to_file = fopen(argv[3], "w");;
            if (to_file != NULL) {
                while ((nitems = fread(buffer, sizeof(char), sizeof(buffer), from_file)) > 0) {
                    if (fwrite(buffer, sizeof(char), nitems, to_file) != nitems) {
                        fprintf(stderr, "ERROR: Failure while copying file, errno = %d.\n", errno);
                        return EXIT_FAILURE;
                    }
                }
                fclose(to_file);
            } else {
                fprintf(stderr, "ERROR: Unable to open destination filepath for writing, errno = %d.\n", errno);
            }
            fclose(from_file);
        } else {
            fprintf(stderr, "ERROR: Unable to open source filepath for reading, errno = %d.\n", errno);
        }
    } else if ((argc == 4) && (strcasecmp(argv[1], "move") == 0)) {
        // Check files at filepaths.
        if (!is_valid_filepath(argv[2]) || !is_valid_filepath(argv[3])) {
            fprintf(stderr, "ERROR: At least one of the specified filepaths is not allowed.\n");
            return EXIT_FAILURE;
        }

        // Move from_filepath to to_filepath.
        if (strcmp(argv[1], argv[2]) != 0) {
            if (rename(argv[1], argv[2]) != 0) {
                fprintf(stderr, "ERROR: Failed to rename file, errno = %d.\n", errno);
                return EXIT_FAILURE;
            }
        }
    } else if ((argc == 3) && (strcasecmp(argv[1], "delete") == 0)) {
        // Check file at filepath.
        if (!is_valid_filepath(argv[2])) {
            fprintf(stderr, "ERROR: Specified filepath is not allowed.\n");
            return EXIT_FAILURE;
        }

        // Delete file at filepath.
        if (unlink(argv[2]) != 0) {
            fprintf(stderr, "ERROR: Failed to delete file, errno = %d.\n", errno);
            return EXIT_FAILURE;
        }
    } else {
        print_usage();
    }

    return EXIT_SUCCESS;
}
