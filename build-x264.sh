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

rm -rf x264
git clone https://github.com/mirror/x264
cd x264

./configure \
 --prefix=${BASEDIR}/build/x264 \
 --sysroot=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/sysroot \
 --enable-pic \
 --enable-static \
 --enable-debug \
 --disable-cli \
 --host=aarch64-linux-android

make -j${THREADS}
make install