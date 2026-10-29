# The aarch64 build environment for the PortMaster package.
#
# ubuntu:20.04 (glibc 2.31) is the base because a binary only runs on handheld
# firmwares whose glibc is at least as new as the one it was linked against;
# building on a newer distro produces ports that fail on older CFWs.
#
# tools/package-portmaster.sh builds this image on first use:
#   docker build --platform=linux/arm64 -t portmaster-builder:aarch64 portmaster
FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        # toolchain and build systems
        build-essential gcc g++ gdb ccache \
        autoconf automake libtool pkg-config \
        make ninja-build scons \
        python3 python3-pip python3-setuptools python3-wheel \
        # general utilities
        ca-certificates git git-lfs curl wget nano less file \
        zip unzip p7zip-full xz-utils rsync patchelf chrpath \
        # SDL
        libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev \
        libsdl2-ttf-dev libsdl2-net-dev libsdl2-gfx-dev \
        libsdl1.2-dev libsdl-image1.2-dev libsdl-mixer1.2-dev libsdl-ttf2.0-dev \
        # graphics (GLES/EGL/KMS are what the devices actually provide)
        libgles2-mesa-dev libegl1-mesa-dev libgl1-mesa-dev \
        libgbm-dev libdrm-dev libglew-dev libglm-dev \
        # audio
        libasound2-dev libpulse-dev libopenal-dev \
        libogg-dev libvorbis-dev libflac-dev libopus-dev libopusfile-dev \
        libmpg123-dev libmodplug-dev libxmp-dev libsndfile1-dev libfluidsynth-dev \
        libinstpatch-dev \
        # images, fonts, compression
        libpng-dev libjpeg-dev libwebp-dev libtiff-dev \
        libfreetype6-dev libharfbuzz-dev \
        zlib1g-dev libbz2-dev liblzma-dev libzstd-dev libzip-dev \
        # misc libraries ports commonly need
        libcurl4-openssl-dev libssl-dev libxml2-dev libyaml-dev \
        libudev-dev libevdev-dev libboost-dev libboost-filesystem-dev \
        libboost-system-dev libboost-program-options-dev \
        libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev \
        liblua5.1-0-dev liblua5.3-0-dev libreadline-dev libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

# Focal ships CMake 3.16, which FluidSynth's build rejects.
# The PyPI wheels are manylinux2014 builds, so they run fine on this glibc.
RUN python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir cmake meson

WORKDIR /workspace
CMD ["/bin/bash"]
