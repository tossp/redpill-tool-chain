ARG DOCKER_BASE_IMAGE=ubuntu:20.04
# extract kernel and toolkit dev
FROM ${DOCKER_BASE_IMAGE} AS extract

ARG KERNEL_SRC_FILENAME
ADD downloads/${KERNEL_SRC_FILENAME} /

# tool chain image
FROM ${DOCKER_BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed  -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    sed  -i "s/security.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    apt-get update && \    
    apt-get install --yes --no-install-recommends ca-certificates build-essential git libssl-dev curl cpio bspatch vim gettext bc bison flex dosfstools kmod jq && \
    rm -rf /var/lib/apt/lists/* /tmp/*

ARG REDPILL_LKM_REPO=https://github.com/RedPill-TTG/redpill-lkm.git
ARG REDPILL_LKM_BRANCH=master
ARG REDPILL_LKM_SRC=/opt/redpill-lkm

ARG REDPILL_LOAD_REPO=https://github.com/RedPill-TTG/redpill-load.git
ARG REDPILL_LOAD_BRANCH=master
ARG REDPILL_LOAD_SRC=/opt/redpill-load

RUN git clone --depth 1 ${REDPILL_LKM_REPO} -b ${REDPILL_LKM_BRANCH}  ${REDPILL_LKM_SRC} && \
    git clone --depth 1 ${REDPILL_LOAD_REPO} -b ${REDPILL_LOAD_BRANCH} ${REDPILL_LOAD_SRC}

ARG TARGET_PLATFORM
ARG TARGET_VERSION
ARG DSM_VERSION
ARG COMPILE_WITH
ARG TARGET_REVISION

ENV ARCH=x86_64 \
    LINUX_SRC=${REDPILL_LKM_SRC}/${COMPILE_WITH}-${TARGET_PLATFORM}-${TARGET_VERSION}-${TARGET_REVISION} \
    REDPILL_LKM_SRC=${REDPILL_LKM_SRC} \
    REDPILL_LOAD_SRC=${REDPILL_LOAD_SRC} \
    TARGET_PLATFORM=${TARGET_PLATFORM} \
    TARGET_VERSION=${TARGET_VERSION} \
    TARGET_REVISION=${TARGET_REVISION}

ARG EXTRACTED_KSRC
COPY --from=extract ${EXTRACTED_KSRC} ${LINUX_SRC}

RUN if [ "apollolake" = "$TARGET_PLATFORM" ]; then echo '+' > ${LINUX_SRC}/.scmversion; fi && \
    if [ "$COMPILE_WITH" = "kernel" ]; then \
        cp ${LINUX_SRC}/synoconfigs/${TARGET_PLATFORM} ${LINUX_SRC}/.config && \
        make -C ${LINUX_SRC} oldconfig && \
        make -C ${LINUX_SRC} modules_prepare ;\
    fi

WORKDIR "/opt"

COPY Makefile /opt/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]