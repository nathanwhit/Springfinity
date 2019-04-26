include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = infiniboard12prefs
infiniboard12prefs_FILES = IFBRootListController.m
infiniboard12prefs_INSTALL_PATH = /Library/PreferenceBundles
infiniboard12prefs_FRAMEWORKS = UIKit
infiniboard12prefs_PRIVATE_FRAMEWORKS = Preferences
infiniboard12prefs_CFLAGS += -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/infiniboard12prefs.plist$(ECHO_END)
