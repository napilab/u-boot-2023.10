#!/bin/bash
set -e

TOOLS=~/d400/napi-mainline-uboot-tool/tools
BLOBS=~/d400/napi-mainline-uboot-tool/blobs
BL31=~/d400/rkbin/bin/rk33/rk3308_bl31_v2.27.elf
OUT=~/d400/rosa-data/bootloader-napic

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cd $TMPDIR

echo "Building idbloader.bin..."
mkimage -n rk3308 -T rksd -d "${BLOBS}/rk3308_ddr_589MHz_uart0_m0_v2.07.bin" idbloader.bin
cat "${BLOBS}/rk3308_miniloader_v1.39.bin" >> idbloader.bin

echo "Building uboot.img..."
${TOOLS}/loaderimage --pack --uboot "${BLOBS}/u-boot-dtb.bin" uboot.img 0x600000

echo "Building trust.bin with BL31 v2.27..."
cat > trust.ini << 'TRUSTEOF'
[VERSION]
MAJOR=1
MINOR=0
[BL30_OPTION]
SEC=0
[BL31_OPTION]
SEC=1
PATH=bl31.elf
ADDR=0x10000
[BL32_OPTION]
SEC=0
[BL33_OPTION]
SEC=0
[OUTPUT]
PATH=trust.bin
TRUSTEOF
${TOOLS}/trust_merger --replace bl31.elf "${BL31}" trust.ini

mkdir -p $OUT
cp idbloader.bin uboot.img trust.bin $OUT/
echo "Done! Files in $OUT"
ls -la $OUT/
