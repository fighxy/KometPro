import 'package:flutter/widgets.dart';

void closeChatSurface(
  BuildContext context, {
  required bool embedded,
  VoidCallback? onClose,
}) {
  if (embedded) {
    onClose?.call();
    return;
  }
  final navigator = Navigator.of(context);
  if (navigator.canPop()) navigator.pop();
}

void popToRootOrClose(
  BuildContext context, {
  VoidCallback? onRemoved,
  VoidCallback? onClose,
}) {
  if (onRemoved != null) {
    onRemoved();
    return;
  }
  if (onClose != null) {
    onClose();
    return;
  }
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  }
}
