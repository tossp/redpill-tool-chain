# RedPill Tool Chain

这是一个测试项目，可能会有不可预测的事情发生（比如：毁损数据、烧毁硬件等等），请**谨慎使用**。

[English](README_EN.md "English")

感谢 @haydibe 提供 RedPill Tool Chain

# 关于项目?

- 基于[红丸团队](https://github.com/RedPill-TTG)源码制作
- 为apollolake提供适当的DSM7支持 (thnx @jumkey)
- 针对DSM6.2.4和DSM7.0从基于内核源代码的构建切换到基于工具包开发人员的构建 (thnx [@jumkey](https://github.com/jumkey))
- `redpill_lkm_make_target`字段的可选值有 `dev-v6`, `dev-v7`, `test-v6`, `test-v7`, `prod-v6` 或者 `prod-v7`，
  需要注意后缀为`-v6`的值用于 DSM6 版本构建， 需要注意后缀为`-v7`的值用于 DSM7 版本构建. 默认使用的是 `dev-v6` 和 `dev-v7`。

> PS: 由于toolkit dev缺少fs/proc所需的源代码，因此它们取自提取的DSM6.2.4内核源代码。
构建需要此单个文件夹的源代码，但不使用内核源代码构建redpill.ko模块。 

如果您发现工具链的构建方式有问题或者有改进的想法，请让我知道。

对于所有其他问题：请向社区提出——我知道的并不比其他人多。

# 如何使用?

1. 编辑`<platform>_user_config.json`比如 918+ 就编辑 `apollolake_user_config.json` 文件
1. 编辑`global_config.json`中的`docker.use_custom_bind_mounts`和`docker.custom_bind_mounts.host_path`两个字段，并放入扩展驱动
1. 为你想要的平台和版本构建编译镜像: 
   比如 `redpill_tool_chain.sh build apollolake-7.0-41890`
1. 为你想要的平台和版本构建引导: 
   比如 `redpill_tool_chain.sh auto apollolake-7.0-41890`

`redpill_tool_chain.sh auto`运行结束之后，将会在宿主机的`./image`文件夹中生成 RedPill引导镜像。

依赖: `docker`

# 其他说明
为了方便我自己
- `docker/Dockerfile` 中补入了阿里云镜像
- `redpill_tool_chain.sh run <platform_version>`自定义引导构建过程
- `dd if=$(ls -lt ./images/redpill-* | awk 'NR==1{print $9}') of=/dev/synoboot bs=4M && sync`写入引导
