TOOL_NAME = symbolicate
symbolicate_INSTALL_PATH = /usr/bin
symbolicate_OBJC_FILES = \
    ../Common/common.c \
    ../Common/RegexKitLite.m \
    main.m \
    symbolicate.m
symbolicate_CFLAGS = -I ../Common
symbolicate_LDFLAGS = -licucore
symbolicate_PRIVATE_FRAMEWORKS = Symbolication

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tool.mk
