##!/usr/bin/env bash
set -eu

USERCONFIG_VID=changeme
USERCONFIG_PID=changeme
USERCONFIG_SN=changeme
USERCONFIG_MAC1=changeme

function readConfig() {
    cat global_config.json
}

function getValueByJsonPath(){
    local JSONPATH=${1}
    local CONFIG=${2}
    jq -r "${JSONPATH}" <<<${CONFIG}
}

function buildImage(){
    [ "${USE_BUILDKIT}" == "true" ] && export DOCKER_BUILDKIT=1
    docker build --file docker/Dockerfile --force-rm  --pull \
        --build-arg DOCKER_BASE_IMAGE="${DOCKER_BASE_IMAGE}" \
        --build-arg COMPILE_WITH="${COMPILE_WITH}" \
        --build-arg EXTRACTED_KSRC="${EXTRACTED_KSRC}" \
        --build-arg KERNEL_SRC_FILENAME="$( [ "${COMPILE_WITH}" == "kernel" ] && echo "${KERNEL_FILENAME}" || echo "${TOOLKIT_DEV_FILENAME}")" \
        --build-arg REDPILL_LKM_REPO="${REDPILL_LKM_REPO}" \
        --build-arg REDPILL_LKM_BRANCH="${REDPILL_LKM_BRANCH}" \
        --build-arg REDPILL_LOAD_REPO="${REDPILL_LOAD_REPO}" \
        --build-arg REDPILL_LOAD_BRANCH="${REDPILL_LOAD_BRANCH}" \
        --build-arg TARGET_PLATFORM="${TARGET_PLATFORM}" \
        --build-arg TARGET_VERSION="${TARGET_VERSION}" \
        --build-arg DSM_VERSION="${DSM_VERSION}" \
        --build-arg TARGET_REVISION="${TARGET_REVISION}" \
        --build-arg USERCONFIG_VID="${USERCONFIG_VID}" \
        --build-arg USERCONFIG_PID="${USERCONFIG_PID}" \
        --build-arg USERCONFIG_SN="${USERCONFIG_SN}" \
        --build-arg USERCONFIG_MAC1="${USERCONFIG_MAC1}" \
        -t ${DOCKER_IMAGE_NAME}:${TARGET_PLATFORM}-${TARGET_VERSION}-${TARGET_REVISION} ./docker
    }

function runContainer(){
    config=$( [ -e user_config.json ] && echo "-v ${PWD}/user_config.json:/opt/redpill-load/user_config.json")
    final_cmd="docker run -ti --rm --privileged -v /dev:/dev \
        -v ${REDPILL_LOAD_CACHE}:/opt/redpill-load/cache \
        -v ${REDPILL_LOAD_IMAGES}:/opt/redpill-load/images \
        $config \
        -e USERCONFIG_VID="${USERCONFIG_VID}" \
        -e USERCONFIG_PID="${USERCONFIG_PID}" \
        -e USERCONFIG_SN="${USERCONFIG_SN}" \
        -e USERCONFIG_MAC1="${USERCONFIG_MAC1}" \
        -e TARGET_PLATFORM="${TARGET_PLATFORM}" \
        -e TARGET_VERSION="${TARGET_VERSION}" \
        -e DSM_VERSION="${DSM_VERSION}" \
        -e REVISION="${TARGET_REVISION}" \
        ${DOCKER_IMAGE_NAME}:${TARGET_PLATFORM}-${TARGET_VERSION}-${TARGET_REVISION} bash $@"
    eval ${final_cmd}
}

function downloadFromUrlIfNotExists(){
    local DOWNLOAD_URL="${1}"
    local OUT_FILE="${2}"
    local MSG="${3}"
    if [ ! -e ${OUT_FILE} ]; then
        echo "Downloading ${MSG}"
        curl --progress-bar --location ${DOWNLOAD_URL} --output ${OUT_FILE}
    fi
}

function showHelp(){
cat << EOF
Usage: ${0} <action> <platform version>

Actions: build run img debug

Available platform versions:
---------------------
${AVAILABLE_IDS}
EOF
}

# mount-bind host folder with absolute path into redpill-load cache folder
# will not work with relativfe path! If single name is used, a docker volume will be created!
REDPILL_LOAD_CACHE=${PWD}/cache

