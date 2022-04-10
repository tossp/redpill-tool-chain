#!/usr/bin/env bash

set -u

##### BASIC RUNTIME VALIDATION #########################################################################################
# shellcheck disable=SC2128
if [ -z "${BASH_SOURCE}" ] ; then
    echo "You need to execute this script using bash v4+ without using pipes"
    exit 1
fi

cd "${BASH_SOURCE%/*}/" || exit 1
########################################################################################################################

##### CONFIGURATION YOU CAN OVERRIDE USING ENVIRONMENT #################################################################
BRP_JUN_MOD=${BRP_JUN_MOD:-0} # whether you want to use jun's mod
BRP_DEBUG=${BRP_DEBUG:-0} # whether you want to see debug messages
BRP_CACHE_DIR=${BRP_CACHE_DIR:-"$PWD/redpill-load/cache"} # cache directory where stuff is downloaded & unpacked
BRP_USER_CFG=${BRP_USER_CFG:-"$PWD/redpill-load/user_config.json"}
BRP_BUILD_DIR=${BRP_BUILD_DIR:-''} # makes sure attempts are unique; do not override this unless you're using repack
BRP_KEEP_BUILD=${BRP_KEEP_BUILD:-''} # will be set to 1 for repack method or 0 for direct
BRP_LINUX_PATCH_METHOD=${BRP_LINUX_PATCH_METHOD:-"direct"} # how to generate kernel image (direct bsp patch vs repack)
BRP_LINUX_SRC=${BRP_LINUX_SRC:-''} # used for repack method
BRP_BOOT_IMAGE=${BRP_BOOT_IMAGE:-"$PWD/redpill-load/ext/boot-image-template.img.gz"} # gz-ed "template" image to base final image on
# you can also set RPT_EXTS_DIR as it's used by ext-manager
RPT_BUNDLED_EXTS_CFG=${RPT_BUNDLED_EXTS_CFG:-"$PWD/redpill-load/bundled-exts.json"} # file with list of bundled extensions

# The options below are meant for debugging only. Setting them will create an image which is not normally usable
BRP_DEV_DISABLE_RP=${BRP_DEV_DISABLE_RP:-0} # when set to 1 the rp.ko will be renamed to rp-dis.ko
BRP_DEV_DISABLE_SB=${BRP_DEV_DISABLE_SB:-0} # when set to 1 the synobios.ko will be renamed to synobios-dis.ko
BRP_DEV_DISABLE_EXTS=${BRP_DEV_DISABLE_EXTS:-0} # when set 1 all extensions will be disabled (and not included in image)
########################################################################################################################

##### INCLUDES #########################################################################################################
. redpill-load/include/log.sh # logging helpers
. redpill-load/include/text.sh # text manipulation
. redpill-load/include/runtime.sh # need to include this early so we can used date and such
. redpill-load/include/json.sh # json parsing routines
. redpill-load/include/config-manipulators.sh
. redpill-load/include/file.sh # file-related operations (copying/moving/unpacking etc)
. redpill-load/include/patch.sh # helpers for patching files using patch(1) and bspatch(1)
. redpill-load/include/boot-image.sh # helper functions for dealing with the boot image
. redpill-load/include/ext-bridge.sh # helper to interact with extensions manager
########################################################################################################################

##### CONFIGURATION VALIDATION##########################################################################################

### Command line params handling
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "Usage: $0 platform version <output-file>"
  exit 1
fi
BRP_HW_PLATFORM="$1"
BRP_SW_VERSION="$2"
BRP_OUTPUT_FILE="${3:-"$PWD/redpill-load/images/redpill-${BRP_HW_PLATFORM}_${BRP_SW_VERSION}_b$(date '+%s').img"}"

BRP_REL_CONFIG_BASE="$PWD/redpill-load/config/${BRP_HW_PLATFORM}/${BRP_SW_VERSION}"
BRP_REL_CONFIG_JSON="${BRP_REL_CONFIG_BASE}/config.json"

### Some config validation
if [ "${BRP_LINUX_PATCH_METHOD}" == "direct" ]; then
  BRP_BUILD_DIR=${BRP_BUILD_DIR:-"$PWD/redpill-load/build/$(date '+%s')"}
  BRP_KEEP_BUILD=${BRP_KEEP_BUILD:='0'}
elif [ "${BRP_LINUX_PATCH_METHOD}" == "repack" ]; then
  if [ -z ${BRP_BUILD_DIR} ]; then
    pr_crit "You've chosen \"%s\" method for patching - you must specify BRP_BUILD_DIR" "${BRP_LINUX_PATCH_METHOD}"
  fi
  BRP_KEEP_BUILD=${BRP_KEEP_BUILD:='1'}

  if [ -z ${BRP_LINUX_SRC} ]; then
    pr_crit "You've chosen \"repack\" method for patching - you must specify BRP_LINUX_SRC" "${BRP_LINUX_PATCH_METHOD}"
  fi

  if [ ! -f "${BRP_LINUX_SRC}/Kbuild"  ]; then
    pr_crit "BRP_LINUX_SRC=%s doesn't look like are valid Linux source tree (Kbuild not present)" "${BRP_LINUX_SRC}"
  fi

  if [ ! -f "${BRP_LINUX_SRC}/.config"  ]; then
    pr_crit "Kernel configuration file (%s/.config) doesn't exist - create one (or copy existing one)" "${BRP_LINUX_SRC}"
  fi
else
  pr_crit "BRP_LINUX_PATCH_METHOD=%s is not are valid value: {direct|repack}" "${BRP_LINUX_PATCH_METHOD}"
fi

if [ ! -f "${BRP_USER_CFG}" ]; then
  pr_crit "User config (BRP_USER_CFG) \"%s\" doesn't exist" "${BRP_USER_CFG}"
fi
brp_json_validate "${BRP_USER_CFG}"

if [ ! -f "${BRP_REL_CONFIG_JSON}" ]; then
  pr_crit "There doesn't seem to be a config for %s platform running %s (checked %s)" \
          "${BRP_HW_PLATFORM}" "${BRP_SW_VERSION}" "${BRP_REL_CONFIG_JSON}"
fi
brp_json_validate "${BRP_REL_CONFIG_JSON}"

### Here we define some common/well-known paths used later, as well as the map for resolving path variables in configs
readonly BRP_REL_OS_ID=$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.id")
readonly BRP_UPAT_DIR="${BRP_BUILD_DIR}/pat-${BRP_REL_OS_ID}-unpacked" # unpacked pat directory
readonly BRP_EXT_DIR="$PWD/ext" # a directory with external tools/files/modules
readonly BRP_COMMON_CFG_BASE="$PWD/config/_common" # a directory with common configs & patches sable for many platforms
readonly BRP_USER_DIR="$PWD/custom"
# vars map for copying files from release configs. If you're changing this please add to docs!
typeset -r -A BRP_RELEASE_PATHS=(
  [@@@_DEF_@@@]="${BRP_REL_CONFIG_BASE}"
  [@@@PAT@@@]="${BRP_UPAT_DIR}"
  [@@@COMMON@@@]="${BRP_COMMON_CFG_BASE}"
  [@@@EXT@@@]="${BRP_EXT_DIR}"
)
# vars map for copying files from user config. If you're changing this please add to docs!
typeset -r -A BRP_USER_PATHS=(
  [@@@_DEF_@@@]="${BRP_USER_DIR}"
)

