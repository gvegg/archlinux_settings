# Установка grub-loading на новую систему

Это пошаговая инструкция для **чистой системы Arch Linux**, на которой уже
установлен и работает GRUB. Комплект не устанавливает загрузчик: он меняет
только тему GRUB и заставку Plymouth.

Если GRUB ещё не установлен, сначала установи и настрой его обычным способом
(`grub-install` + `grub-mkconfig`), убедись, что система загружается, и только
потом возвращайся сюда.

---

## 0. Что проверить до начала

```bash
# Arch?
cat /etc/arch-release

# GRUB и mkinitcpio есть?
command -v grub-mkconfig
command -v mkinitcpio

# /boot смонтирован?
findmnt /boot
ls -l /boot/vmlinuz-linux /boot/initramfs-linux.img

# UEFI или BIOS?
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS

# Разрешение/режим, который умеет GRUB
# (в меню GRUB можно проверить videoinfo в командной строке)
```

Комплект рассчитан на **1600×900**. Если у новой системы другое разрешение,
см. раздел «Другое разрешение» в конце и [`GRUB.md`](GRUB.md).

Скопируй папку `grub-loading` на новую систему, например в
`/root/grub-loading` или `~/grub-loading`. Все команды ниже выполняются из
корня этой папки.

Перед установкой проверь целостность (необязательно, но полезно после
передачи папки по сети или через флешку):

```bash
cd /path/to/grub-loading
sha256sum -c checksums.sha256
```

---

## 1. Тема GRUB

```bash
cd /path/to/grub-loading
sudo bash grub/install-theme.sh
```

Скрипт:

1. делает бэкап в `/root/grub-loading-backup-<дата>/`;
2. копирует `grub/theme/` в `/boot/grub/themes/noto_menu`;
3. выставляет в `/etc/default/grub`:
   - `GRUB_THEME="/boot/grub/themes/noto_menu/theme.txt"`
   - `GRUB_GFXMODE=1600x900x32`
   - `GRUB_GFXPAYLOAD_LINUX=keep`
   - `GRUB_TIMEOUT=-1`
   - `GRUB_TIMEOUT_STYLE=menu`
4. выполняет `grub-mkconfig -o /boot/grub/grub.cfg`.

Скрипт **не** отключает генераторы меню и **не** ставит `40_custom`. Поэтому
после него тема уже видна, но пунктов может быть больше трёх (стандартные
Arch, advanced, UEFI firmware и т.п.). Это безопасный режим: установщик темы
не может сделать систему незагружаемой.

Проверка:

```bash
grep -E 'desktop-color|desktop-image' /boot/grub/themes/noto_menu/theme.txt
grep -E 'GRUB_THEME|GRUB_GFXMODE|GRUB_TIMEOUT' /etc/default/grub
```

Ожидаемо: `desktop-color: "#000000"`, `desktop-image` отсутствует.

---

## 2. Ровно три пункта меню (опционально)

Нужно, если требуется точная композиция: `Arch Linux`, `Windows`,
`UEFI BIOS`, без «Advanced options» и без лишних записей.

### 2.1. Узнай UUID и пути

```bash
findmnt -no UUID /
findmnt -no UUID /boot
lsblk -f
ls -l /boot/vmlinuz-linux /boot/initramfs-linux.img
```

Если `/boot` — отдельный раздел:

- `__BOOT_UUID__` = UUID раздела `/boot`;
- `__ROOT_UUID__` = UUID корня `/`;
- пути в menuentry: `/vmlinuz-linux`, `/initramfs-linux.img`.

Если `/boot` лежит внутри корня:

- `__BOOT_UUID__` = `__ROOT_UUID__` = UUID корня;
- пути: `/boot/vmlinuz-linux`, `/boot/initramfs-linux.img`.

### 2.2. Отредактируй шаблон

```bash
cp grub/40_custom.example /tmp/40_custom
nano /tmp/40_custom
```

Замени:

- `__BOOT_UUID__` — UUID загрузочного раздела;
- `__ROOT_UUID__` — UUID корня;
- при необходимости пути к ядру/initramfs;
- `bootnext 0001` — на номер Windows Boot Manager из `efibootmgr -v`
  (или удали пункт Windows, если Windows нет);
- пункт `UEFI BIOS` — оставь только на UEFI, иначе удали.

Шаблон уже содержит:

