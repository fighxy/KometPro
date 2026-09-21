import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/contacts/contact_sheet_common.dart';

void main() {
  testWidgets('card still dismisses through its outside barrier', (tester) async {
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      }),
    ));
    final result = showBlurredCard<void>(
      host,
      (_) => const Center(
        child: SizedBox(
          width: 200,
          height: 100,
          child: Material(child: Text('Synthetic card')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Synthetic card'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic card'), findsNothing);
    await result;
    expect(tester.takeException(), isNull);
  });
}
