import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/chat_nav.dart';

void main() {
  testWidgets('embedded close leaves the shell route in place', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return PopScope(
              canPop: false,
              child: TextButton(
                onPressed: () => closeChatSurface(
                  context,
                  embedded: true,
                  onClose: () => closed = true,
                ),
                child: const Text('delete-embedded'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('delete-embedded'));
    await tester.pump();

    expect(closed, isTrue);
    expect(find.text('delete-embedded'), findsOneWidget);
  });

  testWidgets('raw pop of the shell blanks the navigator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('pop-shell'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('pop-shell'));
    await tester.pumpAndSettle();

    expect(find.text('pop-shell'), findsNothing);
  });

  testWidgets('non-embedded close pops only the chat route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (chatContext) {
                      return TextButton(
                        onPressed: () => closeChatSurface(
                          chatContext,
                          embedded: false,
                        ),
                        child: const Text('delete-chat'),
                      );
                    },
                  ),
                );
              },
              child: const Text('open-chat'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open-chat'));
    await tester.pumpAndSettle();
    expect(find.text('delete-chat'), findsOneWidget);

    await tester.tap(find.text('delete-chat'));
    await tester.pumpAndSettle();

    expect(find.text('delete-chat'), findsNothing);
    expect(find.text('open-chat'), findsOneWidget);
  });

  testWidgets('popToRootOrClose uses onRemoved instead of popping the shell', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return PopScope(
              canPop: false,
              child: TextButton(
                onPressed: () => popToRootOrClose(
                  context,
                  onRemoved: () => removed = true,
                ),
                child: const Text('delete-info'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('delete-info'));
    await tester.pump();

    expect(removed, isTrue);
    expect(find.text('delete-info'), findsOneWidget);
  });

  testWidgets('popToRootOrClose without callbacks stays on the root route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => popToRootOrClose(context),
              child: const Text('already-root'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('already-root'));
    await tester.pumpAndSettle();

    expect(find.text('already-root'), findsOneWidget);
  });
}
