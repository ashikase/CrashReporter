APPLICATION_NAME = CrashReporter
CrashReporter_FILES = \
    $(THEOS_PROJECT_DIR)/Libraries/RegexKitLite/RegexKitLite.m \
    $(THEOS_PROJECT_DIR)/common/crashlog_util.m \
    $(THEOS_PROJECT_DIR)/common/exec_as_root.m \
    ApplicationDelegate.m \
    BinaryImageCell.m \
	Button.m \
    CrashLog.m \
    CrashLogGroup.m \
    ModalActionSheet.m \
    PackageCache.m \
    RootViewController.m \
    ScriptViewController.m \
    SuspectsViewController.m \
    UIImage+CrashReporter.m \
    VictimViewController.m \
    main.m \
    pastie.m
CrashReporter_CFLAGS = -F$(THEOS)/Frameworks -I$(THEOS_PROJECT_DIR)/Libraries
CrashReporter_LDFLAGS = -F$(THEOS)/Frameworks
CrashReporter_LIBRARIES = crashreport icucore packageinfo
CrashReporter_FRAMEWORKS = CoreGraphics MessageUI SystemConfiguration TechSupport UIKit

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/application.mk

after-clean::
	- rm -rf $(THEOS_PROJECT_DIR)/Application/Common
	- rm -rf $(THEOS_PROJECT_DIR)/Application/common
