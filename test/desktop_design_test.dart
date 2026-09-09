import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komet/core/config/app_composer_style.dart';
import 'package:komet/core/config/app_visual_style.dart';
import 'package:komet/core/config/desktop_density.dart';
import 'package:komet/core/config/desktop_density_mode.dart';
import 'package:komet/core/config/desktop_ui_scale.dart';
import 'package:komet/core/design/komet_layout.dart';
import 'package:komet/frontend/widgets/desktop_command_palette.dart';
import 'package:komet/frontend/widgets/desktop_nav_rail.dart';
import 'package:komet/frontend/widgets/glossy_pill.dart';
import 'package:komet/frontend/widgets/settings_card.dart';
import 'package:komet/frontend/screens/chats/chat/view/chat_list_tile.dart';
import 'dart:ui' show PointerDeviceKind;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppVisualStyle.current.value = VisualStyle.materialYou;
    AppDesktopDensity.current.value = DesktopDensityMode.comfortable;
    DesktopUiScale.value.value = 1;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppVisualStyle.current.value = VisualStyle.materialYou;
    AppDesktopDensity.current.value = DesktopDensityMode.comfortable;
    DesktopUiScale.value.value = 1;
  });

  test('composer follows the theme without overriding saved choices', () async {
    expect(await AppComposerStyle.load(), ComposerStyle.auto);
    expect(ComposerChrome.isGlossy(AppComposerStyle.current.value), isFalse);
    AppVisualStyle.current.value = VisualStyle.glossy;
    expect(ComposerChrome.isGlossy(AppComposerStyle.current.value), isTrue);
    await AppComposerStyle.save(ComposerStyle.materialYou);
    expect(await AppComposerStyle.load(), ComposerStyle.materialYou);
    SharedPreferences.setMockInitialValues({
      AppComposerStyle.prefKey: 'invalid',
    });
    expect(await AppComposerStyle.load(), ComposerStyle.auto);
  });

  test('density persists independently of interface scale', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await AppDesktopDensity.save(DesktopDensityMode.compact);
    expect(await AppDesktopDensity.load(), DesktopDensityMode.compact);
    expect(DesktopDensity.rowInnerHeight, 40);
    DesktopUiScale.value.value = 1.5;
    expect(DesktopDensity.rowInnerHeight, 60);
  });

  test(
    'inspector reserves rail and a readable chat at every desktop scale',
    () {
      for (final width in [1280.0, 1440.0, 1920.0, 2560.0]) {
        for (final scale in [0.75, 1.0, 1.25, 1.5]) {
          for (final list in [280.0, 360.0, 560.0]) {
            if (KometLayout.dockInspector(width, list, scale)) {
              expect(
                width - 60 * scale - list - 10 - 320 * scale,
                greaterThanOrEqualTo(360 * scale),
              );
            }
          }
        }
      }
      expect(KometLayout.dockInspector(1279, 280, 1), isFalse);
      expect(KometLayout.dockInspector(1280, 560, 1.5), isFalse);
    },
  );

  testWidgets('settings surfaces react to visual style', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsCard(children: [Text('Synthetic setting')]),
        ),
      ),
    );
    expect(find.byType(GlossyPill), findsNothing);
    AppVisualStyle.current.value = VisualStyle.glossy;
    await tester.pump();
    expect(find.byType(GlossyPill), findsOneWidget);
    AppVisualStyle.current.value = VisualStyle.materialYou;
    await tester.pump();
    expect(find.byType(GlossyPill), findsNothing);
  });

  testWidgets('hover actions wait and archive without opening the chat', (
    tester,
  ) async {
    var archived = false;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              height: 58,
              child: DesktopChatChrome(
                pinned: false,
                active: false,
                selected: false,
                enableHover: true,
                onArchive: () => archived = true,
                child: InkWell(
                  onTap: () => opened = true,
                  child: const SizedBox.expand(child: Text('Synthetic chat')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(600, 400));
    await mouse.moveTo(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 249));
    expect(find.byTooltip('В архив'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byTooltip('В архив'), findsOneWidget);
    await tester.tap(find.byTooltip('В архив'));
    expect(archived, isTrue);
    expect(opened, isFalse);
    await mouse.removePointer();
  });

  testWidgets('disabled settings cannot toggle', (tester) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsCard(
            children: [
              SettingsToggleTile(
                icon: Icons.settings,
                label: 'Disabled setting',
                value: false,
                enabled: false,
                onChanged: (_) => changed = true,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(changed, isFalse);
  });

  testWidgets('palette filters, executes with Enter and cancels with Escape', (
    tester,
  ) async {
    var invoked = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDesktopCommandPalette(
                context,
                commands: [
                  DesktopCommand(
                    'First action',
                    Icons.search,
                    () => invoked = 1,
                  ),
                  DesktopCommand(
                    'Second action',
                    Icons.settings,
                    () => invoked = 2,
                  ),
                ],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump();
    expect(find.text('First action'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(invoked, 2);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(invoked, 2);
  });

  for (final width in [1280.0, 1440.0, 1920.0, 2560.0]) {
    testWidgets('desktop surfaces fit width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: Row(
                children: [
                  DesktopNavRail(index: 0, onSelect: (_) {}),
                  const Expanded(
                    child: SettingsCard(
                      children: [
                        SettingsNavTile(
                          icon: Icons.settings,
                          label: 'Synthetic setting',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
