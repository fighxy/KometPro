import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/keyboard_safe_form.dart';

void main() {
  testWidgets('form scrolls above keyboard and consumes its inset once',
      (tester) async {
    double? childInset;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          viewInsets: EdgeInsets.only(bottom: 280),
          padding: EdgeInsets.only(top: 24),
          textScaler: TextScaler.linear(2),
        ),
        child: Material(
          child: KeyboardSafeForm(
            child: Builder(builder: (context) {
              childInset = MediaQuery.viewInsetsOf(context).bottom;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 700),
                  TextButton(onPressed: () {}, child: const Text('Save')),
                ],
              );
            }),
          ),
        ),
      ),
    ));
    expect(childInset, 0);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('Save')).dy, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short dialog stays centered in available viewport',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 200)),
        child: KeyboardSafeForm(
          fillViewport: true,
          child: Center(child: SizedBox(key: ValueKey('card'), height: 100)),
        ),
      ),
    ));
    expect(tester.getCenter(find.byKey(const ValueKey('card'))).dy, 200);
    expect(tester.takeException(), isNull);
  });
}
