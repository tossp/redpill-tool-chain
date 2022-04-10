#!/usr/bin/env bash

set -u

if [ ${TARGET_REVISION} -lt 42218 ];then
  exit 0
fi

cat ./redpill-load/build-loader.sh | head -n `expr -1 + $(sed -n '/Printing config variables/=' ./redpill-load/build-loader.sh)` > ./redpill-load/_helper.sh
. ./redpill-load/_helper.sh "${TARGET_NAME}" "${TARGET_VERSION}-${TARGET_REVISION}"
rm ./_helper.sh

# Repacks tar-like file
#
# Args: $1 directory to unpack (must exist) | $2 file path | $3 should hard fail on error? [default=1]
brp_repack_tar()
{
  pr_process "Repacking %s file form %s" "${2}" "${1}"

  local output;
  output=$("${TAR_PATH}" -czf "${2}" -C "${1}" . 2>&1)
  if [ $? -ne 0 ]; then
    pr_process_err

    if [[ "${3:-1}" -ne 1 ]]; then
      pr_err "Failed to unpack tar\n\n%s" "${output}"
      return 1
    else
      pr_crit "Failed to unpack tar\n\n%s" "${output}"
    fi
  fi

  pr_process_ok
}

readonly extract_bin='/usr/local/bin/syno_extract_system_patch'
make_extract(){
  archive="$1"
  if [ ! -f "${extract_bin}" ]; then
    pr_dbg "%s not found - preparing" "${extract_bin}"
    if [ ! -f "${EXTRACT_PAT_FILE}" ]; then
      rpt_download_remote "${EXTRACT_PAT_URL}" "${EXTRACT_PAT_FILE}"
    else
      pr_dbg "Found existing PAT at %s - skipping download" "${EXTRACT_PAT_FILE}"
    fi
    pr_dbg "Found syno_extract_system_patch File not found - preparing" "${extract_bin}"
    brp_mkdir /tmp/synoesp && brp_unpack_tar "${EXTRACT_PAT_FILE}" "/tmp/synoesp"
    brp_mkdir /tmp/extract && brp_unpack_zrd "/tmp/synoesp/rd.gz" "/tmp/extract"
    cp /tmp/extract/usr/lib/{libcurl.so.4,libmbedcrypto.so.5,libmbedtls.so.13,libmbedx509.so.1,libmsgpackc.so.2,libsodium.so,libsynocodesign-ng-virtual-junior-wins.so.7} /usr/local/lib
    cp /tmp/extract/usr/syno/bin/scemd ${extract_bin}
    rm -rf /tmp/synoesp /tmp/extract
  else
    pr_dbg "Found syno_extract_system_patch File at %s - skipping nake" "${extract_bin}"
  fi

  pr_process "Use syno_extract_system_patch extract PAT"
  LD_LIBRARY_PATH=/usr/local/lib ${extract_bin} "${BRP_PAT_FILE}" /tmp/pat && pr_process_ok || pr_process_err

  brp_repack_tar "/tmp/pat/" /tmp/repack.tar.gz

  pr_process "New checksum of PAT %s - Patch the PAT checksum" ${BRP_PAT_FILE}
  mv ${BRP_PAT_FILE} ${BRP_PAT_FILE}.org && mv /tmp/repack.tar.gz ${BRP_PAT_FILE} && rm -rf "/tmp/pat"
  sum=`sha256sum ${BRP_PAT_FILE} | awk '{print $1}'`
  old_sum="$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.sha256")"
  sed -i "s/${old_sum}/${sum}/" "${BRP_REL_CONFIG_JSON}"
  rm -rf /tmp/pat
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
# fix redo
readonly BRP_PAT_FILE="${BRP_CACHE_DIR}/${BRP_REL_OS_ID}.pat"
readonly EXTRACT_PAT_FILE="${BRP_CACHE_DIR}/extract.tar.gz"
readonly EXTRACT_PAT_URL='https://global.download.synology.com/download/DSM/release/7.0.1/42218/DSM_DS3615xs_42218.pat'

if [ -f "${BRP_PAT_FILE}.org" ] && [ -f "${BRP_PAT_FILE}" ]; then
  pr_info "Found patched PAT file - Patch the PAT checksum"
  file_sum="$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.sha256")"
  new_sum=`sha256sum "${BRP_PAT_FILE}" | awk '{print $1}'`
  org_sum=`sha256sum "${BRP_PAT_FILE}.org" | awk '{print $1}'`
  if [ "$new_sum" != "$file_sum" ]  && [ "$org_sum" == "$file_sum" ]; then
    sed -i "s/${org_sum}/${new_sum}/" "${BRP_REL_CONFIG_JSON}"
  fi
fi


if [ ! -d "${BRP_UPAT_DIR}" ]; then
  pr_dbg "Unpacked PAT %s not found - preparing" "${BRP_UPAT_DIR}"

  brp_mkdir "${BRP_UPAT_DIR}"

  if [ ! -f "${BRP_PAT_FILE}" ]; then
    rpt_download_remote "$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.pat_url")" "${BRP_PAT_FILE}"
  else
    pr_dbg "Found existing PAT at %s - skipping download" "${BRP_PAT_FILE}"
  fi

  brp_verify_file_sha256 "${BRP_PAT_FILE}" "$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.sha256")"

  check_pat "${BRP_PAT_FILE}"
  exec_status=$?
  pr_info "Test encryption pat results %s" "${exec_status}"
  if [ "$exec_status" -eq 1 ]; then
    pr_empty_nl
    make_extract "${BRP_PAT_FILE}"
  fi
else
  pr_info "Found unpacked PAT at \"%s\" - skipping unpacking" "${BRP_UPAT_DIR}"
fi

