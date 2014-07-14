APPLICATION_NAME = CrashReporter
CrashReporter_FILES = \
    ../Libraries/RegexKitLite/RegexKitLite.m \
    ApplicationDelegate.m \
    BlameController.m \
    CrashLogDirectoryReader.m \
    CrashLog.m \
    CrashLogGroup.m \
    CrashLogViewController.m \
    CustomBlameController.m \
    ModalActionSheet.m \
    NSString+CrashReporter.m \
    DenyReporterLine.m \
    IncludeReporterLine.m \
    LinkReporterLine.m \
    ReporterLine.m \
    RootViewController.m \
    SuspectsViewController.m \
    VictimViewController.m \
    common.c \
    move_as_root.m \
    find_dpkg.m \
    main.m \
    pastie.m
CrashReporter_CFLAGS = -I../Libraries
CrashReporter_LDFLAGS = -licucore -lsymbolicate
CrashReporter_FRAMEWORKS = MessageUI SystemConfiguration UIKit
CrashReporter_PRIVATE_FRAMEWORKS = Symbolication

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/application.mk
