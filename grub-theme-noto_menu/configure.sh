#!/bin/bash
# ============================================================================
# configure.sh — генерирует 40_custom под текущую машину.
#
# Определяет:
#   * UUID корня и раздела /boot (или корня, если /boot не отдельный);
#   * тип ФС для insmod (fat/ext2/btrfs/xfs/f2fs);
#   * номер Windows Boot Manager в efibootmgr (для bootnext).
#
# Результат: ./40_custom (в .gitignore, в репозиторий не попадает).
# apply.sh вызывает этот скрипт автоматически, если 40_custom ещё нет
# или в нём остались заглушки @...@.
#
# Запуск:  bash configure.sh
# ============================================================================
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$BASE/40_custom.example"
OUT="$BASE/40_custom"

[ -f "$TPL" ] || { echo "ОШИБКА: нет шаблона $TPL"; exit 1; }

ROOT_UUID=$(findmnt -no UUID / 2>/dev/null || true)
[ -n "${ROOT_UUID:-}" ] || { echo "ОШИБКА: не удалось определить UUID корня (findmnt /)"; exit 1; }

# /boot отдельным разделом (как на большинстве UEFI-систем) или внутри корня?
BOOT_TARGET=$(findmnt -no TARGET /boot 2>/dev/null || true)
if [ -n "${BOOT_TARGET:-}" ]; then
  BOOT_UUID=$(findmnt -no UUID /boot 2>/dev/null || true)
  BOOT_FS=$(findmnt -no FSTYPE /boot 2>/dev/null || true)
  KERNEL_PREFIX=""
else
  BOOT_UUID="$ROOT_UUID"
  BOOT_FS=$(findmnt -no FSTYPE / 2>/dev/null || true)
  KERNEL_PREFIX="/boot"
fi
[ -n "${BOOT_UUID:-}" ] || { echo "ОШИБКА: не удалось определить UUID /boot"; exit 1; }

case "${BOOT_FS:-}" in
  vfat|fat)          INSMOD="fat" ;;
  ext2|ext3|ext4)    INSMOD="ext2" ;;
  btrfs)             INSMOD="btrfs" ;;
  xfs)               INSMOD="xfs" ;;
  f2fs)              INSMOD="f2fs" ;;
  *)
    INSMOD="ext2"
    echo "ПРЕДУПРЕЖДЕНИЕ: неизвестная ФС '${BOOT_FS:-?}', ставлю insmod ext2."
    echo "  Проверь строку insmod в 40_custom вручную."
    ;;
esac

# Windows Boot Manager: первый Boot#### с таким именем.
WIN=$(efibootmgr 2>/dev/null | awk 'tolower($0) ~ /windows boot manager/ {print $1; exit}' \
      | sed -e 's/^Boot//' -e 's/\*$//' || true)
if ! [[ "${WIN:-}" =~ ^[0-9A-Fa-f]{4}$ ]]; then
  WIN="0001"
  echo "ПРЕДУПРЕЖДЕНИЕ: Windows Boot Manager не найден в efibootmgr."
  echo "  Оставлен bootnext 0001. Если Windows нет — удали пункт Windows"
  echo "  и переделай тему на 2 пункта (FRESH-INSTALL.md, §10.1)."
fi

sed -e "s|@ROOT_UUID@|$ROOT_UUID|g" \
    -e "s|@BOOT_UUID@|$BOOT_UUID|g" \
    -e "s|@BOOT_INSMOD@|$INSMOD|g" \
    -e "s|@KERNEL_PREFIX@|$KERNEL_PREFIX|g" \
    -e "s|@WINDOWS_BOOTNUM@|$WIN|g" \
    "$TPL" > "$OUT"
chmod +x "$OUT"

echo "Готово: $OUT"
echo "  корень: UUID=$ROOT_UUID"
echo "  /boot:  UUID=$BOOT_UUID (${BOOT_FS:-?}, insmod $INSMOD, prefix '${KERNEL_PREFIX}')"
echo "  Windows: bootnext $WIN"
