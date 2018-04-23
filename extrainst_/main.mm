/**
 * Copyright © 2018  Lance Fetters (a.k.a. ashikase)
 */

int main(int argc, char *argv[], char *envp[]) {
    @autoreleasepool {
        // NOTE: In iOS 11 jailbroken via Electra, CrashReporter cannot be
        //       launched via the "CrashReporter_" safe mode script.
        // NOTE: This is believed to also be true for all current jailbreaks
        //       for 10.3, though is untested due to lack of a 10.3 device.
        if (IOS_GTE(10_3)) {
            NSBundle *bundle = [NSBundle bundleWithPath:@"/Applications/CrashReporter.app"];
            if (bundle == nil) {
                fprintf(stderr, "ERROR: App bundle not found.\n");
                return 1;
            }

            NSURL *url = [bundle URLForResource:@"Info" withExtension:@"plist"];
            if (url == nil) {
                fprintf(stderr, "ERROR: Info.plist not found.\n");
                return 1;
            }

            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfURL:url];
            if (dict == nil) {
                fprintf(stderr, "ERROR: Unable to load contents of Info.plist.\n");
                return 1;
            }

            dict[@"CFBundleExecutable"] = @"CrashReporter";

            if (![dict writeToURL:url atomically:YES]) {
                fprintf(stderr, "ERROR: Failed to write updated Info.plist.\n");
                return 1;
            }
        }
    }

    return 0;
}

/* vim: set ft=logos ff=unix sw=4 ts=4 tw=80 expandtab: */
