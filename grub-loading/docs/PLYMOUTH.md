# Plymouth: как устроена заставка arch-waves

Plymouth — это ранняя графическая заставка, которая запускается из
initramfs и держит экран до появления логина или дисплей-менеджера.
В этой системе дисплей-менеджера нет: после заставки появляется обычный
текстовый логин `tty1`.

Заставка сделана на плагине **`script`**: это не готовый движок со
спиннером, а маленький скрипт, который сам создаёт спрайты и управляет
прозрачностью.

---

## 1. Внешний вид

| Параметр | Значение |
|---|---|
| Фон | чёрный `(0, 0, 0)` |
| Логотип | Arch, 200×200, `#1793d1`, без TM |
| Надпись | «Arch Linux», Noto Sans Regular 72 px, белая `#ffffff` |
| Отступ логотип → надпись | 30 px |
| Группа | по центру экрана |
| Анимация | плавное появление ~0.5 с |
| Спиннер | отсутствует |
| Выключение/перезагрузка | чёрный экран без надписей |

Для 1600×900:

```text
высота группы = 200 + 30 + 57 = 287
верх группы = (900 − 287) / 2 = 306.5
верх надписи = 306.5 + 200 + 30 = 536.5
```

Скрипт не хардкодит 1600×900: он берёт `Window.GetWidth()` и
`Window.GetHeight()` и центрирует группу. Поэтому на другом разрешении
композиция останется по центру; фиксированные размеры — только у PNG.

---

## 2. Файлы темы

```text
/usr/share/plymouth/themes/arch-waves/
├── arch-waves.plymouth   описание темы для Plymouth
├── arch-waves.script     скрипт отрисовки
├── arch-logo.png         логотип 200×200, RGBA
└── wordmark.png          «Arch Linux» 357×57, белая, RGBA
```

`arch-waves.plymouth`:

```ini
[Plymouth Theme]
Name=Arch Waves
Description=Чёрный фон, логотип Arch и белая надпись «Arch Linux»
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/arch-waves
ScriptFile=/usr/share/plymouth/themes/arch-waves/arch-waves.script
```

`ModuleName=script` означает, что Plymouth загрузит `arch-waves.script`.
`ImageDir` — каталог, относительно которого скрипт ищет PNG по имени.

---

## 3. Почему PNG, а не шрифт

В initramfs не нужно тащить TTF/FreeType: логотип и надпись — готовые
PNG. Plymouth умеет рисовать PNG с альфой, поэтому:

- надпись выглядит ровно так, как отрендерена (полный AA);
- в initramfs не нужны шрифты;
- проще гарантировать одинаковый вид на разных системах;
- меньше зависимостей и размер.

`wordmark.png` — белая надпись 72 px, `arch-logo.png` — синий логотип
200×200. Оба лежат в `plymouth/theme/` и копируются установщиком.

---

## 4. Фон

В скрипте:

```text
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);
```

Это задаёт чёрный фон окна Plymouth. Отдельного фонового спрайта нет.
Почему так:

- чёрный фон совпадает с GRUB, поэтому переход без белой вспышки;
- не нужен `bg-waves.png` и его лицензия;
- нет масштабирования картинки под разные разрешения;
- на выключении/перезагрузке достаточно не рисовать спрайты — фон уже
  чёрный.

---

## 5. Скрипт: пошагово

### 5.1. Режим

```text
global.mode = Plymouth.GetMode();
global.is_boot = (global.mode == "boot");
```

`Plymouth.GetMode()` возвращает режим (`boot`, `shutdown`, `reboot` и
другие служебные режимы).

- `boot` — рисуем логотип и надпись;
- `shutdown`/`reboot` — не рисуем ничего, остаётся чёрный экран.

### 5.2. Спрайты

```text
global.logo_image  = Image("arch-logo.png");
global.logo_sprite = Sprite(global.logo_image);

global.wordmark_image  = Image("wordmark.png");
global.wordmark_sprite = Sprite(global.wordmark_image);
```

Спрайты создаются один раз в `do_layout()`. Позиция задаётся
`SetPosition(x, y, z)`, где `z=10` — порядок относительно других
спрайтов. Фонового спрайта нет, поэтому чёрный фон окна виден везде.

### 5.3. Центрирование

```text
group_h = logo.height + gap + wordmark.height
group_top = (screen_height - group_h) / 2
logo_y = group_top
text_y = logo_y + logo.height + gap
logo_x = (screen_width - logo.width) / 2
text_x = (screen_width - wordmark.width) / 2
```

Это обычная математика центрирования. Она не зависит от 1600×900.

### 5.4. Появление

```text
Plymouth.SetRefreshRate(50);
Plymouth.SetRefreshFunction(refresh_callback);
```

Refresh-колбэк вызывается 50 раз в секунду. В нём:

```text
frame = frame + 1
fade = frame / 25   (пока frame < 25)
sprite.SetOpacity(fade)
```

