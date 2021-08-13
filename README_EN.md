# RedPill Tool Chain

[中文说明](README.md "English")
THX @haydibe
# Inofficial redpill toolchain image builder
- Creates a OCI Container (~= Docker) image based tool chain.
- Takes care of downloading (and caching) the required sources to compile redpill.ko and the required os packages that the build process depends on.
- Caches .pat downloads inside the container on the host.

## Changes
- Migrated from Make to Bash (requires `jq`, instead of `make` now )
- Removed Synology toolchain, the tool chain now consists  of debian packages
- Configuration is now done in the JSON file `global_config.json`
- The configuration allows to specify own configurations -> just copy a block underneath the `building_configs` block and make sure it has a unique value for the id attribute. The id is used what actualy is used to determine the <platform_version>.

## Usage

1. Create `user_config.json` according https://github.com/RedPill-TTG/redpill-load
2. Build the image for the platform and version you want:
   `redpill_tool_chain.sh build <platform_version>`
3. Run the image for the platform and version you want:
   `redpill_tool_chain.sh run <platform_version>`
4. Inside the container, run `make build_all` to build the loader for the platform_version

Note: run `redpill_tool_chain.sh build` to get the list of supported <platform_version>

After set 4. the redpill load image should be build and can be found in the host folder "images".