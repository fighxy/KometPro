import 'package:flutter/material.dart';

class ChatPaneWidth extends InheritedWidget {
  const ChatPaneWidth({super.key, required this.width, required super.child});

  final double width;

  static double of(BuildContext context) {
    final pane = context
        .dependOnInheritedWidgetOfExactType<ChatPaneWidth>()
        ?.width;
    if (pane != null && pane > 0) return pane;
    return MediaQuery.sizeOf(context).width;
  }

  @override
  bool updateShouldNotify(ChatPaneWidth oldWidget) => oldWidget.width != width;
}
