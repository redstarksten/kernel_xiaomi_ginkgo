#!/usr/bin/env bash
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
echo "Clone Anykernel and GCC"
git clone -j32 https://github.com/redstarksten/AnyKernel -b master AnyKernel
git clone -j32 --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 toolchain
git clone -j32 --depth=1 https://github.com/NusantaraDevs/clang clang
cmake -DCMAKE_PREFIX_PATH=${LLVM_PREFIX}/lib/cmake/llvm ../llvm_git/polly
echo "Done"
token="1290161744:AAGMv7NlfFdjRG-OR1L644TU8J8dyqDcfH8"
chat_id="513350521"
GCC="$(pwd)/gcc/bin/aarch64-linux-gnu-"
tanggal=$(TZ=Asia/Jakarta date "+%Y%m%d-%H%M")
START=$(date +"%s")
KERNEL_NAME=StarkX
DEVICE=Ginkgo
export LD_LIBRARY_PATH="/root/clang/bin/../lib:$PATH"xport ARCH=arm64
export KBUILD_BUILD_USER=bukandewa
export KBUILD_BUILD_HOST=Circleci
# sticker plox
function sticker() {
        curl -s -X POST "https://api.telegram.org/bot$token/sendSticker" \
                        -d sticker="CAACAgUAAx0CUPRqKwACFWRellg9L_iFa20dCci4wyL0Pr2xKgACJQEAAna2lSii1C6TeMVizRgE" \
                        -d chat_id=$chat_id
}
# Stiker Error
function stikerr() {
	curl -s -F chat_id=$chat_id -F sticker="CAACAgQAAx0CUPRqKwACFWBellgcUeTWUj_MRWJLz6Czd9cokwACUwwAAskpHQ8go8px5eh4ihgE" https://api.telegram.org/bot$token/sendSticker
}
# Send info plox channel
function sendinfo() {
        PATH="/root/clang/bin:${PATH}"
        curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
                        -d chat_id=$chat_id \
                        -d "disable_web_page_preview=true" \
                        -d "parse_mode=html" \
                        -d text="<b>StarkX Kernel</b> New Build is UP!%0A<b>Started on :</b> <code>circleCI</code>%0A<b>For device :</b> <b>Ginkgo</b> (Redmi Note 8)%0A<b>Kernel Version :</b> <code>$(make kernelversion)</code>%0A<b>Branch :</b> <code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Under commit :</b> <code>$(git log --pretty=format:'"%h : %s"' -1)</code>%0A<b>Using compiler :</b> <code>$($(pwd)/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')</code>%0A<b>Started on :</b> <code>$(TZ=Asia/Jakarta date)</code>%0A<b>circleCI Status :</b> <a href='https://app.circleci.com/pipelines/github/redstarksten/kernel_xiaomi_ginkgo'>here</a>"
}
# Push kernel to channel
function push() {
        cd AnyKernel
	ZIP=$(echo Mina-Kernel-*.zip)
	curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
			-F chat_id="$chat_id" \
			-F "disable_web_page_preview=true" \
			-F "parse_mode=html" \
			-F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."
}
# Function upload logs to my own TELEGRAM paste
function paste() {
        cat build.log | curl -F document=@build.log "https://api.telegram.org/bot$token/sendDocument" \
			-F chat_id="$chat_id" \
			-F "disable_web_page_preview=true" \
			-F "parse_mode=html" 
}
# Fin Error
function finerr() {
        paste
        curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
			-d chat_id="$chat_id" \
			-d "disable_web_page_preview=true" \
			-d "parse_mode=markdown" \
			-d text="Build throw an error(s)"
}
# Compile plox
function compile() {
make O=out ARCH=arm64 vendor/ginkgo-perf_defconfig
PATH="${PWD}/bin:${PWD}/toolchain/bin:${PATH}:${PWD}/clang/bin:${PATH}" \
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      LD=ld.lld \
                      AR=llvm-ar \
                      NM=llvm-nm \
                      OBJCOPY=llvm-objcopy \
                      OBJDUMP=llvm-objdump \
                      STRIP=llvm-strip \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- | tee build.log
            if ! [ -a $IMAGE ]; then
                finerr
		stikerr
                exit 1
            fi
        cp out/arch/arm64/boot/Image.gz-dtb AnyKernel/zImage
}
# Zipping
function zipping() {
        cd AnyKernel
        zip -r9 $KERNEL_NAME-$DEVICE-${tanggal}.zip *
        cd ..
}
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
paste
push
sticker
