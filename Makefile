TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := NeoIsland
NeoIsland_FILES := Tweak.x Sources/NIConfigurationManager.m Sources/NICompatibility.m Sources/NIIslandManager.m Sources/NIIslandView.m Sources/NIModuleProvider.m Sources/NIIconRenderer.m
NeoIsland_CFLAGS := -fobjc-arc -Wall -Wextra
NeoIsland_FRAMEWORKS := UIKit Foundation QuartzCore MediaPlayer AVFAudio SystemConfiguration

INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk

before-package::
	chmod -R u=rwX,go=rX "$(THEOS_STAGING_DIR)" "$(_THEOS_STAGING_TMP)"

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk