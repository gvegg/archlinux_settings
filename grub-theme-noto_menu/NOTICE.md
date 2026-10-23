# Сторонние ассеты и лицензии

Проект использует смешанные лицензии. Код, скрипты и конфигурация темы
распространяются по MIT (`LICENSE`). Отдельные ассеты — по своим лицензиям,
указанным ниже.

## Фон

* Файлы: `backgrounds/waves-1600-original.jpg`, производный `theme/bg-waves.png`,
  а также `docs/preview.png` (содержит тот же фон).
* Автор: **Davmormar**.
* Источник: [Wikimedia Commons — File:Abstract-background-white-12.jpg](https://commons.wikimedia.org/wiki/File:Abstract-background-white-12.jpg).
* Лицензия: **Creative Commons Attribution-ShareAlike 4.0 International**
  (CC BY-SA 4.0), полный текст — `LICENSES/CC-BY-SA-4.0.txt`,
  также https://creativecommons.org/licenses/by-sa/4.0/.
* Изменения: центральный кроп 16:9, ресайз до 1600×900, затемнение на 25 %
  (яркость ×0.75). Исходник и результат распространяются на условиях CC BY-SA 4.0.

## Шрифт

* Файлы: `theme/NotoSans-Regular-24.pf2`, `theme/caption_0.png`,
  `theme/caption_1.png`, `theme/caption_2.png` (подписи отрендерены шрифтом
  Noto Sans), а также подписи в `docs/preview.png`.
* Шрифт: **Noto Sans**, Copyright 2018 The Noto Project Authors
  (https://github.com/notofonts/noto-fonts).
* Лицензия: **SIL Open Font License 1.1** (OFL 1.1), полный текст —
  `LICENSES/OFL-1.1.txt`, также https://openfontlicense.org/.
* `NotoSans-Regular-24.pf2` — битмап-шрифт, собранный из Noto Sans через
  `grub-mkfont`; распространяется на условиях OFL 1.1.

## GRUB

Скрипты рассчитаны на GRUB 2, который распространяется по GPLv3 отдельно и в
этот репозиторий не входит. `grub-install` не используется: меняются только
конфигурация и файлы темы.

## Что это значит на практике

При копировании, изменении и распространении темы:

* сохраняй `LICENSE`, `NOTICE.md` и тексты в `LICENSES/`;
* указывай автора фона Davmormar и лицензию CC BY-SA 4.0;
* производные фона (включая перекрашенный/обрезанный `bg-waves.png`)
  распространяй по CC BY-SA 4.0;
* шрифтовые файлы и производные от Noto Sans распространяй по OFL 1.1.