```text
quiet loglevel=0 systemd.show_status=no udev.log_level=0 splash
```

`splash` обязателен для Plymouth. `quiet`/`loglevel`/`show_status` убирают
текст с экрана; если хочешь видеть диагностику — убери их, но оставь
`splash`.

### 2.3. Установи меню

```bash
# бэкап текущего 40_custom
sudo cp /etc/grub.d/40_custom \
        /root/40_custom.backup-$(date +%Y%m%d-%H%M%S)

sudo cp /tmp/40_custom /etc/grub.d/40_custom
sudo chmod +x /etc/grub.d/40_custom

# отключаем автоматические генераторы, иначе пунктов будет больше
sudo chmod -x /etc/grub.d/10_linux \
              /etc/grub.d/30_uefi-firmware \
              /etc/grub.d/31_efi_bootnext 2>/dev/null || true

sudo grub-mkconfig -o /boot/grub/grub.cfg
```

**Не запускай `grub-install`.** Он не нужен и может изменить NVRAM.

Проверка:

```bash
grep -nE "menuentry|linux|initrd|bootnext|fwsetup" /etc/grub.d/40_custom
grep -n "noto_menu" /boot/grub/grub.cfg
```

Если пунктов всё равно больше трёх, проверь, что `10_linux`,
`30_uefi-firmware`, `31_efi_bootnext` действительно не executable:

```bash
ls -l /etc/grub.d/
```

Вернуть автоматические пункты: `sudo chmod +x` тем же файлам и снова
`grub-mkconfig`.

### 2.4. Если ядро не `linux`

Шаблон использует `/vmlinuz-linux` и `/initramfs-linux.img`. Для `linux-lts`,
`linux-zen` и т.п. добавь отдельный `menuentry` с их путями. При обновлении
ядра статический пункт сам не появится — это осознанная цена трёх пунктов.

---

## 3. Заставка Plymouth

```bash
# из корня grub-loading
sudo bash plymouth/install-theme.sh
```

Скрипт:

1. делает бэкап в `/root/grub-loading-plymouth-backup-<дата>/`;
2. при необходимости ставит `plymouth`:
   `pacman -S --needed --noconfirm plymouth`;
3. копирует `plymouth/theme/` в
   `/usr/share/plymouth/themes/arch-waves`;
4. добавляет `plymouth` в `HOOKS` сразу после `systemd`;
5. добавляет `splash` в `GRUB_CMDLINE_LINUX_DEFAULT` (если файл есть);
6. выбирает тему `arch-waves`;
7. выполняет `mkinitcpio -P`;
8. если есть GRUB, выполняет `grub-mkconfig`.

### Важно про статическое меню

`GRUB_CMDLINE_LINUX_DEFAULT` **не применяется** к ручному `menuentry` из
`40_custom`. Если ты выбрал три пункта, `splash` должен быть прямо в строке
`linux` этого файла. В шаблоне он уже есть.

Если используешь стандартное меню GRUB, установщик Plymouth добавит `splash`
в `GRUB_CMDLINE_LINUX_DEFAULT` сам.

Установщик также смотрит на `/etc/grub.d/40_custom`: если там есть активная
строка `linux` без `splash`, он выведет предупреждение — это значит, что
для статического меню параметр нужно добавить вручную.

### Проверка

```bash
plymouth-set-default-theme
grep -E '^HOOKS=' /etc/mkinitcpio.conf
lsinitcpio /boot/initramfs-linux.img | grep -E 'plymouthd|arch-waves'
```

Ожидаемо: тема `arch-waves`, `plymouth` в HOOKS, в initramfs есть `plymouthd`
и файлы темы.

---

## 4. Полная тишина при загрузке (опционально)

Скрипт Plymouth добавляет только `splash`. Чтобы не было текста ядра и
systemd, добавь в командную строку:

```text
quiet loglevel=0 systemd.show_status=no udev.log_level=0
```

Для стандартного меню:

