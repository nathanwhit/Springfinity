include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = springfinityprefs
springfinityprefs_FILES = SFRootListController.m
springfinityprefs_INSTALL_PATH = /Library/PreferenceBundles
springfinityprefs_FRAMEWORKS = UIKit
springfinityprefs_PRIVATE_FRAMEWORKS = Preferences
springfinityprefs_CFLAGS += -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/springfinityprefs.plist$(ECHO_END)
