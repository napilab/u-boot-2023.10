#!/bin/bash
# pack-deb.sh - сборка vendor chain U-Boot и упаковка в deb для Napi-C
#
# Структура проекта u-boot-2023.10:
#   blobs/
#   ├── rk3308_ddr_589MHz_uart0_m0_v2.07.bin
#   ├── rk3308_miniloader_v1.39.bin
#   └── rk3308_bl31_v2.26.elf
#   tools/
#   ├── loaderimage
#   └── trust_merger
#   u-boot-dtb.bin            ← берётся из каталога сборки
#   pack-deb.sh               ← этот скрипт
#
# Использование: bash pack-deb.sh [версия]
# Пример:        bash pack-deb.sh 2023.10-1
#
# Результат: linux-u-boot-napic-current_<версия>_arm64.deb
# Скопируй его в make-napi-debian/uboot/

# --- Проверка интерпретатора ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Ошибка: запускай через bash, не sh:"
    echo "  bash $0 $*"
    exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOBS="${SCRIPT_DIR}/blobs"
TOOLS="${SCRIPT_DIR}/tools"
VERSION="${1:-2023.10}"

PKG_NAME="linux-u-boot-napic-current"
INSTALL_PATH="usr/lib/linux-u-boot-current-napic"
MAINTAINER="NapiLab <dj.novikov@gmail.com>"

DDR_BLOB="${BLOBS}/rk3308_ddr_589MHz_uart0_m0_v2.07.bin"
MINILOADER_BLOB="${BLOBS}/rk3308_miniloader_v1.39.bin"
BL31_BLOB="${BLOBS}/rk3308_bl31_v2.26.elf"
UBOOT_DTB="${SCRIPT_DIR}/u-boot-dtb.bin"

# --- Проверки ---
echo "Проверка файлов..."
for f in "${DDR_BLOB}" "${MINILOADER_BLOB}" "${BL31_BLOB}" "${UBOOT_DTB}"; do
    [[ -f "${f}" ]] || { echo "Ошибка: не найден ${f}"; exit 1; }
done
for t in loaderimage trust_merger; do
    [[ -x "${TOOLS}/${t}" ]] || { echo "Ошибка: не найден или не исполняемый ${TOOLS}/${t}"; exit 1; }
done
command -v mkimage &>/dev/null || { echo "Ошибка: не установлен mkimage (apt install u-boot-tools)"; exit 1; }

# --- Сборка компонентов ---
TMPDIR=$(mktemp -d)
PKGDIR=$(mktemp -d)
trap "rm -rf '${TMPDIR}' '${PKGDIR}'" EXIT

echo "Сборка idbloader.bin (DDR blob + miniloader)..."
mkimage -n rk3308 -T rksd -d "${DDR_BLOB}" "${TMPDIR}/idbloader.bin" >/dev/null
cat "${MINILOADER_BLOB}" >> "${TMPDIR}/idbloader.bin"

echo "Сборка uboot.img (u-boot-dtb.bin через loaderimage)..."
"${TOOLS}/loaderimage" --pack --uboot "${UBOOT_DTB}" "${TMPDIR}/uboot.img" 0x600000 >/dev/null 2>&1

echo "Сборка trust.bin (BL31 через trust_merger)..."
cat > "${TMPDIR}/trust.ini" << 'EOF'
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
EOF
(cd "${TMPDIR}" && "${TOOLS}/trust_merger" --replace bl31.elf "${BL31_BLOB}" trust.ini >/dev/null 2>&1)

for f in idbloader.bin uboot.img trust.bin; do
    [[ -f "${TMPDIR}/${f}" ]] || { echo "Ошибка: не удалось собрать ${f}"; exit 1; }
done

# --- Упаковка в deb ---
echo "Упаковка в deb..."
mkdir -p "${PKGDIR}/${INSTALL_PATH}"
mkdir -p "${PKGDIR}/DEBIAN"
mkdir -p "${PKGDIR}/usr/share/doc/${PKG_NAME}"

cp "${TMPDIR}/idbloader.bin" "${PKGDIR}/${INSTALL_PATH}/"
cp "${TMPDIR}/uboot.img"     "${PKGDIR}/${INSTALL_PATH}/"
cp "${TMPDIR}/trust.bin"     "${PKGDIR}/${INSTALL_PATH}/"

cat > "${PKGDIR}/DEBIAN/control" << EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Architecture: arm64
Maintainer: ${MAINTAINER}
Description: U-Boot for Napi-C (RK3308) - vendor chain
 Vendor boot chain for Napi-C board (RK3308 SoC).
 idbloader.bin: DDR init + miniloader  -> sector 64
 uboot.img:     U-Boot proper          -> sector 16384
 trust.bin:     BL31 (TF-A)            -> sector 24576
EOF

echo "${PKG_NAME} (${VERSION}) unstable; urgency=low

  * Custom build

 -- ${MAINTAINER}  $(date -R)" | gzip -9 > "${PKGDIR}/usr/share/doc/${PKG_NAME}/changelog.gz"

OUT_DEB="${SCRIPT_DIR}/${PKG_NAME}_${VERSION}_arm64.deb"
dpkg-deb --build --root-owner-group "${PKGDIR}" "${OUT_DEB}"

echo ""
echo "Готово: ${OUT_DEB}"
echo "Размер: $(du -sh "${OUT_DEB}" | cut -f1)"
echo ""
echo "Содержимое:"
dpkg-deb -c "${OUT_DEB}"
echo ""
echo "Скопируй в систему сборки:"
echo "  cp ${OUT_DEB} ~/d400/debian/make-napi-debian/uboot/"
