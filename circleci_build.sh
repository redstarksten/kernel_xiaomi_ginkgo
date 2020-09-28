#!/usr/bin/env bash
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DTB=$(pwd)/out/arch/arm64/boot/dts/qcom/*.dtb
echo "Clone Anykernel and GCC"
apt-get update -y && apt-get upgrade -y
apt-get install -y python3 git cmake clang-format default-jre clang-tidy clang-tools clang clangd libc++-dev libc++1 libc++abi-dev libc++abi1 libclang-dev libclang1 liblldb-dev libllvm-ocaml-dev libomp-dev libomp5 lld lldb llvm-dev llvm-runtime llvm python-clang build-essential make bzip2 libncurses5-dev lld libssl-dev python3-pip ninja-build
git clone -j32 https://github.com/redstarksten/AnyKernel AnyKernel
# mkdir signer \
# curl -sLo signer/zipsigner-3.0.jar https://raw.githubusercontent.com/najahiiii/Noob-Script/noob/bin/zipsigner-3.0.jar
git clone -j32 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 toolchain
git clone -j32 https://github.com/NusantaraDevs/clang clang
echo "Done"
token="1290161744:AAGMv7NlfFdjRG-OR1L644TU8J8dyqDcfH8"
chat_id="513350521"
GCC="$(pwd)/gcc/bin/aarch64-linux-gnu-"
tanggal=$(TZ=Asia/Jakarta date "+%Y%m%d-%H%M")
START=$(date +"%s")
ZIPNAME="StarkX-Ginkgo-${tanggal}"
mkdir $(pwd)/temp
export TEMP=$(pwd)/temp
export LD_LIBRARY_PATH="/root/clang/bin/../lib:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=Bukandewa
export KBUILD_BUILD_HOST=Circleci
export PUSHZIP=$(pwd)/AnyKernel
# sticker plox
function sticker() {
        echo "Send Sticker"
        curl -s -X POST "https://api.telegram.org/bot$token/sendSticker" \
                        -d sticker="CAACAgUAAxkBAAEBY1BfcfdHj0mZ__wpN2xvPpGAb9VIngACiwAD7OCaHpbj1BCmgcEbGwQ" \
                        -d chat_id=$chat_id
}
# Stiker Error
function stikerr() {
        echo "Send Stiker Error"
	curl -s -F chat_id=$chat_id -F sticker="CAACAgUAAxkBAAEBYwlfcdkduys5zAvVpek_kvzSSOOXZwACGgADwNuQOaZM4AdxOsmJGwQ" https://api.telegram.org/bot$token/sendSticker
}
# Send info plox channel
function sendinfo() {
        echo "Sending Information About New Update"
        PATH="/root/clang/bin:${PATH}"
        curl -X POST "https://api.telegram.org/bot$token/sendMessage" \
                        -d chat_id=$chat_id \
                        -d "disable_web_page_preview=true" \
                        -d "parse_mode=html" \
                        -d text="<b>StarkX Kernel</b> New Update is Coming!%0A<b>Started on :</b> <code>circleCI</code>%0A<b>For device :</b> <b>Ginkgo</b> (Redmi Note 8)%0A<b>Kernel Version :</b> <code>$(make kernelversion)</code>%0A<b>Branch :</b> <code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Under commit :</b> <code>$(git log --pretty=format:'"%h : %s"' -1)</code>%0A<b>Using compiler :</b> <code>$($(pwd)/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')</code>%0A<b>Started on :</b> <code>$(TZ=Asia/Jakarta date)</code>%0A<b>circleCI Status :</b> <a href='https://app.circleci.com/pipelines/github/redstarksten/kernel_xiaomi_ginkgo'>here</a>"
}
# Push kernel to channel
function push() {
        echo - "Push flashable zip to telegram"
        cd Anykernel
	curl -F document=@$(echo $PUSHZIP/*.zip) "https://api.telegram.org/bot$token/sendDocument" \
			-F chat_id="$chat_id" \
			-F "disable_web_page_preview=true" \
			-F "parse_mode=html" \
			-F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."
}
# Function upload logs to my own TELEGRAM paste
function paste() {
        echo "Create log"
        cat $TEMP/build.log | curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$token/sendDocument" \
			-F chat_id="$chat_id" \
			-F "disable_web_page_preview=true" \
			-F "parse_mode=html" 
}
# Fin Error
function finerr() {
        echo "Send Error Message"
        paste
        curl -X POST "https://api.telegram.org/bot$token/sendMessage" \
			-d chat_id="$chat_id" \
			-d "disable_web_page_preview=true" \
			-d "parse_mode=markdown" \
			-d text="Build throw an error(s)"
}
# Compile plox
function compile() {
        echo "Compile Process. Please Wait..."
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
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      Image.gz-dtb | tee $TEMP/build.log

            if ! [ -a $IMAGE ]; then
                finerr
		stikerr
                exit 1
            fi
        cp $IMAGE AnyKernel/Image.gz-dtb
}
# Zipping
function zipping() {
        echo "Zipping Image.gz-dtb using Anykernel"
        cat $IMAGE $DTB > Anykernel/Image.gz-dtb
        cd AnyKernel
        zip -r9 $ZIPNAME.zip *
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

