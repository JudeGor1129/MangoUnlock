ARCHS = arm64
TARGET = iphone:clang:15.0:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MangoUnlock
MangoUnlock_FILES = Tweak.xm
MangoUnlock_FRAMEWORKS = Foundation UIKit
include $(THEOS_MAKE_PATH)/tweak.mk