### Load metadata about extensions
typeset -a RPT_BUNDLED_EXTS_IDS # ordered IDs of bundled extensions
typeset -A RPT_BUNDLED_EXTS # k=>v extensions to their index urls
RPT_BUILD_EXTS='' # by default it's empty == all
RPT_USER_EXTS=''
if [[ "${BRP_DEV_DISABLE_EXTS}" -ne 1 ]]; then
  RPT_USER_EXTS=$(rpt_load_user_extensions "${BRP_USER_CFG}") || exit 1
  rpt_load_bundled_extensions "${RPT_BUNDLED_EXTS_CFG}" RPT_BUNDLED_EXTS_IDS RPT_BUNDLED_EXTS
  if [[ ! -z "${RPT_USER_EXTS}" ]]; then # if user defined some extensions we need to whitelist bundled + user picked
    for ext_id in ${RPT_BUNDLED_EXTS_IDS[@]+"${RPT_BUNDLED_EXTS_IDS[@]}"}; do
      if [[ ! -z "${RPT_BUILD_EXTS}" ]]; then
        RPT_BUILD_EXTS+=','
      fi
      RPT_BUILD_EXTS+="${ext_id}"
    done
    RPT_BUILD_EXTS+=",${RPT_USER_EXTS}"
  fi
fi

pr_dbg "******** Printing config variables ********"
pr_dbg "Cache dir: %s" "$BRP_CACHE_DIR"
pr_dbg "Build dir: %s" "$BRP_BUILD_DIR"
pr_dbg "Ext dir: %s" "$BRP_EXT_DIR"
pr_dbg "User custom dir: %s" "$BRP_USER_DIR"
pr_dbg "User config: %s" "$BRP_USER_CFG"
pr_dbg "Keep build dir? %s" "$BRP_KEEP_BUILD"
pr_dbg "Linux patch method: %s" "$BRP_LINUX_PATCH_METHOD"
pr_dbg "Linux repack src: %s" "$BRP_LINUX_SRC"
pr_dbg "Hardware platform: %s" "$BRP_HW_PLATFORM"
pr_dbg "Software version: %s" "$BRP_SW_VERSION"
pr_dbg "Image template: %s" "$BRP_BOOT_IMAGE"
pr_dbg "Image destination: %s" "$BRP_OUTPUT_FILE"
pr_dbg "Common cfg base: %s" "$BRP_COMMON_CFG_BASE"
pr_dbg "Release cfg base: %s" "$BRP_REL_CONFIG_BASE"
pr_dbg "Release cfg JSON: %s" "$BRP_REL_CONFIG_JSON"
pr_dbg "Release id: %s" "$BRP_REL_OS_ID"
if [[ "${BRP_DEV_DISABLE_EXTS}" -ne 1 ]]; then
  pr_dbg "User extensions [empty means all]: %s" "$RPT_USER_EXTS"
  pr_dbg "Selected extensions [empty means all]: %s" "$RPT_BUILD_EXTS"
else
  pr_warn "User extensions: <disabled>"
  pr_warn "Selected extensions: <all disabled>"
fi
pr_dbg "*******************************************"

########################################################## 读取环境参数完成

# BRP_DEBUG=1 ./helper.sh "DS918+" "7.1.0-42661"

