/**
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#include <dlfcn.h>
#include <sys/sysctl.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

extern CFStringRef kLockdownUniqueDeviceIDKey;
typedef void* LockdownConnectionRef;
extern LockdownConnectionRef lockdown_connect();
extern void lockdown_disconnect(LockdownConnectionRef connection);
extern CFPropertyListRef lockdown_copy_value(LockdownConnectionRef connection, CFStringRef domain, CFStringRef key);

extern CFPropertyListRef MGCopyAnswer(CFStringRef property);

#ifdef __cplusplus
}  // extern "C"
#endif

static inline NSString *platformVersion() {
    NSString *ret = nil;
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *system = (char *)malloc(size * sizeof(char));
    if (sysctlbyname("hw.machine", system, &size, NULL, 0) != -1) {
        ret = [NSString stringWithCString:system encoding:NSASCIIStringEncoding];
        free(system);
    }
    return ret;
}

static inline NSString *uniqueId() {
    NSString *ret = nil;

    CFPropertyListRef value = NULL;
    if (IOS_LT(4_2)) {
        LockdownConnectionRef lockdown = lockdown_connect();
        if (lockdown != NULL) {
            value = (CFStringRef)lockdown_copy_value(lockdown, NULL, kLockdownUniqueDeviceIDKey);
            lockdown_disconnect(lockdown);
        }
    } else {
        // NOTE: Can't link to dylib as it doesn't exist in older iOS versions.
        void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
        if (handle != NULL) {
            CFPropertyListRef (*MGCopyAnswer)(CFStringRef) = (CFPropertyListRef (*)(CFStringRef))dlsym(handle, "MGCopyAnswer");
            if (MGCopyAnswer != NULL) {
                value = MGCopyAnswer(CFSTR("UniqueDeviceID"));
            }
            dlclose(handle);
        }
    }

    if (value != NULL) {
        if (CFGetTypeID(value) == CFStringGetTypeID()) {
            ret = [NSString stringWithString:(NSString *)value];
        }
        CFRelease(value);
    }

    return ret;
}

/* vim: set ft=c ff=unix sw=4 ts=4 expandtab tw=80: */