# mount bind hots folder with absolute path into redpill load images folder
REDPILL_LOAD_IMAGES=${PWD}/images


####################################################
# Do not touch anything below, unless you know what you are doing...
####################################################

# parse paramters from config
CONFIG=$(readConfig)
AVAILABLE_IDS=$(getValueByJsonPath ".build_configs[].id" "${CONFIG}")

if [ $# -lt 2 ]; then
    showHelp
    exit 1
fi

ACTION=${1}
ID=${2}
BUILD_CONFIG=$(getValueByJsonPath ".build_configs[] | select(.id==\"${ID}\")" "${CONFIG}")
if [ -z "${BUILD_CONFIG}" ];then
    echo "Error: Platform version ${ID} not specified in global_config.json"
    echo
    showHelp
    exit 1
fi
USE_BUILDKIT=$(getValueByJsonPath ".docker.use_buildkit" "${CONFIG}")
DOCKER_IMAGE_NAME=$(getValueByJsonPath ".docker.image_name" "${CONFIG}")
DOWNLOAD_FOLDER=$(getValueByJsonPath ".docker.download_folder" "${CONFIG}")
TARGET_PLATFORM=$(getValueByJsonPath ".platform_version | split(\"-\")[0]" "${BUILD_CONFIG}")
TARGET_VERSION=$(getValueByJsonPath ".platform_version | split(\"-\")[1]" "${BUILD_CONFIG}")
DSM_VERSION=$(getValueByJsonPath ".platform_version | split(\"-\")[1][0:3]" "${BUILD_CONFIG}")
TARGET_REVISION=$(getValueByJsonPath ".platform_version | split(\"-\")[2]" "${BUILD_CONFIG}")
DOCKER_BASE_IMAGE=$(getValueByJsonPath ".docker_base_image" "${BUILD_CONFIG}")
KERNEL_DOWNLOAD_URL=$(getValueByJsonPath ".download_urls.kernel" "${BUILD_CONFIG}")
COMPILE_WITH=$(getValueByJsonPath ".compile_with" "${BUILD_CONFIG}")
KERNEL_FILENAME=$(getValueByJsonPath ".download_urls.kernel | split(\"/\")[] | select ( . | endswith(\".txz\"))" "${BUILD_CONFIG}")
TOOLKIT_DEV_DOWNLOAD_URL=$(getValueByJsonPath ".download_urls.toolkit_dev" "${BUILD_CONFIG}")
TOOLKIT_DEV_FILENAME=$(getValueByJsonPath ".download_urls.toolkit_dev | split(\"/\")[] | select ( . | endswith(\".txz\"))" "${BUILD_CONFIG}")
REDPILL_LKM_REPO=$(getValueByJsonPath ".redpill_lkm.source_url" "${BUILD_CONFIG}")
REDPILL_LKM_BRANCH=$(getValueByJsonPath ".redpill_lkm.branch" "${BUILD_CONFIG}")
REDPILL_LOAD_REPO=$(getValueByJsonPath ".redpill_load.source_url" "${BUILD_CONFIG}")
REDPILL_LOAD_BRANCH=$(getValueByJsonPath ".redpill_load.branch" "${BUILD_CONFIG}")

EXTRACTED_KSRC='/linux*'
if [ "${COMPILE_WITH}" == "toolkit_dev" ]; then
    EXTRACTED_KSRC="/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-${DSM_VERSION}/build/"
fi

case "${ACTION}" in
    build)  downloadFromUrlIfNotExists "${KERNEL_DOWNLOAD_URL}" "${DOWNLOAD_FOLDER}/${KERNEL_FILENAME}" "Kernel"
            downloadFromUrlIfNotExists "${TOOLKIT_DEV_DOWNLOAD_URL}" "${DOWNLOAD_FOLDER}/${TOOLKIT_DEV_FILENAME}" "Toolkit Dev"
            buildImage
            ;;
    img)   runContainer -c "'make build_all'"
            ;;
    debug)  runContainer -c "'BRP_DEBUG=1 make build_all'"
            ;;
    run)    runContainer
            ;;
    *)      if [ ! -z ${ACTION} ];then
                echo "Error: action ${ACTION} does not exist"
                echo ""
            fi
            showHelp
            exit 1
            ;;
esac

