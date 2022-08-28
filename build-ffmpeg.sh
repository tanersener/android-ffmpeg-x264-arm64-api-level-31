#!/bin/bash

set -e

export BASEDIR="$(pwd)"
export TOOLCHAIN=$(echo "$(uname -s)" | tr '[:upper:]' '[:lower:]')"-x86_64"
if [ "$(uname)" == "Darwin" ]; then
  export THREADS="$(sysctl -n hw.logicalcpu)"
else
  export THREADS="$(nproc)"
fi
export CC=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/bin/aarch64-linux-android31-clang
export CXX=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/bin/aarch64-linux-android31-clang++
export AR=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/bin/llvm-ar
export RANLIB=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/bin/llvm-ranlib
export STRIP=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/bin/llvm-strip
export NM=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/bin/llvm-nm
export PKG_CONFIG_LIBDIR=${BASEDIR}/build/x264/lib/pkgconfig

export CFLAGS="-DBIONIC_IOCTL_NO_SIGNEDNESS_OVERLOAD $(pkg-config --cflags x264)"
export LDFLAGS="-lc -lm -ldl $(pkg-config --libs --static x264) -L${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/aarch64-linux-android/lib -L${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/sysroot/usr/lib/aarch64-linux-android/31 -L${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/lib"
export HOST_PKG_CONFIG_PATH=$(command -v pkg-config)

rm -rf FFmpeg
git clone https://github.com/FFmpeg/FFmpeg.git
cd FFmpeg

./configure \
 --prefix=${BASEDIR}/build/ffmpeg \
 --sysroot=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/sysroot \
 --cross-prefix=aarch64-linux-android- \
 --pkg-config="${HOST_PKG_CONFIG_PATH}" \
 --enable-cross-compile \
 --arch=aarch64 \
 --cpu=armv8 \
 --enable-neon \
 --enable-asm \
 --enable-inline-asm \
 --target-os=android \
 --cc=${CC} \
 --cxx=${CXX} \
 --ranlib=${RANLIB} \
 --strip=${STRIP} \
 --nm=${NM} \
 --enable-pic \
 --enable-optimizations \
 --enable-swscale \
 --enable-shared \
 --enable-pthreads \
 --enable-small \
 --enable-debug \
 --enable-version3 \
 --enable-gpl \
 --enable-libx264 \
 --disable-static \
 --disable-stripping \
 --disable-autodetect

make -j${THREADS}
make install
