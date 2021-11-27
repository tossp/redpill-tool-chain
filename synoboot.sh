#!/usr/bin/env bash

T='/dev/synoboot'
S='images/redpill-DS[39]*.img'

cd $(dirname $(readlink -f "$0"))

IMG_FILE=`ls -lt ${S} 2>/dev/null | awk 'NR==1{print $9}'`

if [ ! -b "${T}" ];then
    echo -e "The target block device address does not exist:\t${T}"
    exit 1
fi

if [ ! -f "${IMG_FILE}" ];then
    echo -e "Is not a valid file:\t${IMG_FILE}"
    ls -lt ${S}
    exit 1
fi

echo -e "Boot image:\t\t${PWD}/${IMG_FILE}"
echo -e "Target block device:\t${T}"
dd if="${IMG_FILE}" of="${T}" bs=4M conv=nocreat oflag=sync status=progress

