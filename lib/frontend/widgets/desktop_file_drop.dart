import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../core/config/desktop_density.dart';
import '../../core/design/komet_tokens.dart';

class DesktopFileDrop extends StatefulWidget {
  const DesktopFileDrop({
    super.key,
    required this.child,
    required this.onFiles,
    this.enabled = true,
  });

  final Widget child;
  final ValueChanged<List<String>> onFiles;
  final bool enabled;

  @override
  State<DesktopFileDrop> createState() => _DesktopFileDropState();
}

class _DesktopFileDropState extends State<DesktopFileDrop> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!DesktopDensity.enabled) return widget.child;
    final enabled = widget.enabled && (ModalRoute.isCurrentOf(context) ?? true);
    final tokens = KometTokens.of(context);
    return DropTarget(
      enable: enabled,
      onDragEntered: (_) => setState(() => _hovered = true),
      onDragExited: (_) => setState(() => _hovered = false),
      onDragDone: (details) {
        setState(() => _hovered = false);
        if (enabled) {
          widget.onFiles(details.files.map((file) => file.path).toList());
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_hovered && enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.overlay,
                    border: Border.all(color: tokens.focused, width: 2),
                    borderRadius: KometTokens.cardRadius,
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_upload_outlined, size: 40),
                        SizedBox(height: 12),
                        Text('Перетащите файлы сюда'),
                        Text('Перед отправкой откроется предпросмотр'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
