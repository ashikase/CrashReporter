@interface NSTask : NSObject
+ (NSTask *)launchedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)arguments;
@end

%hook NSFileManager

- (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error {
    NSString *filename = [path lastPathComponent];
    if ([filename hasPrefix:@"LatestCrash-"]) {
        NSString *launchPath = @"/Applications/CrashReporter.app/notifier";
        NSArray *arguments = [NSArray arrayWithObject:destPath];
        [NSTask launchedTaskWithLaunchPath:launchPath arguments:arguments];
    }
    return %orig();
}

%end

