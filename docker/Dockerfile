ARG DOCKER_BASE_IMAGE=debian:8
# extract kernel and toolkit dev
FROM ${DOCKER_BASE_IMAGE} AS extract

ARG KERNEL_SRC_FILENAME
ADD downloads/${KERNEL_SRC_FILENAME} /

# tool chain image
FROM ${DOCKER_BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

# RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
#     sed  -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
#     sed  -i "s/security.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
#     sed  -i "s/deb.debian.org/mirrors.aliyun.com/g" /etc/apt/sources.list && \
#     sed  -i "s/security.debian.org/mirrors.aliyun.com/g" /etc/apt/sources.list

RUN apt-get update && \
    apt-get install --yes --no-install-recommends ca-certificates build-essential git libssl-dev curl cpio bspatch vim gettext bc bison flex dosfstools kmod && \
    rm -rf /var/lib/apt/lists/* /tmp/* && \
    curl --progress-bar --output /usr/bin/jq --location https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod +x /usr/bin/jq

ARG REDPILL_LKM_REPO=https://github.com/RedPill-TTG/redpill-lkm.git
ARG REDPILL_LKM_BRANCH=master
ARG REDPILL_LKM_SRC=/opt/redpill-lkm

ARG REDPILL_LOAD_REPO=https://github.com/RedPill-TTG/redpill-load.git
ARG REDPILL_LOAD_BRANCH=master
ARG REDPILL_LOAD_SRC=/opt/redpill-load

RUN git clone ${REDPILL_LKM_REPO}  -b ${REDPILL_LKM_BRANCH}  ${REDPILL_LKM_SRC} && \
    git clone ${REDPILL_LOAD_REPO} -b ${REDPILL_LOAD_BRANCH} ${REDPILL_LOAD_SRC}

ARG TARGET_NAME
ARG TARGET_PLATFORM
ARG TARGET_VERSION
ARG DSM_VERSION
ARG COMPILE_WITH
ARG TARGET_REVISION
ARG REDPILL_LKM_MAKE_TARGET

LABEL redpill-tool-chain=${TARGET_PLATFORM}-${TARGET_VERSION}-${TARGET_REVISION}

ENV ARCH=x86_64 \
    LINUX_SRC=/opt/${COMPILE_WITH}-${TARGET_PLATFORM}-${TARGET_VERSION}-${TARGET_REVISION} \
    REDPILL_LKM_SRC=${REDPILL_LKM_SRC} \
    REDPILL_LOAD_SRC=${REDPILL_LOAD_SRC} \
    TARGET_NAME=${TARGET_NAME} \
    TARGET_PLATFORM=${TARGET_PLATFORM} \
    TARGET_VERSION=${TARGET_VERSION} \
    TARGET_REVISION=${TARGET_REVISION} \
    REDPILL_LKM_MAKE_TARGET=${REDPILL_LKM_MAKE_TARGET}

ARG EXTRACTED_KSRC
COPY --from=extract ${EXTRACTED_KSRC} ${LINUX_SRC}

RUN if [ "apollolake" = "$TARGET_PLATFORM" ] || [ "broadwellnk" = "$TARGET_PLATFORM"  ] || [ "geminilake" = "$TARGET_PLATFORM" ] || [ "v1000" = "$TARGET_PLATFORM" ] || [ "denverton" = "$TARGET_PLATFORM" ]; then echo '+' > ${LINUX_SRC}/.scmversion; fi && \
    if [ "$COMPILE_WITH" = "kernel" ]; then \
        cp ${LINUX_SRC}/synoconfigs/${TARGET_PLATFORM} ${LINUX_SRC}/.config && \
        make -C ${LINUX_SRC} oldconfig && \
        make -C ${LINUX_SRC} modules_prepare ;\
    fi

WORKDIR "/opt"

COPY Makefile /opt/

COPY entrypoint.sh /entrypoint.sh
COPY helper.sh ./
RUN chmod +x /entrypoint.sh  && chmod +x ./helper.sh

ENTRYPOINT [ "/entrypoint.sh" ]
