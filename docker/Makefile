AKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -e -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

export REDPILL_LKM_SRC         := ${REDPILL_LKM_SRC}
export REDPILL_LOAD_SRC        := ${REDPILL_LOAD_SRC}
export REDPILL_LKM_MAKE_TARGET := ${REDPILL_LKM_MAKE_TARGET}
export TARGET_PLATFORM         := ${TARGET_PLATFORM}
export TARGET_VERSION          := ${TARGET_VERSION}
export TARGET_REVISION         := ${TARGET_REVISION}
export LINUX_SRC               := ${LINUX_SRC}

.PHONY: all
all:
	@echo "Possible Targets:"
	@cat Makefile |grep .PHONY[:] |cut -f2 -d ' ' |xargs -n1 echo " - " |grep -v " -  all"

.PHONY: build_redpill_lkm
build_redpill_lkm:
	@$(MAKE) -C $(REDPILL_LKM_SRC) LINUX_SRC=$(LINUX_SRC) $(REDPILL_LKM_MAKE_TARGET) && \
	echo "#############################################" && \
	modinfo $(REDPILL_LKM_SRC)/redpill.ko

.PHONY: build_redpill_load
build_redpill_load:
	@mkdir -p $(REDPILL_LOAD_SRC)/ext/rp-lkm/
	@echo "#############################################" && \
	echo "Using user_config.json:" && cat $(REDPILL_LOAD_SRC)/user_config.json && \
	echo "#############################################"
	@read -a KVERS <<< "$$(modinfo --field=vermagic redpill-lkm/redpill.ko)" && \
	cp -f $(REDPILL_LKM_SRC)/redpill.ko $(REDPILL_LOAD_SRC)/ext/rp-lkm/redpill-linux-v$${KVERS[0]}.ko
	@if [ "$(TARGET_PLATFORM)" == "bromolow" ]; then \
		pushd $(REDPILL_LOAD_SRC) && \
		./build-loader.sh 'DS3615xs' '$(TARGET_VERSION)-$(TARGET_REVISION)'; \
	fi
	@if [ "$(TARGET_PLATFORM)" == "apollolake" ]; then \
		pushd $(REDPILL_LOAD_SRC) && \
		./build-loader.sh 'DS918+' '$(TARGET_VERSION)-$(TARGET_REVISION)'; \
	fi
	@if [ "$(TARGET_PLATFORM)" == "broadwell" ]; then \
		pushd $(REDPILL_LOAD_SRC) && \
		./build-loader.sh 'DS3617xs' '$(TARGET_VERSION)-$(TARGET_REVISION)'; \
	fi
	@if [ "$(TARGET_PLATFORM)" == "broadwellnk" ]; then \
		pushd $(REDPILL_LOAD_SRC) && \
		./build-loader.sh 'DS3622xs+' '$(TARGET_VERSION)-$(TARGET_REVISION)'; \
	fi
	@if [ "$(TARGET_PLATFORM)" == "geminilake" ]; then \
		pushd $(REDPILL_LOAD_SRC) && \
		./build-loader.sh 'DS920+' '$(TARGET_VERSION)-$(TARGET_REVISION)'; \
	fi

.PHONY: build_all
build_all: build_redpill_lkm build_redpill_load

.PHONY: clean_redpill_lkm
clean_redpill_lkm:
	@$(MAKE) -C $(REDPILL_LKM_SRC) clean
