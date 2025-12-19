# 环境变量预设
THEOS ?= /opt/theos
THEOS_MAKE_PATH ?= $(THEOS)/makefiles

# 目标配置
export TARGET = iphone:clang:14.5:14.5
export ARCHS = arm64 arm64e
export FINALPACKAGE = 0

# 项目名称
TWEAK_NAME = WeChatIslandBanner

# 源文件（使用 Tab 缩进 ⇥）
WeChatIslandBanner_FILES = \
	Tweak.xm \
	$(wildcard Sources/*.m) \
	$(wildcard Controllers/*.m)

WeChatIslandBanner_HEADER_DIRS = \
	$(THEOS_PROJECT_DIR)/Headers \
	$(THEOS_PROJECT_DIR)/Controllers \
	$(THEOS_PROJECT_DIR)/Sources

# 编译选项
WeChatIslandBanner_CFLAGS += -fobjc-arc -mios-version-min=14.5 \
	-I$(THEOS_PROJECT_DIR) \
	-I$(THEOS_PROJECT_DIR)/Headers \
	-I$(THEOS_PROJECT_DIR)/Sources \
	-I$(THEOS_PROJECT_DIR)/Controllers

# 框架依赖
WeChatIslandBanner_FRAMEWORKS = UIKit

# 加载构建规则
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk