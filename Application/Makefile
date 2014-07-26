APPLICATION_NAME = CrashReporter
CrashReporter_FILES = \
    ../Common/crashlog_util.m \
    ../Common/exec_as_root.m \
    ApplicationDelegate.m \
    ContactViewController.m \
    CrashLog.m \
    CrashLogGroup.m \
    CrashLogViewController.m \
    IncludeInstruction.m \
    Instruction.m \
    LinkInstruction.m \
    ManualScriptViewController.m \
    ModalActionSheet.m \
    NSString+CrashReporter.m \
    Package.m \
    RootViewController.m \
    SuspectsViewController.m \
    VictimViewController.m \
    common.c \
    main.m \
    pastie.m
CrashReporter_CFLAGS = -I../Libraries
CrashReporter_LDFLAGS = -llockdown -lsymbolicate
CrashReporter_FRAMEWORKS = MessageUI SystemConfiguration UIKit
CrashReporter_PRIVATE_FRAMEWORKS = Symbolication

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/application.mk

after-clean::
	- rm -rf $(THEOS_PROJECT_DIR)/Application/Common
