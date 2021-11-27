# RedPill Tool Chain

[中文说明](README.md "English")
THX @haydibe

## Inofficial redpill toolchain image builder

- Creates a OCI Container (~= Docker) image based tool chain.
- Takes care of downloading (and caching) the required sources to compile redpill.ko and the required os packages that the build process depends on.
- Caches .pat downloads inside the container on the host.
- Configuration is done in the JSON file `global_config.json`; custom <platform_version> entries can be added underneath the `building_configs` block. Make sure the id is unique per block!
- Supports a `user_config.json` per <platform_version>
- Supports to bind a local redpill-lkm folder into the container (set `"docker.local_rp_lkm_use": "true"` and set `"docker.local_rp_lkm_path": "path/to/rp-lkm"`)
- Supports to bind a local redpill-load folder into the container (set `"docker.local_rp_load_use": "true"` and set `"docker.local_rp_load_path": "path/to/rp-load"`)
- Supports to clean old image versions and the build cache per <platform_version> or for `all` of them at once.
- Supports to auto clean old image versions and the build cache for the current build image, set `"docker.auto_clean":`to `"true"`.
- Allows to configure if the build cache is used or not ("docker.use_build_cache")
- Allows to specify if "clean all" should delete all or only orphaned images.
- The default `global_config.json` contains platform versions provided by the official redpill-load image. Please create new <platform_version> and point them to custom repositories if wanted.
- Supports to add custom mounts (set`"docker.use_custom_bind_mounts":` to `"true"` and add your custom bind-mounts in `"docker.custom_bind_mounts"`).
- Performs integrity check of required kernel/toolkit-dev required for the image build
- Supports the make target to specify the redpill.ko build configuration. Set `<platform version>.redpill_lkm_make_target` to `dev-v6`, `dev-v7`, `test-v6`, `test-v7`, `prod-v6` or `prod-v7`.
  Make sure to use the -v6 ones on DSM6 build and -v7 on DSM7 build. By default the targets `dev-v6` and `dev-v7` are used.

  - dev: all symbols included, debug messages included
  - test: fully stripped with only warning & above (no debugs or info)
  - prod: fully stripped with no debug messages

## Changes

- added the additionaly required make target when building redpill.ko
- added a new configuration item in `<platform version>.redpill_lkm_make_target` to set the build target

## Usage

1. Edit `<platform>_user_config.json` that matches your <platform_version> according [redpill-load](https://github.com/RedPill-TTG/redpill-load) and place it in the same folder as redpill_tool_chain.sh
2. Build the image for the platform and version you want:
   `./redpill_tool_chain.sh build <platform_version>`
3. Run the image for the platform and version you want:
   `./redpill_tool_chain.sh auto <platform_version>`

You can always use `./redpill_tool_chain.sh run <platform_version>` to get a bash prompt, modify whatever you want and finaly execute `make -C /opt/build_all` to build the boot loader image.
After step 3. the redpill load image should be build and can be found in the host folder "images".

Note1: run `./redpill_tool_chain.sh` to get the list of supported ids for the <platform_version> parameter.
Note2: if `docker.use_local_rp_load` is set to `true`, the auto action will not pull latest redpill-load sources.
Note3: Please do not ask to add <platform_version> with configurations for other redpill-load repositories.

Feel free to modify any values in `global_config.json` that suite your needs!

Examples:

### See Help text

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

Custom Extensions:
---------------------
pocopico.mpt3sas
thethorgroup.boot-wait
thethorgroup.virtio
```

### Custom extended driver management

- Install thethorgroup.virtio    : `./redpill_tool_chain.sh add https://github.com/jumkey/redpill-load/raw/develop/redpill-virtio/rpext-index.json`
- Install thethorgroup.boot-wait : `./redpill_tool_chain.sh add https://github.com/jumkey/redpill-load/raw/develop/redpill-boot-wait/rpext-index.json`
- Install pocopico.mpt3sas       : `./redpill_tool_chain.sh add https://raw.githubusercontent.com/pocopico/rp-ext/master/mpt3sas/rpext-index.json`
- Remove pocopico.mpt3sas        : `./redpill_tool_chain.sh del pocopico.mpt3sas`

[Get more extended drivers....](https://github.com/pocopico/rp-ext)

### Build toolchain image

- For Bromolow 6.2.4   : `./redpill_tool_chain.sh build bromolow-6.2.4-25556`
- For Bromolow 7.0     : `./redpill_tool_chain.sh build bromolow-7.0-41222`
- For Apollolake 6.2.4 : `./redpill_tool_chain.sh build apollolake-6.2.4-25556`
- For Apollolake 7.0   : `./redpill_tool_chain.sh build apollolake-7.0-41890`

### Create redpill bootloader image

- For Bromolow 6.2.4   : `./redpill_tool_chain.sh auto bromolow-6.2.4-25556`
- For Bromolow 7.0     : `./redpill_tool_chain.sh auto bromolow-7.0-41222`
- For Apollolake 6.2.4 : `./redpill_tool_chain.sh auto apollolake-6.2.4-25556`
- For Apollolake 7.0   : `./redpill_tool_chain.sh auto apollolake-7.0-41890`

### Clean old redpill bootloader images and build cache

- For Bromolow 6.2.4   : `./redpill_tool_chain.sh clean bromolow-6.2.4-25556`
- For Bromolow 7.0     : `./redpill_tool_chain.sh clean bromolow-7.0-41222`
- For Apollolake 6.2.4 : `./redpill_tool_chain.sh clean apollolake-6.2.4-25556`
- For Apollolake 7.0   : `./redpill_tool_chain.sh clean apollolake-7.0-41890`
- For all              : `./redpill_tool_chain.sh clean all`
