#!/usr/bin/env bash
Image=Image.gz-dtb
CONFIG=vendor/ginkgo-perf_defconfig
Img_Dir=$(pwd)/out/arch/arm64/boot/$Image
Any_Dir=$(pwd)/Anykernel
Any_Img=$Any_Dir/$Image
Dtb=$(pwd)/out/arch/arm64/boot/dts/qcom/*.dtb
Signer_Dir=$(pwd)/signer
Final_Zip=$Signer_Dir/$Zipname.signed.zip
tanggal=$(TZ=Asia/Jakarta date "+%Y%m%d-%H%M")
START=$(date +"%s")
Kernel_Name=StarkX
Device=Ginkgo
Zipname=$Kernel_Name-$Device-${tanggal}
echo -e "   #############################################"
echo -e "  #                                           #"
echo -e " #             Dependencies...               #"
echo -e "#                                           #"
echo -e "############################################\n"
#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install -y python3 git cmake clang-format default-jre clang-tidy clang-tools clang clangd libc++-dev libc++1 libc++abi-dev libc++abi1 libclang-dev libclang1 liblldb-dev libllvm-ocaml-dev libomp-dev libomp5 lld lldb llvm-dev llvm-runtime llvm python-clang build-essential make bzip2 libncurses5-dev lld libssl-dev python3-pip ninja-build
# git clone -j32 https://github.com/NusantaraDevs/clang clang
echo -e "   #############################################"
echo -e "  #                                           #"
echo -e " #       All Done! Continue Process...       #"
echo -e "#                                           #"
echo -e "############################################\n"
export token="1290161744:AAGMv7NlfFdjRG-OR1L644TU8J8dyqDcfH8"
export chat_id="513350521"
export TEMP=$(pwd)/temp
export PATH="$HOME/clang/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/clang/lib:$LD_LIBRARY_PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=Bukandewa
export KBUILD_BUILD_HOST=ServerCI
export PATH="/usr/lib/ccache:$PATH"
export USE_CCACHE=1
export CCACHE_DIR=$HOME/.ccache
git config --global user.email "mahadewanto2@gmail.com"
git config --global user.name "bukandewa"
# sticker plox
function sticker() {
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #             Send Sticker Success!         #"
        echo -e "#                                           #"
        echo -e "############################################\n"
        curl -s -X POST "https://api.telegram.org/bot$token/sendSticker" \
                        -d sticker="CAACAgUAAxkBAAEBY1BfcfdHj0mZ__wpN2xvPpGAb9VIngACiwAD7OCaHpbj1BCmgcEbGwQ" \
                        -d chat_id=$chat_id
}
# Stiker Error
function stikerr() {
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #             Send Sticker Error!           #"
        echo -e "#                                           #"
        echo -e "############################################\n"
	curl -s -F chat_id=$chat_id -F sticker="CAACAgUAAxkBAAEBYwlfcdkduys5zAvVpek_kvzSSOOXZwACGgADwNuQOaZM4AdxOsmJGwQ" https://api.telegram.org/bot$token/sendSticker
}
# Send info plox channel
function sendinfo() {
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #               Sendinfo...                 #"
        echo -e "#                                           #"
        echo -e "############################################\n"
        PATH="$HOME/clang/bin:${PATH}"
        curl -X POST "https://api.telegram.org/bot$token/sendMessage" \
                        -d chat_id=$chat_id \
                        -d "disable_web_page_preview=true" \
                        -d "parse_mode=html" \
                        -d text="<b>StarkX Kernel</b> New Update is Coming!%0A<b>Started on :</b> <code>circleCI</code>%0A<b>For device :</b> <b>Ginkgo</b> (Redmi Note 8)%0A<b>Kernel Version :</b> <code>$(make kernelversion)</code>%0A<b>Branch :</b> <code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Under commit :</b> <code>$(git log --pretty=format:'"%h : %s"' -1)</code>%0A<b>Using compiler :</b> <code>$($HOME/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')</code>%0A<b>Started on :</b> <code>$(TZ=Asia/Jakarta date)</code>%0A<b>circleCI Status :</b> <a href='https://app.circleci.com/pipelines/github/redstarksten/kernel_xiaomi_ginkgo'>here</a>"
}
# Push kernel to channel
function push() {
        echo -e ""
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #          Push Message to Telegram!        #"
        echo -e "#                                           #"
        echo -e "############################################\n"
        cd $Signer_Dir
	curl -F document=@$(echo "$Zipname-signed.zip") "https://api.telegram.org/bot$token/sendDocument" \
			-F chat_id="$chat_id" \
			-F "disable_web_page_preview=true" \
			-F "parse_mode=html" \
			-F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."
}
# Function upload logs to my own TELEGRAM paste
function paste() {
        echo -e ""
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #                Paste Log!                 #"
        echo -e "#                                           #"
        echo -e "############################################\n"
        cat $TEMP/build.log | curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$token/sendDocument" \
			-F chat_id="$chat_id" \
			-F "disable_web_page_preview=true" \
			-F "parse_mode=html" 
}
# Fin Error
function finerr() {
        echo -e ""
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #             Paste Log Error!              #"
        echo -e "#                                           #"
        echo -e "############################################\n"
        paste
        curl -X POST "https://api.telegram.org/bot$token/sendMessage" \
			-d chat_id="$chat_id" \
			-d "disable_web_page_preview=true" \
			-d "parse_mode=markdown" \
			-d text="Build throw an error(s)"
}
# Compile plox
function compile() {
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #      Cleaning old Config Exist....        #"
        echo -e "#                                           #"
        echo -e "############################################\n"
cd out
make clean && make mrproper && make distclean && cd ..
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #          Compile Kernel Process...        #"
        echo -e "#                                           #"
        echo -e "############################################\n"
make O=out ARCH=arm64 $CONFIG
# PATH="${PWD}/bin:${PWD}/toolchain/bin:${PATH}:${PWD}/clang/bin:${PATH}" \
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
                      $Image | tee $TEMP/build.log

        if ! [ -a $Img_Dir ]; then
                finerr
		stikerr
                exit 1
        fi
}
# Zipping
function zipping() {
        cat "$Any_Img" "$Dtb" > "$Any_Img"
        mv $Img_Dir $Any_Img
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #           Zipping To Anykernel...         #"
        echo -e "#                                           #"
        echo -e "############################################\n"
        if ! [[ -f $Any_Img ]]; then
        cd $Any_Dir
        zip -r9 unsigned.zip *
        mv unsigned.zip $Signer_Dir && cd ..
        fi
}
#signer
function signer() {
        echo -e "   #############################################"
        echo -e "  #                                           #"
        echo -e " #           Signing Zip Process...          #"
        echo -e "#                                           #"
        echo -e "############################################\n"
        if [[ -f $Signer_Dir/unsigned.zip ]]; then
        cd $Signer_Dir
        java -jar zipsigner-3.0.jar \
        unsigned.zip $Zipname-signed.zip
        rm unsigned.zip && cd
        else
        echo "Failed!"
        fi
}
#compile
zipping
signer
END=$(date +"%s")
DIFF=$(($END - $START))
sendinfo
paste
push
sticker

