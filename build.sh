#!/usr/bin/env bash
CONFIG=vendor/starkx_defconfig
EXTRA=$HOME/Extra
START=$(date +"%s")
tanggal=$(TZ=Asia/Jakarta date '+%Y%m%d'-'%H%M')
KERNEL_DIR=$HOME/kernel_xiaomi_ginkgo
KERNEL_NAME=StarkX-R
KERNEL_VERSION=$(make kernelversion)
DEVICE=RN8
ZIPNAME=${KERNEL_NAME}-${DEVICE}-${tanggal}
IMG_DIR=${KERNEL_DIR}/out/arch/arm64/boot/Image.gz-dtb
ANY_DIR=${EXTRA}/Anykernel
ANY_IMG=${ANY_DIR}/Image.gz-dtb
DTB=${KERNEL_DIR}/out/arch/arm64/boot/dtbo.img
SIGNER_DIR=${EXTRA}/signer

function check() {
	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Extra Checker..."
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""

    if ! [[ -d ${ANY_DIR} ]]; then
      	cd ..${EXTRA}
      	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Cloning Anykernel..."	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
	git clone https://github.com/redstarksten/Anykernel.git
   else
   	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Anykernel already exist." 	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
    fi

    if ! [[ -d ${SIGNER_DIR} ]]; then
    	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Download signer..."  	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
    	mkdir signer && curl -sLo signer/zipsigner-3.0.jar https://raw.githubusercontent.com/najahiiii/Noob-Script/noob/bin/zipsigner-3.0.jar && cd
    else
    	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Signer already exist."  	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
    fi
}
#telegram
export token="1290161744:AAGMv7NlfFdjRG-OR1L644TU8J8dyqDcfH8"
export chat_id="-1001169205147"
export sticker_id="CAACAgUAAxkBAAEBY1BfcfdHj0mZ__wpN2xvPpGAb9VIngACiwAD7OCaHpbj1BCmgcEbGwQ"
export logo=${EXTRA}/logo.jpg
#env
export PATH="$HOME/unnamed-clang/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/unnamed-clang/lib:$LD_LIBRARY_PATH"
export ARCH=arm64
export SUBARCH=arm64
#CUSTOM KBUILD
export KBUILD_BUILD_USER="bukandewa"
export KBUILD_BUILD_HOST="manjaro-pc"
export KBUILD_COMPILER_STRING="unnamed"
export KBUILD_LINKER_STRING="clang"
export KBUILD_BUILD_VERSION="1"
#export KBUILD_BUILD_TIMESTAMP=$(TZ=Asia/Jakarta date)
#CCACHE
export PATH="/usr/lib/ccache:$PATH"
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
#config global
git config --global user.email "mahadewanto2@gmail.com"
git config --global user.name "bukandewa"
git config --global user.signingkey F14470B7A98EBDF2600BBD9616334271F7E45334

# sticker plox
function sticker() {
	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Send sticker success!"  	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
        ./telegram -s ${sticker_id}
}

#Upload to gdrive
function upload() {
	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Upload to Gdrive Folder...."	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
	#fileinfo
	gdrive upload --share $(echo ${SIGNER_DIR}/${ZIPNAME}-signed.zip) | tee ${EXTRA}/link.txt
	link=$(echo $(cat $EXTRA/link.txt | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*" | sort -u))
	link2=$(echo $(cat $EXTRA/link2.txt | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*" | sort -u))
	filename=$(echo $(cat $EXTRA/link.txt | grep -Eo "StarkX[a-zA-Z0-9./?=_%:-]*" | sort -u))
	filename2=$(echo $(cat $EXTRA/link2.txt | grep -Eo "StarkX[a-zA-Z0-9./?=_%:-]*" | sort -u))
	filesize=$(echo $(cat $EXTRA/link.txt | grep -Eo "total\s[a-zA-Z0-9./?=_%:-]*\s[a-zA-Z0-9./?=_%:-]*" | sort -u))
	filesize2=$(echo $(cat $EXTRA/link2.txt | grep -Eo "total\s[a-zA-Z0-9./?=_%:-]*\s[a-zA-Z0-9./?=_%:-]*" | sort -u))
	sha1=$(echo $(cat $EXTRA/sha1.txt))
        sha2=$(echo $(cat $EXTRA/sha2.txt))
}	
#send image and caption info
function image() {
	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Send image and caption..."  	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
        ./telegram -i $(echo ${logo}) -H -D \
-T "<b>${KERNEL_NAME}</b> New Update!
<b>Redmi Note 8/8T A10/A11</b>
<b>By @bukandewa</b>

<a href='https://t.me/StarkXKernel'>Channel</a> | <a href='https://t.me/StarkXOfficial'>Group</a> | <a href='https://github.com/redstarksten'>Github</a>

<b><u>Changelog :</u></b>
- Upstream to 'v4.14.221' linux stable
- etc.

<b><u>StarkX-R for MiUi A11</u></b>
Filename: '$filename'
Filesize: '$filesize'
ZIP sha1: '$sha1'
Link: <a href='$link'>Download Here</a>

<b><u>StarkX-Q for MiUi A10</u></b>
Filename: '$filename2'
Filesize: '$filesize2'
ZIP sha1: '$sha2'
Link: <a href='$link2'>Download Here</a>

<b><u>Notes :</u></b>

- Dont forget to backup boot and dtbo image before flash the kernel!
- Just flash, wipe dalvik cache then reboot
- Tell me if you find any bugs or kernel wont boot."

rm -rf $SIGNER_DIR/*.zip
}

# Compile plox
function compile() {
mkdir -p out
	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Clean oldconfig exist..."  	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
make O=out clean && make O=out mrproper
        echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Compile kernel process..."  	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
make O=out ARCH=arm64 ${CONFIG} > /dev/null
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      LD=ld.lld \
                      AR=llvm-ar \
                      AS=llvm-as \
                      NM=llvm-nm \
                      OBJCOPY=llvm-objcopy \
                      OBJDUMP=llvm-objdump \
                      STRIP=llvm-strip \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      Image.gz-dtb \
                      dtbo.img
}

# Zipping
function zipping() {
        echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Zipping to anykernel..."  	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
        if [[ -f ${IMG_DIR} ]] && [[ -f ${DTB} ]]; then
        cp ${IMG_DIR} ${ANY_DIR} 
        cp ${DTB} ${ANY_DIR}
        cd /${ANY_DIR}
        zip -r9 unsigned.zip * -x .git README.md *placeholder
        mv unsigned.zip ${SIGNER_DIR} && cd ..
        else
        echo -e "Failed!"
        fi
}
#signer
function signer() {
	echo -e ""
	echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
	echo -e "Signing zip process..."  	
	echo -e "▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄"
	echo -e ""
        if [[ -f ${SIGNER_DIR}/unsigned.zip ]]; then
        cd signer
        java -jar zipsigner-3.0.jar unsigned.zip ${ZIPNAME}-signed.zip
        $(echo sha1sum ${ZIPNAME}-signed.zip) | grep -Eo '^[^ ]+' | tee $EXTRA/sha1.txt
        rm -rf unsigned.zip && cd ../telegram      
        else
        echo -e "Failed!"
        fi
}
check
compile
zipping
signer
END=$(date +"%s")
DIFF=$(($END - $START))
upload
image
sticker
