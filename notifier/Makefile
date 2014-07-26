TOOL_NAME = notifier
notifier_INSTALL_PATH = /Applications/CrashReporter.app
notifier_FILES = \
    ../Common/crashlog_util.m \
    ../Common/exec_as_root.m \
    main.m
notifier_LDFLAGS = -lsymbolicate
notifier_PRIVATE_FRAMEWORKS = SpringBoardServices
notifier_CODESIGN_FLAGS="-SEntitlements.plist"

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/tool.mk

after-clean::
	- rm -rf $(THEOS_PROJECT_DIR)/notifier/Common
