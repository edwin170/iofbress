THEOS_DEVICE_IP = -p 2222 root@localhost
ARCHS = arm64 arm64e
export SYSROOT = $(THEOS)/sdks/iPhoneOS13.7.sdk
TARGET := iphone:clang:13.7:12.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = iofbress

iofbress_FILES = main.m
iofbress_CFLAGS = -fobjc-arc
iofbress_CODESIGN_FLAGS = -Sentitlements.plist
iofbress_INSTALL_PATH = /usr/local/bin
iofbress_FRAMEWORKS = IOKit CoreFoundation Foundation


include $(THEOS_MAKE_PATH)/tool.mk
