
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GyroInspector

GyroInspector_FILES = Tweak.xm
GyroInspector_CFLAGS = -fobjc-arc
GyroInspector_FRAMEWORKS = UIKit CoreMotion

include $(THEOS_MAKE_PATH)/tweak.mk
