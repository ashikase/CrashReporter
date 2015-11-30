SUBPROJECTS = Application as_root monitor notifier scanner
PKG_ID = crash-reporter

export ARCHS = armv6 arm64
export SDKVERSION = 7.1
export TARGET = iphone:clang
export TARGET_IPHONEOS_DEPLOYMENT_VERSION = 3.0

export ADDITIONAL_CFLAGS += -I$(THEOS_PROJECT_DIR)/common  -I$(THEOS_PROJECT_DIR)/Libraries/Common -include firmware.h
export ADDITIONAL_LDFLAGS = -L$(THEOS)/lib/arm

include theos/makefiles/common.mk
include theos/makefiles/aggregate.mk

after-stage::
	# Give as_root the power of root in order to move/delete root-owned files.
	- chmod u+s $(THEOS_STAGING_DIR)/Applications/CrashReporter.app/as_root
	# Copy localization files.
	- cp -a $(THEOS_PROJECT_DIR)/Localization/CrashReporter/Application/*.lproj $(THEOS_STAGING_DIR)/Applications/CrashReporter.app/
	- cp -a $(THEOS_PROJECT_DIR)/Localization/CrashReporter/Preferences/*.lproj $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/CrashReporter/
	# Optimize png files
	- find $(THEOS_STAGING_DIR) -iname '*.png' -exec pincrush -i {} \;
	# Convert plist files to binary
	- find $(THEOS_STAGING_DIR)/ -type f -iname '*.plist' -exec plutil -convert binary1 {} \;
	# Remove repository-related files
	- find $(THEOS_STAGING_DIR) -name '.gitkeep' -delete

after-install::
	- ssh idevice killall CrashReporter

distclean: clean
	- rm -f $(THEOS_PROJECT_DIR)/$(PKG_ID)*.deb
	- rm -f $(THEOS_PROJECT_DIR)/.theos/packages/*