```bash
sudo nano /etc/default/grub
# GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=0 systemd.show_status=no udev.log_level=0 splash"
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Для статического меню — прямо в `linux`-строку `/etc/grub.d/40_custom`,
затем `sudo grub-mkconfig -o /boot/grub/grub.cfg`.

Почему это опционально: `quiet` скрывает диагностику. Если система не
загружается, временно убери `quiet`/`loglevel`, чтобы увидеть ошибки.

---

## 5. Уменьшение чёрного промежутка (опционально)

Plymouth стартует из initramfs. Чем больше initramfs и чем позже
загружается KMS, тем длиннее пауза между GRUB и заставкой. На текущей
системе владельца `kms` был убран, а `i915` добавлен в `MODULES`; initramfs
уменьшился примерно со 131 МБ до 24 МБ.

**Это не обязательно для работы темы и потенциально опасно.** Не удаляй
`kms` вслепую: на другой видеокарте ранний KMS может быть нужен.

Проверь:

```bash
grep -E '^MODULES|^HOOKS' /etc/mkinitcpio.conf
```

Если в `MODULES` уже есть драйвер твоей видеокарты (например, `i915` для
Intel, `amdgpu` для AMD), можно попробовать:

```bash
sudo cp /etc/mkinitcpio.conf /root/mkinitcpio.conf.backup-$(date +%Y%m%d-%H%M%S)
sudo nano /etc/mkinitcpio.conf
# убрать kms из HOOKS, оставить драйвер в MODULES
sudo mkinitcpio -P
lsinitcpio -a /boot/initramfs-linux.img | head
```

Если после перезагрузки пропал экран/стал чёрный — верни `kms` в HOOKS,
`sudo mkinitcpio -P`, либо загрузись с `nomodeset` и восстанови конфиг.

Установщик Plymouth этого не делает намеренно: он не знает твою видеокарту.

---

## 6. Перезагрузка и проверка

```bash
sudo reboot
```

Ожидаемо:

1. Меню GRUB: чёрный фон, три белые плашки, синяя рамка у выбранной.
2. После Enter: чёрный фон Plymouth, логотип Arch, белая надпись
   «Arch Linux», без спиннера.
3. Затем логин `tty1`.
4. Выключение/перезагрузка: чёрный экран.

Если вид другой — [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

---

## 7. Откат

### Только Plymouth

```bash
sudo cp /root/grub-loading-plymouth-backup-<дата>/mkinitcpio.conf /etc/mkinitcpio.conf
sudo cp /root/grub-loading-plymouth-backup-<дата>/default.grub /etc/default/grub
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Только GRUB-тема

```bash
sudo cp /root/grub-loading-backup-<дата>/default.grub /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Старый каталог темы лежит в бэкапе как `theme-old/`; при необходимости
верни его в `/boot/grub/themes/noto_menu`.

### Аварийно

Если Plymouth мешает загрузке:

1. В меню GRUB нажми `e`.
2. В строке `linux` добавь `plymouth.enable=0`.
3. `Ctrl+X`.

Если не загружается графика — добавь `nomodeset`, загрузись и восстанови
конфиги из `/root/grub-loading-*backup-*`.

---

## 8. Другое разрешение

GRUB-тема — **пиксельная**, координаты и PNG рассчитаны на 1600×900.
Варианты:

1. **Форсировать 1600×900** через `GRUB_GFXMODE=1600x900x32`. Если монитор
   поддерживает режим, тема ляжет 1:1. Если нет — GRUB выберет другой режим,
   и координаты могут сместиться.
2. **Пересчитать тему** под своё разрешение:
   [`grub/tools/README.md`](../grub/tools/README.md). Нужны `noto-fonts` и
   `python-pillow`; `make_plates.py` — только stdlib.

Plymouth-заставка центрируется сама: она читает `Window.GetWidth()` и
`Window.GetHeight()`, поэтому на другом разрешении логотип и надпись
останутся по центру. Размеры логотипа (200 px) и надписи (72 px) фиксированы;
для другого DPI их можно заменить PNG-файлами.

---

## 9. Чего делать нельзя

- Не запускать `grub-install` без необходимости.
- Не менять BootOrder/NVRAM, кроме осознанного `bootnext` для Windows.
- Не трогать разделы Windows/SSD: комплект работает только с файлами
  `/boot`, `/etc` и `/usr/share/plymouth`.
- Не отключать `10_linux` и другие генераторы, не сделав бэкап и не
  убедившись, что `40_custom` содержит рабочий пункт Arch.
- Не удалять `kms` из HOOKS, если не знаешь, какой драйвер GPU у тебя в
  `MODULES`.
- Не копировать `theme.txt` в `/boot` через `cp -a`: `/boot` часто FAT32,
  владельцы не сохраняются; обычный `cp`/`cp -r` достаточно.
