#!/bin/bash
echo -e "Script by :\n"
echo -e "#####  #    # #    #   ##   ##   # ####   #######     #   ## " 
echo -e "#    # #    # #  ##    ##   ###  # #   ## #     #  #  #   ## "
echo -e "###### #    # ###     #  #  # ## # #    # ####### ### #  #  # "
echo -e "#    # #    # #  ##   ####  #  # # #    # #      ## ###  #### "
echo -e "###### ###### #   ## #    # #   ## #####  ###### #   #  #    #\n"

SECONDS=0
export ARCH=arm64
#export KBUILD_BUILD_VERSION=#1
export KBUILD_BUILD_USER=bukandewa
export KBUILD_BUILD_HOST=pro
export PATH="$HOME/proton-clang/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/tc-build/install/lib:$LD_LIBRARY_PATH"
#export DTC_EXT=dtc
export KBUILD_COMPILER_STRING="$("$HOME"/proton-clang/bin/clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' -e 's/^.*clang/clang/')"
git config --global user.email "mahadewanto2@gmail.com"
git config --global user.name "bukandewa"

KERNEL_DIR=$(pwd)
IMAGE_DIR=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
DTB_DIR=$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/trinket.dtb
KERNEL_NAME=EndLesS
KERNEL_VER=RC2.1
TANGGAL=$(date '+%Y%m%d')
ZIPNAME="$KERNEL_NAME"-"$KERNEL_VER"-"$TANGGAL"
CONFIG=vendor/ginkgo-perf_defconfig

function checker() {
CHECK1=$KERNEL_DIR/out
if [[ -d "$CHECK1" ]]; then
cd out
echo "==========================================="
echo -e "Old config is exist! Clean first..."
echo "==========================================="
echo "==========================================="
echo -e "Cleaning process..."
echo "==========================================="
make clean && make mrproper && make distclean && cd ..
echo "===================================="
echo -e "Cleaning done! Continue..."
echo "===================================="
rm -rf $CHECK1
echo "==========================================="
echo -e "Checking Dependencies 1... OK! "
echo "==========================================="
fi

CHECK2=$KERNEL_DIR/Anykernel
if [[ -d "$CHECK2" ]]; then
echo "==========================================="
echo -e "Anykernel already exist. Continue..."
echo "==========================================="
echo "==========================================="
echo -e "Checking Dependencies 2... OK! "
echo "==========================================="
else
cd $KERNEL_DIR
echo "===================="
echo -e "Cloning Anykernel..."
echo "===================="
git clone https://github.com/redstarksten/Anykernel.git
fi

CHECK3=$KERNEL_DIR/signer/zipsigner-3.0.jar
if [[ -f "$CHECK3" ]]; then
echo "==========================================="
echo -e "zipsigner already exist. Continue..."
echo "==========================================="
echo "==========================================="
echo -e "Checking Dependencies 3... OK!"
echo "==========================================="
else
echo "===================="
echo -e "Cloning zigpsigner..."
echo "===================="
mkdir signer && curl -sLo signer/zipsigner-3.0.jar https://raw.githubusercontent.com/najahiiii/Noob-Script/noob/bin/zipsigner-3.0.jar
echo "==========================================="
echo -e "All dependencies ready. Continue..."
echo "==========================================="
fi
}

# Compile
function compile() {
    echo "==========================================="
    echo -e "Create Defconfig process..."
    echo "==========================================="
    make -j"$(nproc)" O=out $CONFIG > /dev/null
    echo "==========================================="
    echo -e "Compile kernel process...\nUse :"
    echo "==========================================="
    echo "$("$HOME"/proton-clang/bin/clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' -e 's/^.*clang/clang/')"
    echo "==========================================="
    make O=out -j$(nproc) \
                    CC="clang" \
                    CXX="clang++" \
                    LD="ld.lld" \
                    AR="llvm-ar" \
                    NM="llvm-nm" \
                    OBJCOPY="llvm-objcopy" \
                    OBJDUMP="llvm-objdump" \
                    STRIP="llvm-strip" \
                    CLANG_TRIPLE=aarch64-linux-gnu- \
                    CROSS_COMPILE=aarch64-linux-gnu- \
                    CROSS_COMPILE_ARM32=arm-linux-gnueabi-\
                    Image.gz-dtb
}

# Zipping
function zipping() {
    if [[ -f $IMAGE_DIR ]]; then
    echo "==========================================="
    echo -e "Copying Image.gz-dtb to Anykernel folder"
    echo "==========================================="
    cp $IMAGE_DIR Anykernel/Image.gz-dtb
    echo "==========================================="
    echo -e "Copying dtb file to Anykernel folder"
    echo "==========================================="
    cp -f $DTB_DIR Anykernel/dts/trinket.dtb
    cd Anykernel
    echo "==========================================="
    echo -e "Zipping process..."
    echo "==========================================="
    zip -r9 unsigned.zip *
    echo "==========================================="
    echo -e "Zipping success! "
    echo "==========================================="
    mv unsigned.zip ../signer/
    rm -r *zip *dtb
    cd dts && rm trinket.dtb
    cd .. && cd ..
    else
    echo "Failed!"
    fi
}

#signer
function signer() {
	if [[ -f "$KERNEL_DIR/signer/unsigned.zip" ]]; then
	echo "==========================================="
	echo -e "Entering signer folder"
	echo "==========================================="
	cd signer
	echo "==========================================="
	echo -e "Removing old zip..."
	echo -e "==========================================="
	echo "==========================================="
	echo -e "Signing process..."
	echo "==========================================="
	java -jar zipsigner-3.0.jar \
	unsigned.zip $ZIPNAME-signed.zip
	echo "==========================================="
	echo -e "Signing zip success! "
	echo "==========================================="
	rm unsigned.zip
	else
	echo "Failed!"
	fi
}

#upload_gdrive
function gdrive() {
    if [[ -f "$ZIPNAME-signed.zip" ]]; then
    echo "==========================================="	
    echo -e "Uploading process..."
    echo "==========================================="
    cp $ZIPNAME-signed.zip /run/user/1000/gvfs/google-drive:host=gmail.com,user=mahadewanto2/1LGS8Afn9iMZjcQ02nTz1b7_gfHbiZK_B
    echo "==========================================="
    echo -e "Upload to gdrive success!"
    echo "==========================================="
    cd ..
    else
    echo "Failed!"
    	fi
}

checker
compile
zipping
signer
gdrive
echo -e "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"

