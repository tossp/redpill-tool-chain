AKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -e -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

export REDPILL_SRC        := /opt/redpill-lkm
export REDPILL_LOADER_SRC := /opt/redpill-load

export TARGET_PLATFORM     :=${TARGET_PLATFORM}
export LINUX_SRC          := ${LINUX_SRC}

export USERCONFIG_VID     := ${USERCONFIG_VID}
export USERCONFIG_PID     := ${USERCONFIG_PID}
export USERCONFIG_SN      := ${USERCONFIG_SN}
export USERCONFIG_MAC1    := ${USERCONFIG_MAC1}

export BUILD_REDPILL_LOADER_VERSION := ${BUILD_REDPILL_LOADER_VERSION}

.PHONY: all
all:
	@echo "Possible Targets:"
	@less Makefile |grep .PHONY[:] |cut -f2 -d ' ' |xargs -n1 echo " - " |grep -v " -  all"

.PHONY: build_redpill_lkm
build_redpill_lkm:
	@$(MAKE) -C $(REDPILL_SRC) LINUX_SRC=$(LINUX_SRC) && \
	echo "#############################################" && \
	modinfo $(REDPILL_SRC)/redpill.ko

.PHONY: build_redpill_load
build_redpill_load:
	@mkdir -p $(REDPILL_LOADER_SRC)/ext/rp-lkm/
	@if [ ! -e $(REDPILL_LOADER_SRC)/user_config.json ]; then envsubst < user_config.json.template > $(REDPILL_LOADER_SRC)/user_config.json; fi
	@echo "#############################################" && \
	echo "Using user_config.json:" && cat $(REDPILL_LOADER_SRC)/user_config.json && \
	echo "#############################################"
	@if [ "$(TARGET_PLATFORM)" == "bromolow" ]; then \
		pushd $(REDPILL_LOADER_SRC) && \
		if [ "$(BUILD_REDPILL_LOADER_VERSION)" == "7.0-41890" ];then \
			cp -f $(REDPILL_SRC)/redpill.ko $(REDPILL_LOADER_SRC)/ext/rp-lkm/redpill-linux-v3.10.108.ko ; \
		else \
			cp -f $(REDPILL_SRC)/redpill.ko $(REDPILL_LOADER_SRC)/ext/rp-lkm/redpill-linux-v3.10.105.ko ; \
		fi && \
		./build-loader.sh 'DS3615xs' '$(BUILD_REDPILL_LOADER_VERSION)'; \
	fi
	@if [ "$(TARGET_PLATFORM)" == "apollolake" ]; then \
		pushd $(REDPILL_LOADER_SRC) && \
		if [ "$(BUILD_REDPILL_LOADER_VERSION)" == "7.0-41890" ];then \
			cp -f $(REDPILL_SRC)/redpill.ko $(REDPILL_LOADER_SRC)/ext/rp-lkm/redpill-linux-v4.4.180+.ko; \
		else \
			cp -f $(REDPILL_SRC)/redpill.ko $(REDPILL_LOADER_SRC)/ext/rp-lkm/redpill-linux-v4.4.59+.ko; \
		fi && \
		./build-loader.sh 'DS918+' '$(BUILD_REDPILL_LOADER_VERSION)'; \
	fi

.PHONY: build_all
build_all: build_redpill_lkm build_redpill_load

.PHONY: clean_redpill_lkm
clean_redpill_lkm:
	@$(MAKE) -C $(REDPILL_SRC) clean
