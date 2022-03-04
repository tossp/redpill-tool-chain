# RedPill Tool Chain

这是一个测试项目，可能会有不可预测的事情发生（比如：毁损数据、烧毁硬件等等），请**谨慎使用**。

[English](README_en.md "English")

感谢 @haydibe 提供 RedPill Tool Chain

## 关于项目?

- 基于[RedPill-TTG](https://github.com/RedPill-TTG)源码制作
- 为apollolake提供适当的DSM7支持 ( 感谢 [@jumkey](https://github.com/jumkey) )
- 整理社区扩展驱动 ( 感谢 [@pocopico](https://github.com/pocopico) )
- `redpill_lkm_make_target`字段的可选值有 `dev-v6`, `dev-v7`, `test-v6`, `test-v7`, `prod-v6` 或者 `prod-v7`，
  需要注意后缀为`-v6`的值用于 DSM6 版本构建， 需要注意后缀为`-v7`的值用于 DSM7 版本构建. 默认使用的是 `dev-v6` 和 `dev-v7`。

> PS: 由于toolkit dev缺少fs/proc所需的源代码，因此它们取自提取的DSM6.2.4内核源代码。
构建需要此单个文件夹的源代码，但不使用内核源代码构建redpill.ko模块。

如果您发现工具链的构建方式有问题或者有改进的想法，请让我知道。

对于所有其他问题：请向社区提出——我知道的并不比其他人多。

## 如何使用?

1. 复制`sample_user_config.json`为`bromolow_user_config.json`或者`apollolake_user_config.json`
1. 编辑`<platform>_user_config.json`比如 918+ 就编辑 `apollolake_user_config.json` 文件
1. 添加扩展驱动：
   比如 `redpill_tool_chain.sh add https://raw.githubusercontent.com/pocopico/rp-ext/master/mpt3sas/rpext-index.json`
1. 为你想要的平台和版本构建编译镜像:  
   比如 `redpill_tool_chain.sh build apollolake-7.0-41890`
1. 为你想要的平台和版本构建引导:
   比如 `redpill_tool_chain.sh auto apollolake-7.0-41890`

`redpill_tool_chain.sh auto`运行结束之后，将会在宿主机的`./image`文件夹中生成 RedPill引导镜像。

`<platform>_user_config.json`文件中的`extensions`字段保持为空，会自动打包所有已安装的自定义驱动。
自定义驱动请按需添加，尽量不要加载无关驱动，否则会因为扩展驱动太大导致打包失败。

依赖: `docker`

## 快捷说明

- `docker/Dockerfile` 中补入了阿里云镜像
- `redpill_tool_chain.sh add <URL>`添加扩展驱动
- `redpill_tool_chain.sh del <ID>`删除扩展驱动
- `redpill_tool_chain.sh run <platform_version>`自定义引导构建过程
- 使用`synoboot.sh`写入引导

### 自定义扩展驱动管理

- 安装 thethorgroup.virtio    : `./redpill_tool_chain.sh add https://github.com/jumkey/redpill-load/raw/develop/redpill-virtio/rpext-index.json`
- 安装 thethorgroup.boot-wait : `./redpill_tool_chain.sh add https://github.com/jumkey/redpill-load/raw/develop/redpill-boot-wait/rpext-index.json`
- 安装 pocopico.mpt3sas       : `./redpill_tool_chain.sh add https://raw.githubusercontent.com/pocopico/rp-ext/master/mpt3sas/rpext-index.json`
- 移除 pocopico.mpt3sas       : `./redpill_tool_chain.sh del pocopico.mpt3sas`
- 安装 jumkey.dtb             : `./redpill_tool_chain.sh add https://github.com/jumkey/redpill-load/raw/develop/redpill-dtb/rpext-index.json`
- 移除 jumkey.dtb             : `./redpill_tool_chain.sh del jumkey.dtb`

[获取更多扩展驱动...](https://github.com/pocopico/rp-ext)

### 构建工具链镜像

- `./redpill_tool_chain.sh build bromolow-6.2.4-25556`
- `./redpill_tool_chain.sh build bromolow-7.0-41222`
- `./redpill_tool_chain.sh build apollolake-6.2.4-25556`
- `./redpill_tool_chain.sh build apollolake-7.0-41890`

### 制作 redpill 引导镜像

- `./redpill_tool_chain.sh auto bromolow-6.2.4-25556`
- `./redpill_tool_chain.sh auto bromolow-7.0-41222`
- `./redpill_tool_chain.sh auto apollolake-6.2.4-25556`
- `./redpill_tool_chain.sh auto apollolake-7.0-41890`

### Clean old redpill bootloader images and build cache

- `./redpill_tool_chain.sh clean bromolow-6.2.4-25556`
- `./redpill_tool_chain.sh clean bromolow-7.0-41222`
- `./redpill_tool_chain.sh clean apollolake-6.2.4-25556`
- `./redpill_tool_chain.sh clean apollolake-7.0-41890`
- `./redpill_tool_chain.sh clean all`

### 查看帮助文本

```txt
./redpill_tool_chain.sh
Usage: ./redpill_tool_chain.sh <action> <platform version>

Actions: build, auto, run, clean

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

Available platform versions:
---------------------
bromolow-6.2.4-25556
bromolow-7.0-41222
bromolow-7.0.1-42218
apollolake-6.2.4-25556
apollolake-7.0-41890
apollolake-7.0.1-42218
broadwell-7.0.1-42218
broadwellnk-7.0.1-42218
geminilake-7.0.1-42218

Custom Extensions:
---------------------
pocopico.mpt3sas
thethorgroup.boot-wait
thethorgroup.virtio
```

## 更多细节

编译`geminilake`需要加入`jumkey.dtb`扩展并参考[这里](https://github.com/jumkey/redpill-load/blob/develop/redpill-dtb/README.md)创建设备的二进制设备树

查看基于[test.yml](https://github.com/tossp/redpill-tool-chain/blob/master/.github/workflows/test.yml)的使用[示例](https://github.com/tossp/redpill-tool-chain/actions/workflows/test.yml)
