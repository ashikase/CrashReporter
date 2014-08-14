TECHSUPPORT_FRAMEWORK = $(THEOS_PROJECT_DIR)/Frameworks/TechSupport/_/Library/Frameworks

APPLICATION_NAME = CrashReporter
CrashReporter_FILES = \
    ../common/crashlog_util.m \
    ../common/exec_as_root.m \
    ApplicationDelegate.m \
    CrashLog.m \
    CrashLogGroup.m \
    ManualScriptViewController.m \
    ModalActionSheet.m \
    PackageCache.m \
    RootViewController.m \
    SuspectsViewController.m \
    UIImage+CrashReporter.m \
    VictimViewController.m \
    main.m \
    pastie.m
CrashReporter_CFLAGS = -F$(TECHSUPPORT_FRAMEWORK) -I$(THEOS_PROJECT_DIR)/Libraries
CrashReporter_LDFLAGS = -lcrashreport -F$(TECHSUPPORT_FRAMEWORK) -framework TechSupport
CrashReporter_FRAMEWORKS = CoreGraphics MessageUI SystemConfiguration UIKit

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/application.mk

after-clean::
	- rm -rf $(THEOS_PROJECT_DIR)/Application/Common
	- rm -rf $(THEOS_PROJECT_DIR)/Application/common
