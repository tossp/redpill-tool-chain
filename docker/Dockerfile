ARG DOCKER_BASE_IMAGE=debian:8
# extract kernel and toolkit dev
FROM ${DOCKER_BASE_IMAGE} AS extract

ARG TOOLKIT_DEV_FILENAME
ADD downloads/${TOOLKIT_DEV_FILENAME} /

ARG KERNEL_FILENAME
ADD downloads/${KERNEL_FILENAME} /

# tool chain image
FROM ${DOCKER_BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed  -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    sed  -i "s/security.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    apt-get update && \    
    apt-get install --yes --no-install-recommends ca-certificates build-essential git libssl-dev curl cpio bspatch vim gettext bc bison flex dosfstools kmod bsdiff patch jq xz-utils && \
    rm -rf /var/lib/apt/lists/* /tmp/*

ARG TOOLCHAIN_FILENAME
ADD downloads/${TOOLCHAIN_FILENAME} /opt/

ARG REDPILL_LKM_REPO=https://github.com/RedPill-TTG/redpill-lkm.git
ARG REDPILL_LKM_BRANCH=master
RUN git clone ${REDPILL_LKM_REPO} -b ${REDPILL_LKM_BRANCH} /opt/redpill-lkm

ARG REDPILL_LOAD=https://github.com/RedPill-TTG/redpill-load.git
ARG REDPILL_LOAD_BRANCH=master
RUN git clone ${REDPILL_LOAD} -b ${REDPILL_LOAD_BRANCH} /opt/redpill-load

ARG TARGET_VERSION
ARG TARGET_PLATFORM
COPY --from=extract /usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-${TARGET_VERSION}/build /opt/redpill-lkm/kernel-${TARGET_PLATFORM}-${TARGET_VERSION}
COPY --from=extract /linux*/fs/proc/ /opt/redpill-lkm/kernel-${TARGET_PLATFORM}-${TARGET_VERSION}/fs/proc/

WORKDIR "/opt"

COPY Makefile user_config.json.template /opt/
ARG BUILD_REDPILL_LOADER_VERSION
ARG USERCONFIG_VID=<fill me>
ARG USERCONFIG_PID=<fill me>
ARG USERCONFIG_SN=<fill me>
ARG USERCONFIG_MAC1=<fill me>

#    LINUX_SRC=/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-${TARGET_VERSION}/build \

ENV ARCH=x86_64 \
    CROSS_COMPILE=/opt/x86_64-pc-linux-gnu/bin/x86_64-pc-linux-gnu- \
    LINUX_SRC=/opt/redpill-lkm/kernel-${TARGET_PLATFORM}-${TARGET_VERSION} \
    TARGET_PLATFORM=${TARGET_PLATFORM} \
    BUILD_REDPILL_LOADER_VERSION=${BUILD_REDPILL_LOADER_VERSION} \
    USERCONFIG_VID=${USERCONFIG_VID} \
    USERCONFIG_PID=${USERCONFIG_PID} \
    USERCONFIG_SN=${USERCONFIG_SN} \
    USERCONFIG_MAC1=${USERCONFIG_MAC1}

CMD ["bash"]