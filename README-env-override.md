# Фиксированный bootcmd независимо от env

## Проблема

`bootcmd` из сохранённого env перебивал желаемую последовательность загрузки.
Нужно было жёстко задать `bootcmd` при каждом старте, не отказываясь от `saveenv`.

## Решение

Используется хук `rk_board_late_init()` — он вызывается после загрузки env,
поэтому `env_set()` внутри него всегда перекрывает сохранённое значение.

### 1. `configs/napi-rk3308_defconfig`

```
CONFIG_BOARD_LATE_INIT=y
```

### 2. `board/rockchip/evb_rk3308/evb_rk3308.c`

```c
#include <env.h>

int rk_board_late_init(void)
{
	env_set("bootcmd",
		"setenv fdt_addr_r 0x01e00000;"
		"setenv kernel_addr_r 0x02080000;"
		"setenv ramdisk_addr_r 0x06000000;"
		"setenv kernel_comp_addr_r 0x08000000;"
		"setenv kernel_comp_size 0x04000000;"
		"bootflow scan");
	return 0;
}
```

## Почему не `CONFIG_BOOTCOMMAND`

`CONFIG_BOOTCOMMAND` задаёт дефолт, но сохранённый env его перебивает.
`rk_board_late_init()` выполняется **после** загрузки env — переменная
всегда выставляется в нужное значение независимо от содержимого env.

## Почему `rk_board_late_init`, а не `board_late_init`

В `arch/arm/mach-rockchip/board.c` уже определён `board_late_init()`,
который вызывает `rk_board_late_init()` как weak-хук. Переопределять
`board_late_init()` нельзя — линкер выдаст ошибку multiple definition.

## Адреса памяти

| Переменная           | Адрес        | Назначение            |
|----------------------|--------------|-----------------------|
| `fdt_addr_r`         | `0x01e00000` | Device Tree           |
| `kernel_addr_r`      | `0x02080000` | Ядро (несжатое)       |
| `ramdisk_addr_r`     | `0x06000000` | initrd                |
| `kernel_comp_addr_r` | `0x08000000` | Буфер распаковки ядра |
| `kernel_comp_size`   | `0x04000000` | Размер буфера (64 МБ) |
