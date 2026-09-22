# Native Liquid Glass on iOS

The iOS 26+ Liquid Glass style uses `native_liquid_glass` 0.3.1 for selected navigation and control surfaces. The UI remains Flutter; the package does not convert Flutter children to UIKit controls.

## Included

- UIKit navigation bars for `ConnectionTitleBar` screens, retaining connection state and guarded back navigation.
- Native backgrounds for the chat header capsules, composer text field, channel actions, search bar, message selection bars, bottom navigation, media caption/control panels and call controls.
- Existing long presses, Lottie icons, text input, accessibility semantics and command callbacks remain Flutter-owned.
- Native backgrounds are explicitly opted into. Message bubbles, reactions, list rows, participant tiles and floating overlays are not converted.

Enable the Liquid Glass visual style in Settings → Customization → Appearance. “System Liquid Glass” switches native rendering on or off without changing the stored visual style. Native intensity is system-controlled; the existing intensity slider continues to affect Flutter-rendered surfaces only.

## Compatibility

- iOS 26+ only; all other targets and older iOS keep their previous Flutter rendering.
- Flutter >=3.41.2 / Dart >=3.11 are required by the dependency; CI uses Flutter 3.44.3.
- Compile with an iOS 26+ SDK. The minimum deployment target remains iOS 13.
- Reduced transparency, high contrast and reduced motion disable native rendering.
- Native theme follows the selected app theme; system mode clears the UIKit appearance override.
- Native surfaces are replaced by fallback backgrounds during route transitions, while covered by popup routes, during main tab transitions and while custom chat/message menus are visible. Text fields and other foreground children stay mounted.
- Theme reveal snapshots are skipped when native glass is enabled because Flutter snapshots do not capture UIKit surfaces.

## Verification on a physical device

1. Compare iOS 26+ native on/off with an older iOS and Android/desktop fallback. Check both light/dark app themes against the opposite device theme, then restore system theme.
2. Toggle Reduce Transparency, Reduce Motion and high contrast. Check VoiceOver labels and large text.
3. Rapidly switch tabs; open/close the create menu and account picker; switch accounts. Confirm long press on the profile tab still works.
4. Open and cancel interactive back gestures, push/pop screens, open nested dialogs and custom chat/message menus. Confirm native material restores and no control is obscured.
5. Type a multiline draft, select/copy text, open attachments and replies, rotate with keyboard open. Confirm draft, focus and selection persist after dismissing overlays.
6. Test search, message selection, channel mute Lottie animation and channel search.
7. Play video, drag its seek bar, open caption/actions, then receive and end a call. Check call controls over video and native/Flutter layering.
8. Profile on hardware: frame timing, scroll jank, memory and heat with native enabled/disabled. Native platform views are not presumed faster than shaders. Keep native off if the regression is material.

A successful CI build does not establish visual correctness or frame performance. Device QA is required before merging.
