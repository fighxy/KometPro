import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchChatsIntent extends Intent {
  const SearchChatsIntent();
}

class ClosePaneIntent extends Intent {
  const ClosePaneIntent();
}

class FindInChatIntent extends Intent {
  const FindInChatIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class NewChatIntent extends Intent {
  const NewChatIntent();
}

class QuitAppIntent extends Intent {
  const QuitAppIntent();
}

class AdjacentChatIntent extends Intent {
  const AdjacentChatIntent(this.delta);
  final int delta;
}

class DesktopShortcuts extends StatelessWidget {
  const DesktopShortcuts({
    super.key,
    required this.child,
    this.onSearchChats,
    this.onClosePane,
    this.onFindInChat,
    this.onOpenSettings,
    this.onNewChat,
    this.onQuit,
    this.onAdjacentChat,
  });

  final Widget child;
  final VoidCallback? onSearchChats;
  final VoidCallback? onClosePane;
  final VoidCallback? onFindInChat;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onNewChat;
  final VoidCallback? onQuit;
  final void Function(int delta)? onAdjacentChat;

  static bool get _meta => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        break;
      default:
        return child;
    }

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: !_meta, meta: _meta):
            const SearchChatsIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const ClosePaneIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: !_meta, meta: _meta):
            const FindInChatIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, control: !_meta, meta: _meta):
            const ClosePaneIntent(),
        SingleActivator(LogicalKeyboardKey.comma, control: !_meta, meta: _meta):
            const OpenSettingsIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: !_meta, meta: _meta):
            const NewChatIntent(),
        SingleActivator(LogicalKeyboardKey.keyQ, control: !_meta, meta: _meta):
            const QuitAppIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true):
            AdjacentChatIntent(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
            AdjacentChatIntent(1),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SearchChatsIntent: CallbackAction<SearchChatsIntent>(
            onInvoke: (_) {
              onSearchChats?.call();
              return null;
            },
          ),
          ClosePaneIntent: CallbackAction<ClosePaneIntent>(
            onInvoke: (_) {
              onClosePane?.call();
              return null;
            },
          ),
          FindInChatIntent: CallbackAction<FindInChatIntent>(
            onInvoke: (_) {
              onFindInChat?.call();
              return null;
            },
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) {
              onOpenSettings?.call();
              return null;
            },
          ),
          NewChatIntent: CallbackAction<NewChatIntent>(
            onInvoke: (_) {
              onNewChat?.call();
              return null;
            },
          ),
          QuitAppIntent: CallbackAction<QuitAppIntent>(
            onInvoke: (_) {
              onQuit?.call();
              return null;
            },
          ),
          AdjacentChatIntent: CallbackAction<AdjacentChatIntent>(
            onInvoke: (intent) {
              onAdjacentChat?.call(intent.delta);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
