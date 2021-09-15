# RedPill Tool Chain

[中文说明](README.md "English")
THX @haydibe
# Inofficial redpill toolchain image builder
- Creates a OCI Container (~= Docker) image based tool chain.
- Takes care of downloading (and caching) the required sources to compile redpill.ko and the required os packages that the build process depends on.
- Caches .pat downloads inside the container on the host.
- Configuration is done in the JSON file `global_config.json`; custom <platform_version> entries can be added underneath the `building_configs` block. Make sure the id is unique per block!
- Supports a `user_config.json` per <platform_version>
- Supports to bind a local redpill-load folder into the container (set `"docker.local_rp_load_use": "true"` and set `"docker.local_rp_load_path": "path/to/rp-load"`)
- Supports to clean old image versions and the build cache per <platform_version> or for `all` of them at once.
- Supports to auto clean old image versions and the build cache for the current build image, set `"docker.auto_clean":`to `"true"`.
- Allows to configure if the build cache is used or not ("docker.use_build_cache")
- Allows to specify if "clean all" should delete all or only orphaned images.
## Changes
- fixed usage of label that determins the redpill-tool-chain images for clean up
- add `"docker.use_build_cache": "false"` to global_settings.json
- add `"docker.clean_images": "all"` to global_settings.json

## Usage

1. edit `<platform>_user_config.json` that matches your <platform_version> according https://github.com/RedPill-TTG/redpill-load and place it in the same folder as redpill_tool_chain.sh
2. Build the image for the platform and version you want:
   `./redpill_tool_chain.sh build <platform_version>`
3. Run the image for the platform and version you want:
   `./redpill_tool_chain.sh auto <platform_version>`


You can always use `./redpill_tool_chain.sh run <platform_version>` to get a bash prompt, modify whatever you want and finaly execute `make -C /opt/build_all` to build the boot loader image.
After step 3. the redpill load image should be build and can be found in the host folder "images".

Note1: run `./redpill_tool_chain.sh` to get the list of supported ids for the <platform_version> parameter.
Note2: if `docker.use_local_rp_load` is set to `true`, the auto action will not pull latest redpill-load sources.


Feel free to modify any values in `global_config.json` that suite your needs!

Examples:
### See Help text

```
./redpill_tool_chain.sh
Usage: ./redpill_tool_chain.sh <action> <platform version>

Actions: build, auto, run, clean

- build:    Build the toolchain image for the specified platform version.

- auto:     Starts the toolchain container using the previosuly build toolchain image for the specified platform.
            Updates redpill sources and builds the bootloader image automaticaly. Will end the container once done.

- run:      Starts the toolchain container using the previously built toolchain image for the specified platform.
            Interactive Bash terminal.

- clean:    Removes old (=dangling) images and the build cache for a platform version.
            Use `all` as platform version to remove images and build caches for all platform versions. `"docker.clean_images"`="all" only has affect with clean all.

Available platform versions:
---------------------
bromolow-6.2.4-25556
bromolow-7.0-41222
bromolow-7.0.1-42214
apollolake-6.2.4-25556
apollolake-7.0-41890
apollolake-7.0.1-42214
```

### Build toolchain image

For Bromolow 6.2.4   : `./redpill_tool_chain.sh build bromolow-6.2.4-25556`
For Bromolow 7.0     : `./redpill_tool_chain.sh build bromolow-7.0-41222`
For Bromolow 7.0.1   : `./redpill_tool_chain.sh build bromolow-7.0.1-42214`
For Apollolake 6.2.4 : `./redpill_tool_chain.sh build apollolake-6.2.4-25556`
For Apollolake 7.0   : `./redpill_tool_chain.sh build apollolake-7.0-41890`
For Apollolake 7.0.1 : `./redpill_tool_chain.sh build apollolake-7.0.1-42214`

### Create redpill bootloader image

For Bromolow 6.2.4   : `./redpill_tool_chain.sh auto bromolow-6.2.4-25556`
For Bromolow 7.0     : `./redpill_tool_chain.sh auto bromolow-7.0-41222`
For Bromolow 7.0.1   : `./redpill_tool_chain.sh auto bromolow-7.0.1-42214`
For Apollolake 6.2.4 : `./redpill_tool_chain.sh auto apollolake-6.2.4-25556`
For Apollolake 7.0   : `./redpill_tool_chain.sh auto apollolake-7.0-41890`
For Apollolake 7.0.1 : `./redpill_tool_chain.sh auto apollolake-7.0.1-42214`

### Clean old redpill bootloader images and build cache

For Bromolow 6.2.4   : `./redpill_tool_chain.sh clean bromolow-6.2.4-25556`
For Bromolow 7.0     : `./redpill_tool_chain.sh clean bromolow-7.0-41222`
For Bromolow 7.0.1   : `./redpill_tool_chain.sh clean bromolow-7.0.1-42214`
For Apollolake 6.2.4 : `./redpill_tool_chain.sh clean apollolake-6.2.4-25556`
For Apollolake 7.0   : `./redpill_tool_chain.sh clean apollolake-7.0-41890`
For Apollolake 7.0.1 : `./redpill_tool_chain.sh clean apollolake-7.0.1-42214`
For all              : `./redpill_tool_chain.sh clean all`