readonly EXTRACT_PAT_FILE="${BRP_CACHE_DIR}/extract.tar.gz"
make_extract(){
  archive="$1"
  if [ ! -f "${EXTRACT_PAT_FILE}" ]; then
    readonly EXTRACT_PAT_URL='https://global.download.synology.com/download/DSM/release/7.0.1/42218/DSM_DS3622xs%2B_42218.pat'
    pr_info "PAT file %s not found - downloading from %s" "${EXTRACT_PAT_FILE}" "${EXTRACT_PAT_URL}"
    "${CURL_PATH}" --output "${EXTRACT_PAT_FILE}" "${EXTRACT_PAT_URL}"
  else
    pr_dbg "Found existing PAT at %s - skipping download" "${EXTRACT_PAT_FILE}"
  fi
  mkdir synoesp
  tar -C./synoesp/ -xf "${EXTRACT_PAT_FILE}" rd.gz
  cd synoesp
  xz -dc < rd.gz >rd 2>/dev/null && echo "extract rd.gz" || echo error
  cpio -idm <rd 2>&1 && echo "extract rd" || echo error
  mkdir extract && cd extract
  cp ../usr/lib/libcurl.so.4 ../usr/lib/libmbedcrypto.so.5 ../usr/lib/libmbedtls.so.13 ../usr/lib/libmbedx509.so.1 ../usr/lib/libmsgpackc.so.2 ../usr/lib/libsodium.so ../usr/lib/libsynocodesign-ng-virtual-junior-wins.so.7  /usr/local/lib
  cp ../usr/syno/bin/scemd /usr/local/bin/syno_extract_system_patch
  cd ../..
  mkdir pat
  LD_LIBRARY_PATH=/usr/local/lib /usr/local/bin/syno_extract_system_patch "${BRP_PAT_FILE}" pat || pr_info "extract latest pat"
  cd pat
  pr_process "Repacked PAT %s" ${BRP_PAT_FILE}
  pr_empty_nl
  "${TAR_PATH}" -czf archive.tar.gz ./
  mv ${BRP_PAT_FILE} ${BRP_PAT_FILE}.org
  mv archive.tar.gz ${BRP_PAT_FILE}
  cd ../
  rm -rf pat synoesp
  sum=`sha256sum ${BRP_PAT_FILE} | awk '{print $1}'`
  pr_info "The new checksum -  %s" "${sum}"

  old_sum="$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.sha256")"
  sed -i "s/${old_sum}/${sum}/" "${BRP_REL_CONFIG_JSON}"
  pr_process_ok
}

check_pat() {
  archive="$1"
  archiveheader="$(od -bc ${archive} | head -1 | awk '{print $3}')"
  return_value=0
  case ${archiveheader} in
  105)
      pr_dbg "${archive}, is a Tar file"
      ;;
  255)
      pr_info "File ${archive}, Decryption required"
      return_value=1
      ;;
  213)
      pr_dbg "File ${archive}, is a compressed tar"
      ;;
  *)
      pr_process_err

      pr_err  "Could not determine if file ${archive} is encrypted or not, maybe corrupted"
      ls -ltr ${archive}
      pr_crit "${archiveheader}"
      return_value=99
      ;;
  esac
  return $return_value
}

##########################################################
readonly BRP_PAT_FILE="${BRP_CACHE_DIR}/${BRP_REL_OS_ID}.pat"
if [ ! -d "${BRP_UPAT_DIR}" ]; then
  pr_dbg "Unpacked PAT %s not found - preparing" "${BRP_UPAT_DIR}"

  brp_mkdir "${BRP_UPAT_DIR}"

  if [ ! -f "${BRP_PAT_FILE}" ]; then
    readonly BRP_PAT_URL=$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.pat_url")
    pr_info "PAT file %s not found - downloading from %s" "${BRP_PAT_FILE}" "${BRP_PAT_URL}"
    "${CURL_PATH}" --output "${BRP_PAT_FILE}" "${BRP_PAT_URL}"
  else
    pr_dbg "Found existing PAT at %s - skipping download" "${BRP_PAT_FILE}"
  fi

  brp_verify_file_sha256 "${BRP_PAT_FILE}" "$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.sha256")"

  check_pat "${BRP_PAT_FILE}"
  exec_status=$?
  pr_info "Test encryption pat results %s" "${exec_status}"
  if [ "$exec_status" -eq 1 ]; then
    make_extract "${BRP_PAT_FILE}"
  fi
  brp_unpack_tar "${BRP_PAT_FILE}" "${BRP_UPAT_DIR}"
else
  pr_info "Found unpacked PAT at \"%s\" - skipping unpacking" "${BRP_UPAT_DIR}"
fi


if [ "${BRP_KEEP_BUILD}" -eq 0 ]; then
  "${RM_PATH}" -rf "${BRP_BUILD_DIR}"
fi
