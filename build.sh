#!/bin/bash
# Сборка mainline U-Boot 2023.10 для NAPI-C (RK3308)
#
# Результат: u-boot-dtb.bin
# Этот файл копируется в ../napi-mainline-uboot-tool/blobs/u-boot-dtb.bin
# Затем запускается:
#   ../napi-mainline-uboot-tool/napiwrt-mainline-uboot.sh <image.img.gz>

set -e

export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64

make napi-rk3308_defconfig
make -j$(nproc) BL31=blobs/rk3308_bl31_v2.26.elf

echo ""
echo "=== Готово ==="
echo "Скопируйте результат:"
echo "  cp u-boot-dtb.bin ../napi-mainline-uboot-tool/blobs/u-boot-dtb.bin"
echo "Затем прошейте:"
echo "  ../napi-mainline-uboot-tool/napiwrt-mainline-uboot.sh <image.img.gz>"
