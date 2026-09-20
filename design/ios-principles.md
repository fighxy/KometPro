# Komet: iOS 26–27 Liquid Glass

Мобильный сценарий — быстро листать чаты, открывать переписку и писать одной рукой. Desktop-first раскладка AdaptiveShell на компактной ширине не используется: контент идёт полноэкранно, хром парит над ним.

## Слои

Два слоя, как в Human Interface Guidelines.

- Content — список чатов, пузыри, медиа, настройки. Непрозрачный. Стандартные материалы (`surface` / `surfaceContainer`). Liquid Glass на плитках и пузырях не ставить.
- Chrome — плавающий tab bar, шапка, composer, sheets, меню, FAB. Только здесь glass.

Стекать glass на glass нельзя. Sheet уже glass — кнопки внутри не оборачивать вторым `LiquidGlassSurface`.

## Материал

Regular — подписи и иконки (tab bar, alerts, группы настроек).
Clear — только поверх фото и видео.

iOS 27: пользовательский слайдер интенсивности (`GlassIntensity`) — влево прозрачнее, вправо плотнее и контрастнее. Reduce Transparency и high contrast снимают blur и оставляют сплошную поверхность.

Читаемость важнее линзы: адаптивный tint, тёмная кромка, сдержанная дисперсия. На iOS тема по умолчанию — Liquid Glass, пока пользователь не выбрал другую.

## Геометрия

Токены в `IosChrome`. Tab bar — плавающая капсула с боковым inset и отступом от home indicator. При скролле вниз сжимается до иконок без подписи, при скролле вверх или к началу списка раскрывается. Контент edge-to-edge, снизу запас `IosChrome.contentClearance`.

Sheets: радиус `KometTokens.mobileSheet` (28). Полулист слегка inset от краёв. Крупный заголовок списка — system/SF, semibold.

## Движение

Жесты системы не перехватывать. Reduced motion отключает сжатие и блик, но не убирает материал. Проверять Dynamic Island, home indicator и увеличенный текст.

## Не трогать

Трёхпанельный desktop, rail, inspector, Windows mica. iOS-правки не должны менять ветки `DesktopDensity.enabled`.
