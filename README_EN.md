# RedPill Tool Chain

[中文说明](README.md "English")
THX @haydibe
# Inofficial redpill toolchain image builder
- Creates a OCI Container (~= Docker) image based tool chain.
- Takes care of downloading (and caching) the required sources to compile redpill.ko and the required os packages that the build process depends on.
- Caches .pat downloads inside the container on the host.
- Configuration is done in the JSON file `global_config.json`; custom <platform_version> entries can be added underneath the `building_configs` block. Make sure the id is unique per block!
- Support a `user_config.json` per <platform_version>
- ALlow to bind a local redpill-load folder into the container (set `"docker.local_rp_load_use": "true"` and set `"docker.local_rp_load_path": "path/to/rp-load"`)
## Changes
- removed `user_config.json.template`, as it was orphaned and people started to use it in an unintended way.
- new parameters in `global_config.json`:
-- `docker.local_rp_load_use`: wether to mount a local folder with redpill-load into the build container (true/false)
-- `docker.local_rp_load_path`: path to the local copy of redpill-load to mount into the build container (absolute or relative path)
-- `build_configs[].user_config_json`: allows to defina a user_config.json per <platform_version>. 

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

Actions: build, auto, run

- build:    Build the toolchain image for the specified platform version.

- auto:     Starts the toolchain container using the previosuly build toolchain image for the specified platform.
            Updates redpill sources and builds the bootloader image automaticaly. Will end the container once done.

- run:      Starts the toolchain container using the previously built toolchain image for the specified platform.
            Interactive Bash terminal.

Available platform versions:
---------------------
bromolow-6.2.4-25556
bromolow-7.0-41222
apollolake-6.2.4-25556
apollolake-7.0-41890
```

### Build toolchain image

For Bromolow 6.2.4   : `./redpill_tool_chain.sh build bromolow-6.2.4-25556`
For Bromolow 7.0     : `./redpill_tool_chain.sh build bromolow-7.0-41222`
For Apollolake 6.2.4 : `./redpill_tool_chain.sh build apollolake-6.2.4-25556`
For Apollolake 7.0   : `./redpill_tool_chain.sh build apollolake-7.0-41890`

### Create redpill bootloader image

For Bromolow 6.2.4   : `./redpill_tool_chain.sh auto bromolow-6.2.4-25556`
For Bromolow 7.0     : `./redpill_tool_chain.sh auto bromolow-7.0-41222`
For Apollolake 6.2.4 : `./redpill_tool_chain.sh auto apollolake-6.2.4-25556`
For Apollolake 7.0   : `./redpill_tool_chain.sh auto apollolake-7.0-41890`
