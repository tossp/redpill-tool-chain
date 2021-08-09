AKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -e -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

####################################################
# Shared arguments for image build and container run
####################################################

export DOCKER_BASE_IMAGE                 := ubuntu:20.04
export DOCKER_IMAGE_NAME                 := redpill-tool-chain

# The USERCONFIG_ variables MUST be configured with valid values - otherwise the redpill image will not boot!
export USERCONFIG_VID                    := <fill me>
export USERCONFIG_PID                    := <fill me>
export USERCONFIG_SN                     := <fill me>
export USERCONFIG_MAC1                   := <fill me>

# Modify parameters to build either bromolow or apollolake with version 6.2.4-25556 or 7.0-41890
# export TARGET_PLATFORM                   := bromolow
export TARGET_PLATFORM                   := apollolake
# export TARGET_VERSION                    := 6.2
export TARGET_VERSION                    := 7.0

export BUILD_REDPILL_LOADER_VERSION      := $(shell [ "$(TARGET_VERSION)" == "6.2" ] && echo "6.2.4-25556" || echo "7.0-41890")

####################################################
# Arguments for container run
####################################################
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
# mount-bind host folder with absolute path into redpill-load cache folder
# will not work with relativfe path! If single name is used, a docker volume will be created!
export REDPILL_LOAD_CACHE                := $(ROOT_DIR)/cache

# mount bind hots folder with absolute path into redpill load images folder
export REDPILL_LOAD_IMAGES               := $(ROOT_DIR)/images

####################################################
# build image downloads and build argument
####################################################

export DOWNLOAD_FOLDER                              := docker/downloads

export DSM6.2_BROMOLOW_TOOLCHAIN_DOWNLOAD_URL       := https://sourceforge.net/projects/dsgpl/files/Tool%20Chain/DSM%206.2.4%20Tool%20Chains/Intel%20x86%20linux%203.10.105%20%28Bromolow%29/bromolow-gcc493_glibc220_linaro_x86_64-GPL.txz/download
export DSM6.2_BROMOLOW_TOOLCHAIN_FILENAME           := bromolow-gcc493_glibc220_linaro_x86_64-GPL.txz

export DSM7.0_BROMOLOW_TOOLCHAIN_DOWNLOAD_URL       := https://sourceforge.net/projects/dsgpl/files/Tool%20Chain/DSM%207.0.0%20Tool%20Chains/Intel%20x86%20linux%203.10.108%20%28Bromolow%29/bromolow-gcc750_glibc226_x86_64-GPL.txz/download
export DSM7.0_BROMOLOW_TOOLCHAIN_FILENAME           := bromolow-gcc750_glibc226_x86_64-GPL.txz

export DSM6.2_APOLLOLAKE_TOOLCHAIN_DOWNLOAD_URL     := https://sourceforge.net/projects/dsgpl/files/Tool%20Chain/DSM%206.2.4%20Tool%20Chains/Intel%20x86%20Linux%204.4.59%20%28Apollolake%29/apollolake-gcc493_glibc220_linaro_x86_64-GPL.txz/download
export DSM6.2_APOLLOLAKE_TOOLCHAIN_FILENAME         := apollolake-gcc493_glibc220_linaro_x86_64-GPL.txz

export DSM7.0_APOLLOLAKE_TOOLCHAIN_DOWNLOAD_URL     := https://sourceforge.net/projects/dsgpl/files/Tool%20Chain/DSM%207.0.0%20Tool%20Chains/Intel%20x86%20Linux%204.4.180%20%28Apollolake%29/apollolake-gcc750_glibc226_x86_64-GPL.txz/download
export DSM7.0_APOLLOLAKE_TOOLCHAIN_FILENAME         := apollolake-gcc750_glibc226_x86_64-GPL.txz

export BROMOLOW_KERNEL_DOWNLOAD_URL                 := https://sourceforge.net/projects/dsgpl/files/Synology%20NAS%20GPL%20Source/25426branch/bromolow-source/linux-3.10.x.txz/download
export BROMOLOW_KERNEL_FILENAME                     := linux-3.10.x.txz

export APOLLOLAKE_KERNEL_DOWNLOAD_URL               := https://sourceforge.net/projects/dsgpl/files/Synology%20NAS%20GPL%20Source/25426branch/apollolake-source/linux-4.4.x.txz/download
export APOLLOLAKE_KERNEL_FILENAME                   := linux-4.4.x.txz

export TOOLKIT_DEV_DOWNLOAD_URL                     := https://sourceforge.net/projects/dsgpl/files/toolkit/DSM$(TARGET_VERSION)/ds.$(TARGET_PLATFORM)-$(TARGET_VERSION).dev.txz/download
export TOOLKIT_DEV_FILENAME                         := ds.$(TARGET_PLATFORM)-$(TARGET_VERSION).dev.txz

export REDPILL_LKM_REPO                             := https://github.com/RedPill-TTG/redpill-lkm.git
export REDPILL_LKM_BRANCH                           := master

# detect based on TARGET_VERSION
export REDPILL_LOAD                                 := https://github.com/$(shell [ "$(TARGET_VERSION)" == "6.2" ] && echo "RedPill-TTG" || echo "jumkey")/redpill-load.git
export REDPILL_LOAD_BRANCH                          := $(shell [ "$(TARGET_VERSION)" == "6.2" ] && echo "master" || echo "7.0-41890")

#export REDPILL_LOAD                                 := https://github.com/RedPill-TTG/redpill-load.git
#export REDPILL_LOAD_BRANCH                          := master

