#!/usr/bin/env bash

cd $(dirname $(readlink -f "$0"))

S='images/redpill-*'
T='/dev/synoboot'
IMG_FILE=`ls -lt ${S} 2>/dev/null | awk 'NR==1{print $9}'`

if [ ! -b "${T}" ];then
    echo "目标地址不存在:${T}"
    exit 1
fi


if [ -f "${IMG_FILE}" ];then
    echo "准备写入镜像:${PWD}/${IMG_FILE}"
    echo "到设备:${T}"
    # dd if="${IMG_FILE}" of="${T}" bs=4M conv=nocreat oflag=sync status=progress
else
    echo "不是有效的文件:${IMG_FILE}"
    ls -lt ${S}
fi
