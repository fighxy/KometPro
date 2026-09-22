import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/app_native_glass.dart';
import 'package:komet/frontend/widgets/native_glass.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

void main() {
  test('nested overlay releases are balanced and idempotent', () {
    final first = NativeGlassOverlays.suspend();
    final second = NativeGlassOverlays.suspend();
    expect(NativeGlassOverlays.count.value, 2);
    first();
    first();
    expect(NativeGlassOverlays.count.value, 1);
    second();
    expect(NativeGlassOverlays.count.value, 0);
  });

  testWidgets('unsupported platforms retain fallback and foreground controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NativeGlassSurface(
            borderRadius: BorderRadius.circular(20),
            fallback: const ColoredBox(color: Colors.blue),
            child: TextButton(onPressed: () {}, child: const Text('Action')),
          ),
        ),
      ),
    );
    expect(AppNativeGlass.supported, isFalse);
    expect(find.byType(LiquidGlassContainer), findsNothing);
    expect(find.text('Action'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == Colors.blue),
      findsOneWidget,
    );
  });

  testWidgets(
    'draft focus and selection survive overlay and renderer changes',
    (tester) async {
      final controller = TextEditingController(text: 'Synthetic draft');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      addTearDown(() => AppNativeGlass.current.value = true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NativeGlassSurface(
              borderRadius: BorderRadius.circular(20),
              fallback: const ColoredBox(color: Colors.blue),
              child: TextField(controller: controller, focusNode: focus),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 9,
      );
      await tester.pump();
      final state = tester.state(find.byType(EditableText));
      final release = NativeGlassOverlays.suspend();
      AppNativeGlass.current.value = false;
      await tester.pump();
      release();
      AppNativeGlass.current.value = true;
      await tester.pump();
      expect(tester.state(find.byType(EditableText)), same(state));
      expect(controller.text, 'Synthetic draft');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 9),
      );
      expect(focus.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'overlay disposal releases suppression even without dismiss callback',
    (tester) async {
      final release = NativeGlassOverlays.suspend();
      await tester.pumpWidget(
        NativeGlassOverlay(release: release, child: const SizedBox()),
      );
      expect(NativeGlassOverlays.count.value, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(NativeGlassOverlays.count.value, 0);
      release();
      expect(NativeGlassOverlays.count.value, 0);
    },
  );
}
