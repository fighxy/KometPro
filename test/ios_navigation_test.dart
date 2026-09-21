import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/app_visual_style.dart';
import 'package:komet/frontend/widgets/sliding_pill_nav.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('compact tabs retain labels for accessibility and full hit areas',
      (tester) async {
    final oldStyle = AppVisualStyle.current.value;
    addTearDown(() => AppVisualStyle.current.value = oldStyle);
    AppVisualStyle.current.value = VisualStyle.materialYou;
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    var selected = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: SlidingPillNav(
              items: const [
                PillNavItem(icon: Icons.chat, label: 'Chats'),
                PillNavItem(icon: Icons.settings, label: 'Settings'),
              ],
              position: 0,
              collapse: 1,
              geometry: PillNavGeometry.equal(154, 2),
              onTap: (index) => selected = index,
            ),
          ),
        ),
      ),
    ));
    expect(find.bySemanticsLabel('Chats'), findsOneWidget);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    final nav = find.byType(SlidingPillNav);
    final cells = find.descendant(of: nav, matching: find.byType(GestureDetector));
    for (final element in cells.evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)).height,
          greaterThanOrEqualTo(44));
    }
    await tester.tap(find.byIcon(Icons.settings));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}
