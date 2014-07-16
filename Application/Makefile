APPLICATION_NAME = CrashReporter
CrashReporter_FILES = \
    ../Libraries/RegexKitLite/RegexKitLite.m \
    ApplicationDelegate.m \
    ContactViewController.m \
    CrashLog.m \
    CrashLogDirectoryReader.m \
    CrashLogGroup.m \
    CrashLogViewController.m \
    CustomBlameController.m \
    IncludeInstruction.m \
    Instruction.m \
    LinkInstruction.m \
    ModalActionSheet.m \
    NSString+CrashReporter.m \
    Package.m \
    RootViewController.m \
    SuspectsViewController.m \
    VictimViewController.m \
    common.c \
    main.m \
    move_as_root.m \
    pastie.m
CrashReporter_CFLAGS = -I../Libraries
CrashReporter_LDFLAGS = -licucore -lsymbolicate
CrashReporter_FRAMEWORKS = MessageUI SystemConfiguration UIKit
CrashReporter_PRIVATE_FRAMEWORKS = Symbolication

include $(THEOS_MAKE_PATH)/common.mk
include $(THEOS_MAKE_PATH)/application.mk
