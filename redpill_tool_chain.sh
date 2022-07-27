#!/usr/bin/env bash
set -eu
cd $(dirname $(readlink -f "$0"))

function checkPreconditon(){
    missing_tools=""
    for tool in jq docker realpath sha256sum; do
        if [ ! $(which ${tool} ) ];then
            missing_tools+=" ${tool}"
        fi
    done
    if [ ${#missing_tools} -gt 0 ]; then
        echo "required tool(s) missing:$missing_tools. Please install them and run the command again!"
        exit 1
    fi
    asdf
}
checkPreconditon

function readConfig() {
    cat global_config.json
}

function getValueByJsonPath(){
    local JSONPATH=${1}
    local CONFIG=${2}
    jq -r "${JSONPATH}" <<<${CONFIG}
}

function buildImage(){jasdgfu
    local KERNEL_SRC_FILENAME=$( [ "${COMPILE_WITH}" == "kernel" ] && echo "${TARGET_PLATFORM}.${KERNEL_FILENAME}" || echo "${TOOLKIT_DEV_FILENAME}")
    local KERNEL_SRC_FILENAME_SHA256=$( [ "${COMPILE_WITH}" == "kernel" ] && echo "${KERNEL_DOWNLOAD_SHA256}" || echo "${TOOLKIT_DEV_DOWNLOAD_SHA256}")
    checkFileSHA256Checksum "${DOWNLOAD_FOLDER}/${KERNEL_SRC_FILENAME}" "${KERNEL_SRC_FILENAME_SHA256}"

    [ "${USE_BUILDKIT}" == "true" ] && export DOCKER_BUILDKIT=1
    docker build --file docker/Dockerfile --force-rm \
        $( [ "${USE_BUILD_CACHE}" == "false" ] && echo "--no-cache" ) \
        --build-arg DOCKER_BASE_IMAGE="${DOCKER_BASE_IMAGE}" \
        --build-arg COMPILE_WITH="${COMPILE_WITH}" \
        --build-arg EXTRACTED_KSRC="${EXTRACTED_KSRC}" \
        --build-arg KERNEL_SRC_FILENAME="${KERNEL_SRC_FILENAME}" \
        --build-arg REDPILL_LKM_REPO="${REDPILL_LKM_REPO}" \
        --build-arg REDPILL_LKM_BRANCH="${REDPILL_LKM_BRANCH}" \
        --build-arg REDPILL_LOAD_REPO="${REDPILL_LOAD_REPO}" \
        --build-arg REDPILL_LOAD_BRANCH="${REDPILL_LOAD_BRANCH}" \
        --build-arg TARGET_NAME="${TARGET_NAME}" \
        --build-arg TARGET_PLATFORM="${TARGET_PLATFORM}" \
        --build-arg TARGET_VERSION="${TARGET_VERSION}" \
        --build-arg DSM_VERSION="${DSM_VERSION}" \
        --build-arg TARGET_REVISION="${TARGET_REVISION}" \
        --build-arg REDPILL_LKM_MAKE_TARGET=${REDPILL_LKM_MAKE_TARGET} \
        --tag ${DOCKER_IMAGE_NAME}:${ID} ./docker
}

function clean(){
    if [ "${AUTO_CLEAN}" != "true" ]; then
        echo "---------- before clean --------------------------------------"
        docker system df
    fi
    if [ "${ID}" == "all" ];then
        OLD_IMAGES=$(docker image ls --filter label=redpill-tool-chain --quiet $( [ "${CLEAN_IMAGES}" == "orphaned" ] && echo "--filter dangling=true"))
        docker builder prune --all --filter label=redpill-tool-chain --force
    else
        OLD_IMAGES=$(docker image ls --filter label=redpill-tool-chain=${ID} --quiet --filter dangling=true)
        docker builder prune --filter label=redpill-tool-chain=${ID} --force
    fi
    if [ ! -z "${OLD_IMAGES}" ]; then
        docker image rm ${OLD_IMAGES}
    fi
    if [ "${AUTO_CLEAN}" != "true" ]; then
        echo "---------- after clean ---------------------------------------"
        docker system df
    fi
}

function runContainer(){
    local CMD=${1}
    if [ ! -e $(realpath "${USER_CONFIG_JSON}") ]; then
        echo "user config does not exist: ${USER_CONFIG_JSON}"
        echo "run 'cp sample_user_config.json ${USER_CONFIG_JSON}' and edit '${USER_CONFIG_JSON}'."
        exit 1
    fi
    if [[ "${LOCAL_RP_LKM_USE}" == "true" && ! -e $(realpath "${LOCAL_RP_LKM_PATH}") ]]; then
        echo "Local redpill-lkm path does not exist: ${LOCAL_RP_LKM_PATH}"
        exit 1
    fi
    if [[ "${LOCAL_RP_LOAD_USE}" == "true" && ! -e $(realpath "${LOCAL_RP_LOAD_PATH}") ]]; then
        echo "Local redpill-load path does not exist: ${LOCAL_RP_LOAD_PATH}"
        exit 1
    fi
    if [[ "${USE_CUSTOM_BIND_MOUNTS}" == "true" ]]; then
        NUMBER_OF_MOUNTS=$(getValueByJsonPath ". | length" "${CUSTOM_BIND_MOUNTS}")
        for (( i=0; i<${NUMBER_OF_MOUNTS}; i++ ));do
            HOST_PATH=$(getValueByJsonPath ".[${i}].host_path" "${CUSTOM_BIND_MOUNTS}")
            CONTAINER_PATH=$(getValueByJsonPath ".[${i}].container_path" "${CUSTOM_BIND_MOUNTS}")
            if [ ! -e $(realpath "${HOST_PATH}") ]; then
                echo "Host path does not exist: ${HOST_PATH}"
                exit 1
            fi
            BINDS+="--volume $(realpath ${HOST_PATH}):${CONTAINER_PATH} "
        done
    fi
    BINDS+="--volume $(realpath docker/helper.sh):/opt/helper.sh "
    docker run --privileged --rm  $( [ "${CMD}" == "run" ] && echo " --interactive") --tty \
        --name redpill-tool-chain \
        --hostname redpill-tool-chain \
        --volume /dev:/dev \
        $( [ "${USE_CUSTOM_BIND_MOUNTS}" == "true" ] && echo "${BINDS}") \
        $( [ "${LOCAL_RP_LOAD_USE}" == "true" ] && echo "--volume $(realpath ${LOCAL_RP_LOAD_PATH}):/opt/redpill-load") \
        $( [ "${LOCAL_RP_LKM_USE}" == "true" ] && echo "--volume $(realpath ${LOCAL_RP_LKM_PATH}):/opt/redpill-lkm") \
        $( [ -e "${USER_CONFIG_JSON}" ] && echo "--volume $(realpath ${USER_CONFIG_JSON}):/opt/redpill-load/user_config.json") \
        $( [ "${BUILD_LOADER_JUN_MOD}" == "1" ] && echo "--env BRP_JUN_MOD=1") \
        $( [ "${BUILD_LOADER_DEBUG}" == "1" ] && echo "--env BRP_DEBUG=1") \
        --volume ${REDPILL_LOAD_CACHE}:/opt/redpill-load/cache \
        --volume ${REDPILL_LOAD_IMAGES}:/opt/redpill-load/images \
        --env REDPILL_LKM_MAKE_TARGET=${REDPILL_LKM_MAKE_TARGET} \
        --env TARGET_PLATFORM="${TARGET_PLATFORM}" \
        --env TARGET_NAME="${TARGET_NAME}" \
        --env TARGET_VERSION="${TARGET_VERSION}" \
        --env DSM_VERSION="${DSM_VERSION}" \
        --env REVISION="${TARGET_REVISION}" \
        --env LOCAL_RP_LKM_USE="${LOCAL_RP_LKM_USE}" \
        --env LOCAL_RP_LOAD_USE="${LOCAL_RP_LOAD_USE}" \
        ${DOCKER_IMAGE_NAME}:${ID} $( [ "${CMD}" == "run" ] && echo "/bin/bash") $( [ "${CMD}" == "pat" ] && echo "/opt/helper.sh")
}

function __ext_add(){
    if [ -z ${EXT_PATH} ]; then
        echo "Custom extension directory is not enabled"
        exit 1
    fi
    if [ ! -d ${EXT_PATH} ];then
        mkdir ${EXT_PATH}
    fi
    readonly URL="${1}"
    local MRP_TMP_IDX="${EXT_PATH}/_new_ext_index.tmp_json"

    if [ -f ${MRP_TMP_IDX} ];then
        rm ${MRP_TMP_IDX}
    fi

    echo "Downloading"
    curl -k --progress-bar --location ${URL} --output ${MRP_TMP_IDX}

    ext_json=$(cat ${MRP_TMP_IDX})
    ext_id=$(getValueByJsonPath ".id" "${ext_json}")
    ext_name=$(getValueByJsonPath ".info.name" "${ext_json}")
    ext_releases="$(getValueByJsonPath ".releases|keys|join(\" \")" "${ext_json}")"
    echo -e "${ext_id}\nName:\t\t\t${ext_id}\nDescription:\t\t$(getValueByJsonPath ".info.description" "${ext_json}")\nSupport platform:\t${ext_releases}\nInstallation is complete!"
    if [ ! -d "${EXT_PATH}/${ext_id}/${ext_id}" ];then
        mkdir -p ${EXT_PATH}/${ext_id}
    fi
    echo ${ext_json} > "${EXT_PATH}/${ext_id}/${ext_id}.json"
    rm ${MRP_TMP_IDX}
}

function __ext_del(){
    if [ -z ${EXT_PATH} ]; then
        echo "Custom extension directory is not enabled"
        exit 1
    fi
    for i in ${EXTENSION_IDS}
    do
        if [ "${i}" == "${1}" ]; then
            rm -rf "${EXT_PATH}/${1}"
            exit 0
        fi
    done
}

function downloadFromUrlIfNotExists(){
    local DOWNLOAD_URL="${1}"
    local OUT_FILE="${2}"
    local MSG="${3}"
    if [ ! -e ${OUT_FILE} ]; then
        echo "Downloading ${MSG} '${OUT_FILE}'"
        curl -k --progress-bar --location ${DOWNLOAD_URL} --output ${OUT_FILE}
    fi
}

function checkFileSHA256Checksum(){
    local FILE="${1}"
    local EXPECTED_SHA256="${2}"
    local SHA256_RESULT=$(sha256sum ${FILE})
    if [ "${SHA256_RESULT%% *}" != "${EXPECTED_SHA256}" ];then
        echo "The ${FILE} is corrupted, expected sha256 checksum ${EXPECTED_SHA256}, got ${SHA256_RESULT%% *}"
        #rm -f "${FILE}"
        #echo "Deleted corrupted file ${FILE}. Please re-run your action!"
        echo "Please delete the file ${FILE} manualy and re-run your command!"
        exit 1
    fi
}

function showHelp(){
cat << EOF
Usage: ${0} <action> <platform version>

Actions: build, auto, run, clean, add, del, sn, pat

- build:    Build the toolchain image for the specified platform version.

- auto:     Starts the toolchain container using the previosuly build toolchain image for the specified platform.
            Updates redpill sources and builds the bootloader image automaticaly. Will end the container once done.

- run:      Starts the toolchain container using the previously built toolchain image for the specified platform.
            Interactive Bash terminal.

- clean:    Removes old (=dangling) images and the build cache for a platform version.
            Use ‘all’ as platform version to remove images and build caches for all platform versions.

- add:      To install extension you need to know its index file location and nothing more.
            eg: add 'https://example.com/some-extension/rpext-index.json'

- del:      To remove an already installed extension you need to know its ID.
            eg: del 'example_dev.some_extension'

- sn:       Generates a serial number and mac address for the following platforms
            DS3615xs DS3617xs DS916+ DS918+ DS920+ DS3622xs+ FS6400 DVA3219 DVA3221 DS1621+
            eg: sn ds920p

- pat:      For decoding PAT file. see: https://github.com/tossp/redpill-tool-chain/blob/master/.github/workflows/pat.yml

Available platform versions:
---------------------
${AVAILABLE_IDS}

Custom Extensions:
---------------------
${EXTENSION_IDS}

Check global_settings.json for settings.
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
AUTO_CLEAN=$(getValueByJsonPath ".docker.auto_clean" "${CONFIG}")
USE_BUILD_CACHE=$(getValueByJsonPath ".docker.use_build_cache" "${CONFIG}")
CLEAN_IMAGES=$(getValueByJsonPath ".docker.clean_images" "${CONFIG}")
USE_CUSTOM_BIND_MOUNTS=$(getValueByJsonPath ".docker.use_custom_bind_mounts" "${CONFIG}")
CUSTOM_BIND_MOUNTS=$(getValueByJsonPath ".docker.custom_bind_mounts" "${CONFIG}")

EXT_PATH=""
EXTENSION_IDS="[Nothing]"

if [[ "${USE_CUSTOM_BIND_MOUNTS}" == "true" ]]; then
    NUMBER_OF_MOUNTS=$(getValueByJsonPath ". | length" "${CUSTOM_BIND_MOUNTS}")
    for (( i=0; i<${NUMBER_OF_MOUNTS}; i++ ));do
        HOST_PATH=$(getValueByJsonPath ".[${i}].host_path" "${CUSTOM_BIND_MOUNTS}")
        CONTAINER_PATH=$(getValueByJsonPath ".[${i}].container_path" "${CUSTOM_BIND_MOUNTS}")

        if [ -e $(realpath "${HOST_PATH}") ]; then
            EXT_PATH="${HOST_PATH}/extensions"
        fi

        if [[ "${CONTAINER_PATH}" == "/opt/redpill-load/custom" && -d "${EXT_PATH}" ]];then
            EXTENSION_IDS=$(ls ${EXT_PATH})
        fi
    done
fi

if [ $# -lt 2 ]; then
    showHelp
    exit 1
fi

ACTION=${1}
ID=${2}

if [[ "${ACTION}" != "del" && "${ACTION}" != "add" && "${ACTION}" != "sn" && "${ID}" != "all" ]]; then
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
    LOCAL_RP_LKM_USE=$(getValueByJsonPath ".docker.local_rp_lkm_use" "${CONFIG}")
    LOCAL_RP_LKM_PATH=$(getValueByJsonPath ".docker.local_rp_lkm_path" "${CONFIG}")
    LOCAL_RP_LOAD_USE=$(getValueByJsonPath ".docker.local_rp_load_use" "${CONFIG}")
    LOCAL_RP_LOAD_PATH=$(getValueByJsonPath ".docker.local_rp_load_path" "${CONFIG}")
    TARGET_PLATFORM=$(getValueByJsonPath ".platform_version | split(\"-\")[0]" "${BUILD_CONFIG}")
    TARGET_VERSION=$(getValueByJsonPath ".platform_version | split(\"-\")[1]" "${BUILD_CONFIG}")
    DSM_VERSION=$(getValueByJsonPath ".platform_version | split(\"-\")[1][0:3]" "${BUILD_CONFIG}")
    TARGET_REVISION=$(getValueByJsonPath ".platform_version | split(\"-\")[2]" "${BUILD_CONFIG}")
    TARGET_NAME=$(getValueByJsonPath ".platform_name" "${BUILD_CONFIG}")
    USER_CONFIG_JSON=$(getValueByJsonPath ".user_config_json" "${BUILD_CONFIG}")
    DOCKER_BASE_IMAGE=$(getValueByJsonPath ".docker_base_image" "${BUILD_CONFIG}")
    COMPILE_WITH=$(getValueByJsonPath ".compile_with" "${BUILD_CONFIG}")
    REDPILL_LKM_MAKE_TARGET=$(getValueByJsonPath ".redpill_lkm_make_target" "${BUILD_CONFIG}")
    KERNEL_DOWNLOAD_URL=$(getValueByJsonPath ".downloads.kernel.url" "${BUILD_CONFIG}")
    KERNEL_DOWNLOAD_SHA256=$(getValueByJsonPath ".downloads.kernel.sha256" "${BUILD_CONFIG}")
    KERNEL_FILENAME=$(getValueByJsonPath ".downloads.kernel.url | split(\"/\")[] | select ( . | endswith(\".txz\"))" "${BUILD_CONFIG}")
    TOOLKIT_DEV_DOWNLOAD_URL=$(getValueByJsonPath ".downloads.toolkit_dev.url" "${BUILD_CONFIG}")
    TOOLKIT_DEV_DOWNLOAD_SHA256=$(getValueByJsonPath ".downloads.toolkit_dev.sha256" "${BUILD_CONFIG}")
    TOOLKIT_DEV_FILENAME=$(getValueByJsonPath ".downloads.toolkit_dev.url | split(\"/\")[] | select ( . | endswith(\".txz\"))" "${BUILD_CONFIG}")
    REDPILL_LKM_REPO=$(getValueByJsonPath ".redpill_lkm.source_url" "${BUILD_CONFIG}")
    REDPILL_LKM_BRANCH=$(getValueByJsonPath ".redpill_lkm.branch" "${BUILD_CONFIG}")
    REDPILL_LOAD_REPO=$(getValueByJsonPath ".redpill_load.source_url" "${BUILD_CONFIG}")
    REDPILL_LOAD_BRANCH=$(getValueByJsonPath ".redpill_load.branch" "${BUILD_CONFIG}")

    BUILD_LOADER_JUN_MOD=$(getValueByJsonPath ".build_env.jun_mod" "${BUILD_CONFIG}")
    BUILD_LOADER_DEBUG=$(getValueByJsonPath ".build_env.debug" "${BUILD_CONFIG}")

    EXTRACTED_KSRC="/linux*"
    if [ "${COMPILE_WITH}" == "toolkit_dev" ]; then
        # TODO: fix: wait new toolkit
        if [ "${DSM_VERSION}" == "7.1" ]; then
            DSM_VERSION="7.0"
        fi
        EXTRACTED_KSRC="/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-${DSM_VERSION}/build/"
    fi
else
    if [[ "${ACTION}" != "del" && "${ACTION}" != "add" && "${ACTION}" != "sn" && "${ACTION}" != "clean" ]]; then
        echo "All is not supported for action \"${ACTION}\""
        exit 1
    fi
fi

case "${ACTION}" in
    add)    __ext_add "${2}"
            ;;
    del)    __ext_del "${2}"
            echo -e "Extension ID '${2}' not found:\n---------------------\n${EXTENSION_IDS}"
            exit 1
            ;;
    build)  if [ "${COMPILE_WITH}" == "kernel" ];then
                downloadFromUrlIfNotExists "${KERNEL_DOWNLOAD_URL}" "${DOWNLOAD_FOLDER}/${TARGET_PLATFORM}.${KERNEL_FILENAME}" "Kernel"
            else
                downloadFromUrlIfNotExists "${TOOLKIT_DEV_DOWNLOAD_URL}" "${DOWNLOAD_FOLDER}/${TOOLKIT_DEV_FILENAME}" "Toolkit Dev"
            fi
            buildImage
            if [ "${AUTO_CLEAN}" == "true" ]; then
                clean
            fi
            ;;
    run)    runContainer "run"
            ;;
    pat)    runContainer "pat"
            ;;
    auto)   runContainer "auto"
            ;;
    clean)  clean
            ;;
    sn)     ./serialnumbergen.sh `echo "${2}" | tr 'a-z' 'A-Z' | sed -e 's/P/+/' -e 's/XS/xs/'`
            ;;
    *)      if [ ! -z ${ACTION} ];then
                echo "Error: action ${ACTION} does not exist"
                echo ""
            fi
            showHelp
            exit 1
            ;;
esac
