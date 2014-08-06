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

#import "PackageCache.h"

#import <TechSupport/TechSupport.h>

@implementation PackageCache {
    NSMutableDictionary *cache_;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (id)init {
    self = [super init];
    if (self != nil) {
        cache_ = [NSMutableDictionary new];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning)
            name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [cache_ release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    [cache_ removeAllObjects];
}

- (TSPackage *)packageForFile:(NSString *)filepath {
    TSPackage *package = [cache_ objectForKey:filepath];
    if (package == nil) {
        package = [TSPackage packageForFile:filepath];
        if (package != nil) {
            [cache_ setObject:package forKey:filepath];
        }
    }
    return package;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */
