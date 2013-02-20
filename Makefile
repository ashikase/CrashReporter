SUBPROJECTS = Application move_as_root

export ARCHS =

#export SDKTARGET = arm-apple-darwin11
#export TARGET_CXX = clang -ccc-host-triple $(SDKTARGET)
#export TARGET_LD = $(SDKTARGET)-g++
#export TARGET_CODESIGN_ALLOCATE=$(CODESIGN_ALLOCATE)

#ADDITIONAL_FLAGS = -D__IPHONE_OS_VERSION_MIN_REQUIRED=__IPHONE_3_0
ADDITIONAL_FLAGS = -miphoneos-version-min=3.0

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
