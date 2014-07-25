TOOL_NAME = notifier
notifier_INSTALL_PATH = /Applications/CrashReporter.app
notifier_FILES = main.m
notifier_LDFLAGS = -lsymbolicate
notifier_PRIVATE_FRAMEWORKS = SpringBoardServices
notifier_CODESIGN_FLAGS="-SEntitlements.plist"

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/tool.mk
