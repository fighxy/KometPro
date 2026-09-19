import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/app_visual_style.dart';
import 'package:komet/core/config/glass_intensity.dart';
import 'package:komet/frontend/widgets/liquid_glass.dart';

void main() {
  setUp(() {
    AppVisualStyle.current.value = VisualStyle.glossy;
    GlassIntensity.scale.value = GlassIntensity.def;
    GlassIntensity.systemAllowsBlur.value = true;
  });

  testWidgets('reduce motion keeps frosted surfaces enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: GlassSurface(
            frostTint: Colors.red,
            fallbackColor: Colors.blue,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(GlassSurface),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reduced transparency uses the opaque fallback', (tester) async {
    GlassIntensity.systemAllowsBlur.value = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GlassSurface(
          frostTint: Colors.red,
          fallbackColor: Colors.blue,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );

    final backdrop = find.descendant(
      of: find.byType(GlassSurface),
      matching: find.byType(BackdropFilter),
    );
    final fallbackFinder = find.descendant(
      of: find.byType(GlassSurface),
      matching: find.byType(ColoredBox),
    );
    expect(backdrop, findsNothing);
    final fallback = tester.widget<ColoredBox>(fallbackFinder);
    expect(fallback.color, Colors.blue);
  });
}
