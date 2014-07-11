SUBPROJECTS = Application move_as_root

export ARCHS = armv6 arm64
export TARGET = iphone:clang:7.1:3.0

include theos/makefiles/common.mk
include theos/makefiles/aggregate.mk

after-stage::
	# Optimize png files
	- find $(THEOS_STAGING_DIR) -iname '*.png' -exec pincrush -i {} \;
	# Convert plist files to binary
	- find $(THEOS_STAGING_DIR)/ -type f -iname '*.plist' -exec plutil -convert binary1 {} \;
	# Remove repository-related files
	- find $(THEOS_STAGING_DIR) -name '.gitkeep' -delete

distclean: clean
	- rm -f $(THEOS_PROJECT_DIR)/$(APP_ID)*.deb
	- rm -f $(THEOS_PROJECT_DIR)/.theos/packages/*
