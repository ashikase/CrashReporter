APPLICATION_NAME = CrashReporter
CrashReporter_FILES = \
    ../Common/common.c \
    ../Common/RegexKitLite.m \
    ../symbolicate/symbolicate.m \
    BlameController.m \
    CrashLogDateChooser.m \
    CrashLogViewController.m \
    CrashLogsFolderReader.m \
    CrashLogsTableController.m \
    CrashReporterDelegate.m \
    CustomBlameController.m \
    ModalActionSheet.m \
    SuspectsViewController.m \
    find_dpkg.m \
    main.m \
    pastie.m \
    reporter.m
CrashReporter_CFLAGS = -I ../Common -I ../symbolicate
CrashReporter_LDFLAGS = -licucore
CrashReporter_FRAMEWORKS = MessageUI SystemConfiguration UIKit
CrashReporter_PRIVATE_FRAMEWORKS = Symbolication

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/application.mk
