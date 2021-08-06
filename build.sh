#!/bin/bash
#
# Copyright (c) 2021 CloudedQuartz
# Copyright (c) 2021 Diaz1401

CURRENT_DIR="$(pwd)"
KERNELNAME="Kucing"
KERNEL_DIR="$CURRENT_DIR"
AK_REPO="https://github.com/Diaz1401/AnyKernel3"
AK_DIR="$HOME/AnyKernel3"
TC_DIR="$HOME"
LOG="$HOME/log/log.txt"
LOG_DIR="$HOME/log/*"
KERNEL_IMG="$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
TG_CHAT_ID="-1001180467256"
TG_BOT_TOKEN="$TELEGRAM_TOKEN"
GCC_VER="$1" # write from 10 to 12, example: bash build.sh 11

#
# Export arch, subarch, etc
export ARCH="arm64"
export SUBARCH="arm64"
export KBUILD_BUILD_USER="Diaz"
export KBUILD_BUILD_HOST="DroneCI"

#
# Clone GCC Compiler
clone_tc() {
	git clone --depth=1 https://github.com/Diaz1401/gcc"$GCC_VER"-arm64 $TC_DIR/arm64
	git clone --depth=1 https://github.com/Diaz1401/gcc"$GCC_VER"-arm $TC_DIR/arm
}

#
# Clones anykernel
clone_ak() {
	git clone $AK_REPO $AK_DIR
}

#
# tg_sendinfo - sends text through telegram
tg_sendinfo() {
	curl -s "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
		-F parse_mode=html \
		-F text="${1}" \
		-F chat_id="${TG_CHAT_ID}" &> /dev/null
}

#
# tg_pushzip - uploads final zip to telegram
tg_pushzip() {
	curl -F document=@"$1"  "https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument" \
			-F chat_id=$TG_CHAT_ID \
			-F caption="$2" \
			-F parse_mode=html &> /dev/null
}

#
# tg_log - uploads build log to telegram
tg_log() {
    curl -F document=@"$LOG_DIR"  "https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument" \
        -F chat_id=$TG_CHAT_ID \
        -F parse_mode=html &> /dev/null
}

#
# build_setup - enter kernel directory
build_setup() {
    cd "$KERNEL_DIR"
    rm -rf out
    mkdir out
}

#
# build_config - builds .config file for device.
build_config() {
	make O=out kucing_defconfig -j$(nproc --all)
}

#
# build_kernel
build_kernel() {

    BUILD_START=$(date +"%s")
    make -j$(nproc --all) O=out \
                PATH="$TC_DIR/arm64/bin:$TC_DIR/arm/bin:$PATH" \
                CROSS_COMPILE=$TC_DIR/arm64/bin/aarch64-elf- \
                CROSS_COMPILE_ARM32=$TC_DIR/arm/bin/arm-eabi- |& tee $LOG

    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    DATE_NAME=$(date +"%A"_"%I":"%M"_"%p")
}

#
# build_end - creates and sends zip
build_end() {

	if ! [ -a "$KERNEL_IMG" ]; then
        echo -e "\n> Build failed, sed"
	mv $LOG $HOME/log/failed.txt
        tg_log
        exit 1
    fi

    echo -e "\n> Build successful! generating flashable zip..."
	cd "$AK_DIR" || echo -e "\nAnykernel directory ($AK_DIR) does not exist" || exit 1
	git clean -fd
	mv "$KERNEL_IMG" "$AK_DIR"/zImage
	ZIP_NAME=$KERNELNAME-GCC$GCC_VER-$DATE_NAME
	zip -r9 "$ZIP_NAME".zip ./* -x .git README.md ./*placeholder
        ZIP_NAME="$ZIP_NAME".zip

	echo -e "\n> Sent zip and log through Telegram."
	tg_pushzip "$ZIP_NAME" "Time taken: <code>$((DIFF / 60))m $((DIFF % 60))s</code>"
	sleep 5
	mv $LOG $HOME/log/success.txt
	tg_log
}

COMMIT=$(git log --pretty=format:"%s" -1)
COMMIT_SHA=$(git rev-parse --short HEAD)
KERNEL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_DATE=$(date)
CAPTION=$(echo -e \
"Build started
Date: <code>$BUILD_DATE</code>
HEAD: <code>$COMMIT_SHA</code>
Commit: <code>$COMMIT</code>
Branch: <code>$KERNEL_BRANCH</code>
")

#
# compile time
clone_tc
clone_ak
tg_sendinfo "$CAPTION
"
build_setup
build_config
build_kernel
build_end