#REDPILL_LOAD                                        := https://github.com/jumkey/redpill-load.git
#REDPILL_LOAD_BRANCH                                 := 7.0-41890

####################################################
# Do not touch anything below, unless you know what you are doing...
####################################################

.PHONY: all
all:
	$(call printTargets)

.PHONY: build_download
build_download:
	$(call downloadFromUrlIfNotExists,$(call getToolChainFilename),$(call getToolChainDownloadURL),$(TARGET_PLATFORM) toolchain)
	$(call downloadFromUrlIfNotExists,$(call getKernelFilename),$(call getKernelDownloadURL),$(TARGET_PLATFORM) kernel)
	$(call downloadFromUrlIfNotExists,$(TOOLKIT_DEV_FILENAME),$(TOOLKIT_DEV_DOWNLOAD_URL),$(TARGET_PLATFORM) $(TAGET_VERSION) Toolkit (includes kernel modules))

.PHONY: build_image
build_image: build_download
	$(call buildImage,$(TARGET_PLATFORM),$(call getToolChainFilename),$(call getKernelFilename),$(TOOLKIT_DEV_FILENAME))

.PHONY: run_container
run_container:
	$(call runContainer,$(TARGET_PLATFORM))

## Print makefile PHONY targets to the console
define printTargets
	@echo "Possible Targets:"
	@less Makefile |grep .PHONY[:] |cut -f2 -d ' ' |xargs -n1 echo " - " |grep -v " -  all"
endef

## Download binaries
##
## @param 1 Path to downloaded file
## @param 2 Download URL
## @param 3 Message to display
define downloadFromUrlIfNotExists
	@if [ ! -e $(DOWNLOAD_FOLDER)/$(1) ]; then \
		echo "Downloading $(3) $(2) $(1)"; \
		curl --location '$(2)' --output $(DOWNLOAD_FOLDER)/$(1); \
	fi
endef

## Build docker image
##
## @param 1 Platform to build
## @param 3 Toolkit Filename to add to the image
## @param 2 Toolchain Filename to add to the image
define buildImage
	@echo 'DOCKER_BUILDKIT=1 docker build --file docker/Dockerfile --force-rm  --pull \
		--build-arg DOCKER_BASE_IMAGE=$(DOCKER_BASE_IMAGE) \
		--build-arg TOOLCHAIN_FILENAME="$(2)" \
		--build-arg KERNEL_FILENAME="$(3)" \
		--build-arg TOOLKIT_DEV_FILENAME="$(4)" \
		--build-arg REDPILL_LKM_REPO="$(REDPILL_LKM_REPO)" \
		--build-arg REDPILL_LKM_BRANCH="$(REDPILL_LKM_BRANCH)" \
		--build-arg REDPILL_LOAD="$(REDPILL_LOAD)" \
		--build-arg REDPILL_LOAD_BRANCH="$(REDPILL_LOAD_BRANCH)" \
		--build-arg BUILD_REDPILL_LOADER_VERSION="$(BUILD_REDPILL_LOADER_VERSION)" \
		--build-arg USERCONFIG_VID="$(USERCONFIG_VID)" \
		--build-arg USERCONFIG_PID="$(USERCONFIG_PID)" \
		--build-arg USERCONFIG_SN="$(USERCONFIG_SN)" \
		--build-arg USERCONFIG_MAC1="$(USERCONFIG_MAC1)" \
		--build-arg TARGET_PLATFORM="$(TARGET_PLATFORM)" \
		--build-arg TARGET_VERSION="$(TARGET_VERSION)" \
		-t $(DOCKER_IMAGE_NAME):$(TARGET_PLATFORM)-$(TARGET_VERSION) ./docker'
endef

## Run docker container and mount cache volume, image bind-mount and if present a user_config.json file
define runContainer
	@echo 'docker run -ti --rm --privileged -v /dev:/dev \
		-v $(REDPILL_LOAD_CACHE):/opt/redpill-load/cache \
		-v $(REDPILL_LOAD_IMAGES):/opt/redpill-load/images \
		$(shell [ -e user_config.json ] && echo "-v $(PWD)/user_config.json:/opt/redpill-load/user_config.json") \
		-e USERCONFIG_VID="$(USERCONFIG_VID)" \
		-e USERCONFIG_PID="$(USERCONFIG_PID)" \
		-e USERCONFIG_SN="$(USERCONFIG_SN)" \
		-e USERCONFIG_MAC1="$(USERCONFIG_MAC1)" \
		-e BUILD_REDPILL_LOADER_VERSION=$(BUILD_REDPILL_LOADER_VERSION) \
		$(DOCKER_IMAGE_NAME):$(TARGET_PLATFORM)-$(TARGET_VERSION) bash'
endef

define getToolChainFilename
${DSM$(TARGET_VERSION)_$(shell echo $(TARGET_PLATFORM) | tr '[:lower:]' '[:upper:]')_TOOLCHAIN_FILENAME}
endef

define getToolChainDownloadURL
${DSM$(TARGET_VERSION)_$(shell echo $(TARGET_PLATFORM) | tr '[:lower:]' '[:upper:]')_TOOLCHAIN_DOWNLOAD_URL}
endef

define getKernelFilename
${$(shell echo $(TARGET_PLATFORM) | tr '[:lower:]' '[:upper:]')_KERNEL_FILENAME}
endef

define getKernelDownloadURL
${$(shell echo $(TARGET_PLATFORM) | tr '[:lower:]' '[:upper:]')_KERNEL_DOWNLOAD_URL}
endef