25 кадров при 50 Гц ≈ 0.5 секунды. Логотип и надпись проявляются
одновременно. После 25-го кадра `fade=1`.

Почему не анимируем дальше: пользователь просил убрать вращающийся
индикатор и оставить только логотип и название. Появление — минимальная
анимация, которая не отвлекает и не требует лишних спрайтов.

### 5.5. Выключение

```text
if (!global.is_boot)
  return;
```

В `refresh_callback()` при `shutdown`/`reboot` сразу выходим. Спрайты
не создаются, фон остаётся чёрным. Поэтому при выключении нет ни
надписи, ни анимации.

---

## 6. Hook `plymouth` и initramfs

Plymouth должен попасть в initramfs. Для этого в `/etc/mkinitcpio.conf`:

```text
HOOKS=(base systemd plymouth autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)
```

Порядок важен:

- `plymouth` стоит **после** `systemd`, чтобы systemd-хук успел создать
  окружение;
- `autodetect` и остальные хуки идут дальше;
- `kms` в этом комплекте **не добавляется и не удаляется** автоматически.

После изменения:

```bash
sudo mkinitcpio -P
```

Проверка:

```bash
lsinitcpio /boot/initramfs-linux.img | grep -E 'plymouthd|arch-waves'
```

В initramfs должны быть `plymouthd` и файлы темы.

---

## 7. `splash` в командной строке

Plymouth запускается, если ядро получило параметр `splash`. Есть два
варианта:

### Стандартное меню GRUB

```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=0 systemd.show_status=no udev.log_level=0 splash"
```

Затем:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Статическое меню `40_custom`

`GRUB_CMDLINE_LINUX_DEFAULT` **не применяется** к ручному `menuentry`.
Параметр нужно прописать прямо в строке `linux`:

```text
linux /vmlinuz-linux root=UUID=... rw quiet loglevel=0 systemd.show_status=no udev.log_level=0 splash
```

В шаблоне [`../grub/40_custom.example`](../grub/40_custom.example) он уже
есть.

Без `splash` Plymouth не запустится, даже если тема установлена и
initramfs собран.

---

## 8. Почему нет спиннера

Старый вариант рисовал шесть синих точек, вращающихся по кругу, как
загрузка Windows. Владелец попросил убрать вращающийся круг и оставить
только логотип и название.

Плюсы:

- меньше спрайтов и вычислений;
- нет визуального шума;
- не нужно считать угол, хвост затухания и радиус;
- одинаковый вид на загрузке и выключении (на выключении — просто чёрный).

---

## 9. Чёрный промежуток и `kms`

Между меню GRUB и первым кадром Plymouth есть пауза: ядро загружается,
initramfs распаковывается, запускается Plymouth. Если initramfs большой,
пауза длиннее.

На текущей системе владельца:

- `kms` убран из `HOOKS`;
- `MODULES=(i915)`;
- initramfs уменьшился примерно со 131 МБ до 24 МБ;
- фон и в GRUB, и в Plymouth чёрный, поэтому пауза визуально не видна.

Почему `kms` может быть большим: hook `kms` тянет в initramfs модули
KMS и firmware, включая `nouveau`/NVIDIA. На Optimus-ноутбуке это
десятки мегабайт.

**Не удаляй `kms` вслепую.** Если драйвер видеокарты не загрузится
достаточно рано, можно получить чёрный экран. Сначала проверь
`MODULES` и убедись, что драйвер там есть. Подробные команды —
[`INSTALL.md`](INSTALL.md), раздел 5.

---

## 10. Установка и проверка

```bash
sudo bash plymouth/install-theme.sh
```

Скрипт:

1. ставит `plymouth`, если его нет;
2. копирует тему в `/usr/share/plymouth/themes/arch-waves`;
3. добавляет `plymouth` в HOOKS после `systemd`;
4. добавляет `splash` в `/etc/default/grub`;
   если есть статический `40_custom` без `splash`, выводит предупреждение;
5. выбирает тему;
6. делает `mkinitcpio -P`;
7. пересобирает `grub.cfg`.

Проверка:

```bash
plymouth-set-default-theme
grep -E '^HOOKS=' /etc/mkinitcpio.conf
grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub
lsinitcpio /boot/initramfs-linux.img | grep -E 'plymouthd|arch-waves'
```

Проверка без перезагрузки (на TTY, не в X11):

```bash
sudo plymouthd
sudo plymouth --show-splash
sleep 5
sudo plymouth --quit
```

Это покажет заставку поверх текущего TTY. Если что-то не так, смотри
[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

---

## 11. Почему тема называется arch-waves

Историческое имя осталось от старой темы с волнами. Внутри уже нет волн:
чёрный фон, логотип и надпись. Имя менять не стали, чтобы не ломать
`plymouth-set-default-theme`, пути и документацию. Это просто идентификатор.
