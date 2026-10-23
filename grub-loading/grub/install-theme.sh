#!/usr/bin/env bash
# ============================================================================
# install-theme.sh — установка финальной темы GRUB noto_menu.
#
# Что делает:
#   1. Проверяет, что запущен на Arch с GRUB.
#   2. Делает резервную копию /etc/default/grub, /boot/grub/grub.cfg,
#      /etc/grub.d/40_custom и старого каталога темы.
#   3. Копирует готовую тему в /boot/grub/themes/noto_menu.
#   4. Аккуратно выставляет только визуальные ключи GRUB:
#        GRUB_THEME, GRUB_GFXMODE, GRUB_GFXPAYLOAD_LINUX,
#        GRUB_TIMEOUT, GRUB_TIMEOUT_STYLE.
#   5. Пересобирает /boot/grub/grub.cfg через grub-mkconfig.
#
# Чего НЕ делает (намеренно):
#   * не запускает grub-install;
#   * не меняет NVRAM/BootOrder;
#   * не отключает 10_linux/30_uefi-firmware/31_efi_bootnext;
#   * не устанавливает статическое меню из 40_custom.example;
#   * не трогает Windows и разделы SSD.
#
# Почему так: установщик темы не должен делать систему незагружаемой.
# Статическое меню — отдельное осознанное действие, см. 40_custom.example.
#
# Запуск:
#   sudo bash install-theme.sh
# ============================================================================
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_SRC="$BASE/theme"
THEME_DST="/boot/grub/themes/noto_menu"
DEFAULT_GRUB="/etc/default/grub"
GRUB_CFG="/boot/grub/grub.cfg"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/grub-loading-backup-$STAMP"

die() { echo "ОШИБКА: $*" >&2; exit 1; }
say() { echo; echo "== $* =="; }

[ "$(id -u)" -eq 0 ] || die "запускай с sudo: sudo bash install-theme.sh"
[ -f /etc/arch-release ] || echo "ПРЕДУПРЕЖДЕНИЕ: это не похоже на Arch Linux."
command -v pacman >/dev/null 2>&1 || die "нет pacman — это не Arch?"
command -v grub-mkconfig >/dev/null 2>&1 || die "нет grub-mkconfig. Установи GRUB: pacman -S grub"
[ -f "$DEFAULT_GRUB" ] || die "нет $DEFAULT_GRUB"
[ -d /boot/grub ] || die "нет /boot/grub. Проверь, смонтирован ли /boot."
[ -d "$THEME_SRC" ] || die "нет каталога темы: $THEME_SRC"

for f in theme.txt caption_0.png plate_c.png plate_hi_c.png NotoSans-Regular-24.pf2; do
  [ -f "$THEME_SRC/$f" ] || die "в комплекте нет $f — тема неполная"
done

say "Шаг 1. Резервная копия"
mkdir -p "$BACKUP"
cp "$DEFAULT_GRUB" "$BACKUP/default.grub"
[ -f "$GRUB_CFG" ] && cp "$GRUB_CFG" "$BACKUP/grub.cfg"
[ -f /etc/grub.d/40_custom ] && cp /etc/grub.d/40_custom "$BACKUP/40_custom"
if [ -d "$THEME_DST" ]; then
  cp -r "$THEME_DST" "$BACKUP/theme-old"
fi
echo "  сохранено в: $BACKUP"

say "Шаг 2. Установка темы"
mkdir -p "$(dirname "$THEME_DST")"
rm -rf "$THEME_DST"
cp -r "$THEME_SRC" "$THEME_DST"
echo "  тема: $THEME_DST"

say "Шаг 3. Настройки /etc/default/grub"
python3 - "$DEFAULT_GRUB" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
values = {
    "GRUB_TIMEOUT": "-1",
    "GRUB_TIMEOUT_STYLE": "menu",
    "GRUB_GFXMODE": "1600x900x32",
    "GRUB_GFXPAYLOAD_LINUX": "keep",
    "GRUB_THEME": '"/boot/grub/themes/noto_menu/theme.txt"',
}
lines = text.splitlines()
seen = set()
out = []
for line in lines:
    m = re.match(r"^\s*(GRUB_[A-Z0-9_]+)\s*=", line)
    if m and m.group(1) in values:
        key = m.group(1)
        out.append(f"{key}={values[key]}")
        seen.add(key)
    else:
        out.append(line)
for key, value in values.items():
    if key not in seen:
        out.append(f"{key}={value}")
path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY

echo "  изменения:"
diff -u "$BACKUP/default.grub" "$DEFAULT_GRUB" || true

say "Шаг 4. Пересборка grub.cfg"
grub-mkconfig -o "$GRUB_CFG"

say "Шаг 5. Проверка"
grep -q 'desktop-color: "#000000"' "$THEME_DST/theme.txt" \
  || die "в theme.txt нет desktop-color #000000"
if grep -q 'desktop-image' "$THEME_DST/theme.txt"; then
  die "в theme.txt остался desktop-image — фон не будет чёрным"
fi
grep -q 'GRUB_THEME=' "$DEFAULT_GRUB" \
  || die "GRUB_THEME не записался в $DEFAULT_GRUB"
grep -q 'noto_menu' "$GRUB_CFG" \
  || echo "ПРЕДУПРЕЖДЕНИЕ: в grub.cfg не найден noto_menu; проверь GRUB_THEME."

echo
echo "ГОТОВО. Тема установлена."
echo "Резервная копия: $BACKUP"
echo
echo "Дальше:"
echo "  1) Если нужен ровно три пункта — настрой 40_custom.example (см. README)."
echo "  2) Для заставки Plymouth — plymouth/install-theme.sh."
echo "  3) Перезагрузка: sudo reboot."
echo
echo "Если после перезагрузки меню текстовое/без темы:"
echo "  проверь GRUB_GFXMODE и GRUB_THEME, затем снова grub-mkconfig."
echo "Откат: скопируй $BACKUP/default.grub обратно и выполни grub-mkconfig."
