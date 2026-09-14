import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CallToggleMuteIntent extends Intent {
  const CallToggleMuteIntent();
}

class CallToggleVideoIntent extends Intent {
  const CallToggleVideoIntent();
}

class CallToggleScreenIntent extends Intent {
  const CallToggleScreenIntent();
}

class CallToggleChatIntent extends Intent {
  const CallToggleChatIntent();
}

class CallToggleParticipantsIntent extends Intent {
  const CallToggleParticipantsIntent();
}

class CallMinimizeIntent extends Intent {
  const CallMinimizeIntent();
}

class CallDesktopShortcuts extends StatelessWidget {
  const CallDesktopShortcuts({
    super.key,
    required this.child,
    this.enabled = true,
    this.onToggleMute,
    this.onToggleVideo,
    this.onToggleScreen,
    this.onToggleChat,
    this.onToggleParticipants,
    this.onMinimize,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onToggleScreen;
  final VoidCallback? onToggleChat;
  final VoidCallback? onToggleParticipants;
  final VoidCallback? onMinimize;

  static bool get _meta => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
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
        SingleActivator(LogicalKeyboardKey.keyD, control: !_meta, meta: _meta):
            const CallToggleMuteIntent(),
        SingleActivator(LogicalKeyboardKey.keyE, control: !_meta, meta: _meta):
            const CallToggleVideoIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyS,
          control: !_meta,
          meta: _meta,
          shift: true,
        ): const CallToggleScreenIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyH,
          control: !_meta,
          meta: _meta,
          shift: true,
        ): const CallToggleChatIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyP,
          control: !_meta,
          meta: _meta,
          shift: true,
        ): const CallToggleParticipantsIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const CallMinimizeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          CallToggleMuteIntent: CallbackAction<CallToggleMuteIntent>(
            onInvoke: (_) {
              onToggleMute?.call();
              return null;
            },
          ),
          CallToggleVideoIntent: CallbackAction<CallToggleVideoIntent>(
            onInvoke: (_) {
              onToggleVideo?.call();
              return null;
            },
          ),
          CallToggleScreenIntent: CallbackAction<CallToggleScreenIntent>(
            onInvoke: (_) {
              onToggleScreen?.call();
              return null;
            },
          ),
          CallToggleChatIntent: CallbackAction<CallToggleChatIntent>(
            onInvoke: (_) {
              onToggleChat?.call();
              return null;
            },
          ),
          CallToggleParticipantsIntent:
              CallbackAction<CallToggleParticipantsIntent>(
                onInvoke: (_) {
                  onToggleParticipants?.call();
                  return null;
                },
              ),
          CallMinimizeIntent: CallbackAction<CallMinimizeIntent>(
            onInvoke: (_) {
              onMinimize?.call();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
