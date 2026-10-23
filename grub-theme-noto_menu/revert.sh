#!/bin/bash
# ============================================================================
# revert.sh — полный откат apply.sh к состоянию ДО изменения (без rm)
# Запуск:  cd <каталог-репозитория> && sudo bash revert.sh
# Берёт самый свежий ПОЛНЫЙ каталог backup-*/ (в нём есть grub.cfg).
# ============================================================================
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Шаг 0. Проверки =="
[ "$(id -u)" -eq 0 ] || { echo "ОШИБКА: запускай с sudo (sudo bash revert.sh)"; exit 1; }

LASTBKP=""
# Берём самый свежий бэкап, в котором есть grub.cfg.
for d in $(ls -1dt "$BASE"/backup-* 2>/dev/null || true); do
  if [ -f "$d/grub.cfg" ] || [ -f "$d/grub.cfg.orig" ]; then LASTBKP="$d"; break; fi
done
if [ -z "${LASTBKP:-}" ]; then
  echo "ОШИБКА: не найден полный backup-*/ с grub.cfg — откат невозможен."
  echo "  Бэкапы создаёт apply.sh. Если их нет, восстанови /etc/default/grub и"
  echo "  /boot/grub/grub.cfg вручную (см. FRESH-INSTALL.md, §12)."
  exit 1
fi
echo "Использую бэкап: $LASTBKP"
[ -f "$LASTBKP/grub.cfg" ] || [ -f "$LASTBKP/grub.cfg.orig" ] || { echo "ОШИБКА: в $LASTBKP нет grub.cfg — откат невозможен"; exit 1; }

CFG="/boot/grub/grub.cfg"
BKP_CFG="$LASTBKP/grub.cfg"; [ -f "$BKP_CFG" ] || BKP_CFG="$LASTBKP/grub.cfg.orig"
BKP_DEF="$LASTBKP/default.grub"; [ -f "$BKP_DEF" ] || BKP_DEF="$LASTBKP/default.grub.orig"

echo "== Шаг 1. Возвращаем генераторы меню (все, что отключались) =="
for f in 10_linux 30_uefi-firmware 31_efi_bootnext; do
  if [ -e "/etc/grub.d/$f" ]; then
    chmod +x "/etc/grub.d/$f" && echo "  chmod +x $f"
  fi
done
# (+ любая строка в enabled-scripts.txt из бэкапа apply-запуска)
if [ -f "$LASTBKP/enabled-scripts.txt" ]; then
  while read -r f; do
    if [ -n "$f" ] && [ -e "/etc/grub.d/$f" ]; then
      chmod +x "/etc/grub.d/$f" && echo "  chmod +x $f (из бэкапа)"
    fi
  done < "$LASTBKP/enabled-scripts.txt"
fi

echo "== Шаг 2. Восстанавливаем файлы =="
# /boot — vfat (FAT32): cp -a/-p ломаются на ownership → обычный cp
cp "$BKP_CFG" "$CFG"
cp "$BKP_DEF" /etc/default/grub
if [ -f "$LASTBKP/40_custom" ]; then
  cp "$LASTBKP/40_custom" /etc/grub.d/40_custom
  chmod +x /etc/grub.d/40_custom
else
  echo "ПРЕДУПРЕЖДЕНИЕ: в бэкапе нет 40_custom — оставляю текущий файл."
fi

echo "== Шаг 3. Перегенерация grub.cfg =="
grub-mkconfig -o "$CFG" 2>&1 | tail -5

echo "== Итог. Пункты меню: =="
grep -E "^menuentry" "$CFG" | head -12 || true
echo
echo "Откат завершён. Тема осталась в /boot/grub/themes/noto_menu (не мешает, строка GRUB_THEME убрана из default)."
