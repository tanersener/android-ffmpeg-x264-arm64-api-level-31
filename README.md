# FFmpeg and x264 on Android arm64 with api level 31

This repository is created to reproduce the `signal 11 (SIGSEGV), code 2 (SEGV_ACCERR)` crash occurring for `ffmpeg` and 
`x264` on `Android 12 arm64-v8a` devices that run `Api Level 31` or later.

Below you can find the instructions to reproduce it.

Notes:
 - This crash doesn't occur if `x264` is built without `asm`. I believe this proves that this crash originates from the
    aarch64 assembly code `x264` uses.
 - Command used to reproduce this crash uses `792x1568` dimensions. Not all dimensions cause a crash. `792x1568` is one
    of the dimension that does.
 - Older Android devices or emulators e.g. Android 11 (Api Level 30) doesn't have this issue. Android 11 have some new 
    changes regarding `ARM Memory Tagging Extension (MTE)`. Maybe those changes are triggering this crash. 
    See [Tagged Pointers](https://source.android.com/docs/security/test/tagged-pointers) for those changes.

### Building

Instructions under this section shows how we are building `ffmpeg` and `x264` from their latest source code.
Both `macOS` and `Linux` hosts were used to test the scripts.

#### Android NDK
We are using `Android NDK r25b`, but we saw that this case can be reproduced with older `NDK` versions e.g.
`r24`, `r23c`, `r22b` as well.
- Download `Android NDK r25b` [manually](https://developer.android.com/ndk/downloads) or via `Android Studio`, 
   then set `ANDROID_SDK_ROOT` and `ANDROID_NDK_ROOT` environment variables accordingly

#### Additional Packages

`pkg-config` must be in the `PATH`.

#### x264

Use `build-x264.sh` to build `x264`.

This is what `build-x264.sh` does.

```bash
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
make
make install
```

#### FFmpeg

Use `build-ffmpeg.sh` to build `ffmpeg`.

This is what we have inside `build-ffmpeg.sh`.

```bash
git clone https://github.com/FFmpeg/FFmpeg.git
cd FFmpeg

export CFLAGS="-DBIONIC_IOCTL_NO_SIGNEDNESS_OVERLOAD $(pkg-config --cflags x264)"
export LDFLAGS="-lc -lm -ldl $(pkg-config --libs --static x264) -L${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/aarch64-linux-android/lib -L${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/sysroot/usr/lib/aarch64-linux-android/31 -L${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${TOOLCHAIN}/lib"
export HOST_PKG_CONFIG_PATH=$(command -v pkg-config)

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

make
make install
```

### Running

Copy the following files into an Android device or emulator with arm64 architecture and run the command provided below. 
Note that this device must be running Android 12 (Api Level 31+). Older devices don't have this issue.

1. Create a test directory under the `/data/local` folder on the device. 
    Note that `adb`, which is normally under the `${ANDROID_SDK_ROOT}/platform-tools` path is used here. 
    You may need to run `adb root` if you receive permission errors.
 
    ```
    [optional] adb root
    adb shell
    mkdir /data/local/tmp/org.ffmpeg.test
    ```
2. Copy the following files to the `/data/local` folder on the device.
    ```
    adb push build/ffmpeg/bin/ffmpeg /data/local/tmp/org.ffmpeg.test
    adb push build/ffmpeg/lib/libavcodec.so /data/local/tmp/org.ffmpeg.test
    adb push build/ffmpeg/lib/libavdevice.so /data/local/tmp/org.ffmpeg.test
    adb push build/ffmpeg/lib/libavfilter.so /data/local/tmp/org.ffmpeg.test
    adb push build/ffmpeg/lib/libavformat.so /data/local/tmp/org.ffmpeg.test
    adb push build/ffmpeg/lib/libavutil.so /data/local/tmp/org.ffmpeg.test
    adb push build/ffmpeg/lib/libpostproc.so /data/local/tmp/org.ffmpeg.test
    adb push build/ffmpeg/lib/libswresample.so /data/local/tmp/org.ffmpeg.test
    adb push build/ffmpeg/lib/libswscale.so /data/local/tmp/org.ffmpeg.test
    adb push pyramid.jpg /data/local/tmp/org.ffmpeg.test
    ```
3. Run `ffmpeg` on the device.
    ```
    adb shell
    cd /data/local/tmp/org.ffmpeg.test
    export LD_LIBRARY_PATH=/data/local/tmp/org.ffmpeg.test
    ./ffmpeg -v 9 -loglevel 99 -loop 1 -i pyramid.jpg -vf scale=792x1568 -c:v libx264 video.mp4
    ```
    Full console output can be found inside the [console-output.txt](console-output.txt) file.

    Disassembly information captured via `gdb` is available inside [disassembly.txt](disassembly.txt).

4. This command crashes with `Segmentation fault` on Android 12 arm64 devices.


5. Find the `tombstone` file created for this crash.
    ```
    adb shell
    ls -latr /data/tombstones/
      -rw-rw----  1 tombstoned system  95749 2022-08-28 00:29 tombstone_30.pb
      -rw-rw----  1 tombstoned system 174116 2022-08-28 00:29 tombstone_30
    ```
6. Copy the `tombstone` file to the `host`.
    ```
    adb pull /data/tombstones/tombstone_30
    cat tombstone_30
    ```
    This command will print the following output.
    ```
    *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
    Build fingerprint: 'google/sdk_gphone64_arm64/emulator64_arm64:12/SE1A.220630.001/8789670:userdebug/dev-keys'
    Revision: '0'
    ABI: 'arm64'
    Timestamp: 2022-08-28 11:31:51.574993028+0100
    Process uptime: 1s
    Cmdline: ./ffmpeg -v 9 -loglevel 99 -loop 1 -i pyramid.jpg -vf scale=792x1568 -c:v libx264 video.mp4
    pid: 31986, tid: 31986, name: ffmpeg  >>> ./ffmpeg <<<
    uid: 0
    tagged_addr_ctrl: 0000000000000001
    signal 11 (SIGSEGV), code 2 (SEGV_ACCERR), fault addr 0xb400007a2a46b000
        x0  b400007b5d718960  x1  b400007a2a420cd0  x2  b400007a2a425904  x3  b400007a2a433ee4
        x4  b400007a2a46aff4  x5  0000007fc9bbd8ec  x6  00000000fffffffa  x7  0000000000000032
        x8  b400007a2a4232b0  x9  b400007a2a4689b0  x10 0000007cdd03e738  x11 00000000000025e4
        x12 0000000000008000  x13 0000000000000031  x14 0000000000000061  x15 0000000000007fff
        x16 b400007a2a433e74  x17 b400007a2a3ff3a8  x18 0000007cee20c000  x19 0000000000000027
        x20 0000007fc9bbeb28  x21 0000000000000027  x22 00000000000012f2  x23 b400007ced0d6dd0
        x24 b400007a2a431890  x25 b400007a2aa45c60  x26 b400007a2a433e74  x27 b400007b5d718900
        x28 b400007a2a420c60  x29 0000007fc9bbd8f0
        lr  0000007cdcffad9c  sp  0000007fc9bbd8a0  pc  0000007cdd03e74c  pst 0000000080001000

    backtrace:
        #00 pc 000000000060c74c  /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_8_mbtree_propagate_cost_neon+20)
        #01 pc 00000000005c8d98  /data/local/tmp/org.ffmpeg.test/libavcodec.so (macroblock_tree_propagate+540)
        #02 pc 00000000005bd9b4  /data/local/tmp/org.ffmpeg.test/libavcodec.so (macroblock_tree+856)
        #03 pc 00000000005bcef0  /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_8_slicetype_analyse+2844)
        #04 pc 000000000060f4c4  /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_8_lookahead_get_frames+264)
        #05 pc 00000000005962ac  /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_8_encoder_encode+896)
        #06 pc 0000000000592360  /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_encoder_encode+16)
        #07 pc 000000000058c714  /data/local/tmp/org.ffmpeg.test/libavcodec.so (X264_frame+1272)
        #08 pc 00000000004838b8  /data/local/tmp/org.ffmpeg.test/libavcodec.so (ff_encode_encode_cb+36)
        #09 pc 0000000000483db0  /data/local/tmp/org.ffmpeg.test/libavcodec.so (encode_receive_packet_internal+340)
        #10 pc 0000000000483c10  /data/local/tmp/org.ffmpeg.test/libavcodec.so (avcodec_send_frame+516)
        #11 pc 0000000000035f14  /data/local/tmp/org.ffmpeg.test/ffmpeg (encode_frame+252)
        #12 pc 0000000000035950  /data/local/tmp/org.ffmpeg.test/ffmpeg (do_video_out+1840)
        #13 pc 0000000000034eec  /data/local/tmp/org.ffmpeg.test/ffmpeg (reap_filters+280)
        #14 pc 000000000003129c  /data/local/tmp/org.ffmpeg.test/ffmpeg (main+7160)
        #15 pc 00000000000488c8  /apex/com.android.runtime/lib64/bionic/libc.so (__libc_init+96) (BuildId: ba489d4985c0cf173209da67405662f9)
    ...
    ```

7. If you don't see method names next to `libavcodec.so` then use `ndk-stack` to see the contents of the tombstone file.
    ```
    $ANDROID_NDK_ROOT/ndk-stack -sym build/ffmpeg/lib -i tombstone_30
    ```
    This is the output that will be printed. It again shows that crash comes from `x264_8_mbtree_propagate_cost_neon`.
    ```
    ********** Crash dump: **********
    Build fingerprint: 'google/sdk_gphone64_arm64/emulator64_arm64:12/SE1A.220630.001/8789670:userdebug/dev-keys'
    #00 0x000000000060c74c /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_8_mbtree_propagate_cost_neon+20)
    x264_8_mbtree_propagate_cost_neon
    mc-c.c:0:0
    #01 0x00000000005c8d98 /data/local/tmp/org.ffmpeg.test/libavcodec.so (macroblock_tree_propagate+540)
    macroblock_tree_propagate
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/x264/encoder/slicetype.c:1072:9
    #02 0x00000000005bd9b4 /data/local/tmp/org.ffmpeg.test/libavcodec.so (macroblock_tree+856)
    macroblock_tree
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/x264/encoder/slicetype.c:1155:21
    #03 0x00000000005bcef0 /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_8_slicetype_analyse+2844)
    x264_8_slicetype_analyse
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/x264/encoder/slicetype.c:1678:9
    #04 0x000000000060f4c4 /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_8_lookahead_get_frames+264)
    x264_8_lookahead_get_frames
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/x264/encoder/lookahead.c:246:13
    #05 0x00000000005962ac /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_8_encoder_encode+896)
    x264_8_encoder_encode
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/x264/encoder/encoder.c:3447:9
    #06 0x0000000000592360 /data/local/tmp/org.ffmpeg.test/libavcodec.so (x264_encoder_encode+16)
    x264_encoder_encode
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/x264/encoder/api.c:165:12
    #07 0x000000000058c714 /data/local/tmp/org.ffmpeg.test/libavcodec.so (X264_frame+1272)
    X264_frame
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/FFmpeg/libavcodec/libx264.c:518:13
    #08 0x00000000004838b8 /data/local/tmp/org.ffmpeg.test/libavcodec.so (ff_encode_encode_cb+36)
    ff_encode_encode_cb
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/FFmpeg/libavcodec/encode.c:198:11
    #09 0x0000000000483db0 /data/local/tmp/org.ffmpeg.test/libavcodec.so (encode_receive_packet_internal+340)
    encode_simple_internal
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/FFmpeg/libavcodec/encode.c:269:15
    encode_simple_receive_packet
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/FFmpeg/libavcodec/encode.c:286:15
    encode_receive_packet_internal
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/FFmpeg/libavcodec/encode.c:320:15
    #10 0x0000000000483c10 /data/local/tmp/org.ffmpeg.test/libavcodec.so (avcodec_send_frame+516)
    avcodec_send_frame
    /Users/taner/Projects/android-ffmpeg-x264-arm64-api-level-31/FFmpeg/libavcodec/encode.c:461:15
    #11 0x0000000000035f14 /data/local/tmp/org.ffmpeg.test/ffmpeg (encode_frame+252)
    #12 0x0000000000035950 /data/local/tmp/org.ffmpeg.test/ffmpeg (do_video_out+1840)
    #13 0x0000000000034eec /data/local/tmp/org.ffmpeg.test/ffmpeg (reap_filters+280)
    #14 0x000000000003129c /data/local/tmp/org.ffmpeg.test/ffmpeg (main+7160)
    #15 0x00000000000488c8 /apex/com.android.runtime/lib64/bionic/libc.so (__libc_init+96) (BuildId: ba489d4985c0cf173209da67405662f9)
    Crash dump is completed
    ```