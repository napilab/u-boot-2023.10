# Mainline U-Boot 2023.10 для NAPI-C (NNZ Napi C Classic, RK3308)

## Статус

| Функция | Статус |
|---|---|
| eMMC (proper U-Boot) | ✅ работает, 52MHz HS |
| SD-карта | ✅ работает |
| USB host (EHCI) | ✅ работает, boot с USB подтверждён |
| Ethernet | ⚠️ инициализируется, MAC не задан |
| USB gadget / DFU | не тестировалось |

Тег: `napi-c-mainline-v2`

---

## Зачем mainline, если есть vendor U-Boot 2017.09?

Vendor U-Boot (`~/d400/uboot-vendor-2017`, тег `napi-c-v4`) полностью рабочий и
используется в production. Mainline порт нужен для тех, кто хочет современный
U-Boot без vendor-патчей Rockchip.

**Важно:** mainline U-Boot 2024.10 на RK3308 имеет регрессию eMMC — CMD8/CMD2
timeout в proper U-Boot (eMMC видна в SPL но не в proper). Воспроизводится на
rock-pi-s defconfig, не связано с нашим портом. Поэтому используется 2023.10.

---

## Что изменено относительно стокового U-Boot 2023.10

### Коммит 1 — `napi-c-mainline-v1`: минимальный порт, eMMC

**Новые файлы:**

`configs/napi-rk3308_defconfig` — defconfig на базе `rock-pi-s_defconfig` с
изменённым `CONFIG_DEFAULT_DEVICE_TREE="rk3308-napi-c"`.

`arch/arm/dts/rk3308-napi-c.dts` — DTS на базе `rk3308-rock-pi-s.dts`. Изменены
только две строки:
```
model = "NNZ Napi C (Classic)";
compatible = "nnz,napi-c", "rockchip,rk3308";
```
Всё остальное (MMC, pinctrl, регуляторы, сеть) унаследовано от rock-pi-s.

`arch/arm/dts/rk3308-napi-c-u-boot.dtsi` — U-Boot-специфичные дополнения:
boot-order (eMMC → SD), bootph-метки для uart0/pinctrl/rtc.

**Изменённые файлы:**

`arch/arm/dts/Makefile` — добавлена строка сборки `rk3308-napi-c.dtb`.

`.gitignore` — приведён к стандартному виду.

### Коммит 2 — `napi-c-mainline-v2`: USB host

**Проблема:** в `rk3308.dtsi` от mainline 2023.10 USB-ноды отсутствуют полностью
(в отличие от vendor 2017.09 и mainline 2024.10). Драйверы USB скомпилены в
defconfig (унаследованы от rock-pi-s), но описывать им нечего.

**Решение:** USB-узлы добавлены в `rk3308-napi-c-u-boot.dtsi` — наш файл,
апстрим не затронут.

Структура узлов взята из mainline 2024.10 (`usb2phy_grf` как `syscon@ff008000` с
вложенной `u2phy@100`). Compatible для `u2phy` использован из vendor 2017.09
(`rockchip,rk3328-usb2phy`) — именно его поддерживает драйвер
`phy-rockchip-inno-usb2.c` в версии 2023.10. Compatible `rockchip,rk3308-usb2phy`
появился позже и в 2023.10 не поддерживается.

Включён `usb_host0_ehci` (EHCI generic). OTG (`usb20_otg`) оставлен `disabled`.
OHCI не включён (достаточно для USB 2.0 HS устройств).

В defconfig добавлена одна строка:
```
CONFIG_PHY_ROCKCHIP_INNO_USB2=y
```

---

## Boot chain

Vendor-style (Rockchip miniloader), **не** binman/SPL/BL31:

```
miniloader → trust.img (ATF) → u-boot-dtb.bin (proper U-Boot)
```

Прошивка через `~/d400/napi-mainline-uboot-tool/napiwrt-mainline-uboot.sh`.

---

## Сборка

```bash
cd ~/d400/u-boot-2023.10
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64
make napi-rk3308_defconfig
make -j$(nproc)
```

Результат: `u-boot-dtb.bin`

---

## Прошивка в OpenWrt-образ

```bash
cp u-boot-dtb.bin ~/d400/napi-mainline-uboot-tool/blobs/u-boot-dtb.bin

~/d400/napi-mainline-uboot-tool/napiwrt-mainline-uboot.sh \
    /path/to/openwrt-rockchip-armv8-napilab_napic-ext4-sysupgrade.img.gz
```

---

## Проверка eMMC и USB в U-Boot shell

```
=> mmc info
=> usb start
=> usb tree
```

---

## Известные ограничения

- **MAC-адрес** не задан — `ethernet@ff4e0000 address not set`. Это нормально для
  U-Boot; OpenWrt получает MAC из своего хранилища после загрузки.
- **USB gadget / DFU** не тестировался. OTG-порт оставлен `disabled`.
- **OHCI** не включён. Устройства USB 1.1 low-speed (некоторые старые мыши,
  клавиатуры) работать не будут.
