import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/swipe_route.dart';

void main() {
  testWidgets('iOS helper preserves route settings and typed result',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      }),
    ));
    late BuildContext destination;
    final result = pushSwipeable<String>(
      host,
      (context) {
        destination = context;
        return const Scaffold(body: Text('Destination'));
      },
      settings: const RouteSettings(name: '/synthetic-destination'),
    );
    await tester.pumpAndSettle();
    final route = ModalRoute.of(destination)!;
    expect(route, isA<CupertinoPageRoute<String>>());
    expect(route.settings.name, '/synthetic-destination');
    Navigator.of(destination).pop('done');
    await tester.pumpAndSettle();
    expect(await result, 'done');
    expect(tester.takeException(), isNull);
  });
}
