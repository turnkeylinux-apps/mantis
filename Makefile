root.build/ignore-errors = mantis

COMMON_CONF += apache-credit

CREDIT_LOCATION = ~ "^/(?!(manual))"

include $(FAB_PATH)/common/mk/turnkey/lamp.mk
include $(FAB_PATH)/common/mk/turnkey.mk
