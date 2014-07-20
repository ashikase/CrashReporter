@interface NSTask : NSObject
+ (NSTask *)launchedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)arguments;
@end

%hook NSFileManager

- (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error {
    NSString *filename = [path lastPathComponent];
    if ([filename hasPrefix:@"LatestCrash-"]) {
        // Generate full path of actual file.
        NSString *filepath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:destPath];

        // Launch notifier.
        // NOTE: Must be done via a separate binary as a certain entitlement
        //       is required for sending local notifications by proxy.
        NSString *launchPath = @"/Applications/CrashReporter.app/notifier";
        NSArray *arguments = [NSArray arrayWithObject:filepath];
        [NSTask launchedTaskWithLaunchPath:launchPath arguments:arguments];
    }
    return %orig();
}

%end

