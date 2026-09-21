import 'package:flutter/material.dart';

class KeyboardSafeForm extends StatelessWidget {
  final Widget child;
  final bool fillViewport;

  const KeyboardSafeForm({
    super.key,
    required this.child,
    this.fillViewport = false,
  });

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              primary: false,
              hitTestBehavior: HitTestBehavior.deferToChild,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: fillViewport && constraints.hasBoundedHeight
                      ? constraints.maxHeight
                      : 0,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
