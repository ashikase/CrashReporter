TECHSUPPORT_FRAMEWORK = $(THEOS_PROJECT_DIR)/Frameworks/TechSupport/_/Library/Frameworks

APPLICATION_NAME = CrashReporter
CrashReporter_FILES = \
    ../Common/crashlog_util.m \
    ../Common/exec_as_root.m \
    ApplicationDelegate.m \
    CrashLog.m \
    CrashLogGroup.m \
    ManualScriptViewController.m \
    ModalActionSheet.m \
    RootViewController.m \
    SuspectsViewController.m \
    VictimViewController.m \
    common.c \
    main.m \
    pastie.m
CrashReporter_CFLAGS = -F$(TECHSUPPORT_FRAMEWORK) -I$(THEOS_PROJECT_DIR)/Libraries
CrashReporter_LDFLAGS = -llockdown -lsymbolicate -F$(TECHSUPPORT_FRAMEWORK) -framework TechSupport
CrashReporter_FRAMEWORKS = MessageUI SystemConfiguration UIKit
CrashReporter_PRIVATE_FRAMEWORKS = Symbolication

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/application.mk

after-clean::
	- rm -rf $(THEOS_PROJECT_DIR)/Application/Common
