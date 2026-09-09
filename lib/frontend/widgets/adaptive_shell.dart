import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/modules/chats.dart';
import '../../core/config/app_breakpoints.dart';
import '../../core/design/komet_layout.dart';
import '../../core/design/komet_tokens.dart';
import 'desktop_command_palette.dart';
import '../../core/config/build_profile.dart';
import '../../core/config/debug_test.dart';
import '../../core/config/desktop_density.dart';
import '../../core/config/desktop_density_mode.dart';
import '../../core/config/desktop_ui_scale.dart';
import '../../core/desktop/desktop_tray.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/format.dart';
import '../../core/utils/update_checker.dart';
import '../screens/chats/chat_list_screen.dart';
import '../screens/chats/chat_screen.dart';
import '../screens/chats/chat_info_screen.dart';
import '../screens/profile/desktop_settings_page.dart';
import '../screens/profile/settings_tab.dart';
import 'app_scope.dart';
import 'auth_limits_sheet.dart';
import 'desktop_nav_rail.dart';
import 'desktop_shortcuts.dart';
import 'max_link_nav.dart';
import 'swipe_to_pop.dart';
import 'update_dialog.dart';

class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class DesktopChatSelection {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;
  final String? initialMessageId;
  final int? initialMessageTime;

  const DesktopChatSelection({
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    this.initialMessageId,
    this.initialMessageTime,
  });
}

class _AdaptiveShellState extends State<AdaptiveShell>
    with WidgetsBindingObserver {
  static const double _defaultListWidth = KometLayout.list;
  static const double _minListWidth = 280;
  static const double _maxListWidth = 560;
  static const double _dividerHitWidth = 10;
  static const double _dividerLineWidth = 1;
  static const String _prefsKey = 'desktop_list_width';

  final ValueNotifier<double> _listWidth = ValueNotifier(_defaultListWidth);
  final ValueNotifier<DesktopChatSelection?> _selected = ValueNotifier(null);
  int _railIndex = 0;
  bool _infoOpen = false;
  bool _hadHinge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadListWidth();
    DesktopWindow.openChatId.addListener(_onJumpChat);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hadHinge = AppBreakpoints.hingeOf(MediaQuery.of(context)) != null;
      _runStartupPrompts();
      _onJumpChat();
    });
  }

  @override
  void dispose() {
    DesktopWindow.openChatId.removeListener(_onJumpChat);
    WidgetsBinding.instance.removeObserver(this);
    _listWidth.dispose();
    _selected.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hinge = AppBreakpoints.hingeOf(MediaQuery.of(context));
      final hasHinge = hinge != null;
      if (_hadHinge && !hasHinge) {
        unawaited(_loadListWidth());
      }
      _hadHinge = hasHinge;
    });
  }

  Future<void> _runStartupPrompts() async {
    await showPendingAuthLimits(context);
    if (!mounted) return;
    await _maybeCheckUpdate();
  }

  Future<void> _maybeCheckUpdate() async {
    if (!BuildProfile.selfUpdate) return;
    if (DebugTest.enabled) return;
    final update = await UpdateChecker.check();
    if (update == null || !mounted) return;
    await showUpdateDialog(context, update);
  }

  Future<void> _loadListWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKey);
    if (saved == null || !mounted) return;
    _listWidth.value = saved.clamp(_minListWidth, _maxListWidth);
  }

  Future<void> _persistListWidth() async {
    if (_hadHinge) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, _listWidth.value);
  }

  void _onJumpChat() {
    final id = DesktopWindow.openChatId.value;
    if (id == null || id == 0 || !mounted) return;
    DesktopWindow.openChatId.value = null;
    unawaited(openChatById(context, id));
  }

  void _onChatSelected(DesktopChatSelection chat) {
    if (chat.imageUrl.isNotEmpty) {
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(
            chat.imageUrl,
            maxWidth: 144,
            maxHeight: 144,
          ),
          context,
        ),
      );
    }
    if (_selected.value?.chatId != chat.chatId) _infoOpen = false;
    _selected.value = chat;
  }

  void _closeChat() {
    _infoOpen = false;
    _selected.value = null;
  }

  void _toggleInfo() {
    final chat = _selected.value;
    if (chat == null) return;
    final width = MediaQuery.sizeOf(context).width;
    final list = _listWidth.value.clamp(
      _minListWidth,
      KometLayout.listLimit(width, DesktopDensity.s, false),
    );
    if (!KometLayout.dockInspector(width, list, DesktopDensity.s)) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: DesktopDensity.infoPaneWidth,
            child: ChatInfoScreen(
              chatId: chat.chatId,
              name: chat.name,
              imageUrl: chat.imageUrl,
              chatType: chat.chatType,
              openedFromChat: true,
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _infoOpen = !_infoOpen);
  }

  void _openCommandPalette() {
    showDesktopCommandPalette(
      context,
      commands: [
        DesktopCommand(
          'Найти чат',
          Icons.search,
          ChatListScreen.openSearch,
          shortcut: 'Ctrl+Shift+F',
        ),
        DesktopCommand(
          'Новый чат',
          Icons.edit_outlined,
          () => _onRailSelect(2),
          shortcut: 'Ctrl+N',
        ),
        DesktopCommand(
          'Настройки',
          Icons.settings_outlined,
          _openSettings,
          shortcut: 'Ctrl+,',
        ),
        DesktopCommand('Звонки', Icons.call_outlined, () => _onRailSelect(1)),
        if (_selected.value != null) ...[
          DesktopCommand('Поиск в переписке', Icons.search, () {
            ChatScreen.openSearchInVisibleChat();
          }, shortcut: 'Ctrl+F'),
          DesktopCommand('Информация о чате', Icons.info_outline, _toggleInfo),
          DesktopCommand(
            'Закрыть чат',
            Icons.close,
            _closeChat,
            shortcut: 'Esc',
          ),
        ],
      ],
    );
  }

  void _closeInfo() {
    if (!_infoOpen) return;
    setState(() => _infoOpen = false);
  }

  void _onRailSelect(int index) {
    setState(() => _railIndex = index);
    ChatListScreen.selectTab(index);
  }

  Future<void> _openSettings() async {
    setState(() => _railIndex = 3);
    if (DesktopDensity.enabled) {
      await DesktopSettingsPage.open(context);
    } else {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsTab()));
    }
    if (mounted) setState(() => _railIndex = 0);
  }

  void _onDrag(double dx, double totalWidth) {
    final maxAllowedByPane = KometLayout.listLimit(
      totalWidth,
      DesktopDensity.s,
      false,
    );
    final upperBound = maxAllowedByPane < _maxListWidth
        ? maxAllowedByPane
        : _maxListWidth;
    final next = (_listWidth.value + dx).clamp(_minListWidth, upperBound);
    if (next == _listWidth.value) return;
    _listWidth.value = next;
  }

  @override
  Widget build(BuildContext context) {
    return DesktopShortcuts(
      onClosePane: () {
        if (_infoOpen) {
          _closeInfo();
        } else {
          if (ChatScreen.consumeEscapeInVisibleChat()) return;
          _closeChat();
        }
      },
      onCommandPalette: _openCommandPalette,
      onSearchChats: ChatListScreen.openSearch,
      onFindInChat: () {
        if (_selected.value == null || !ChatScreen.openSearchInVisibleChat()) {
          ChatListScreen.openSearch();
        }
      },
      onOpenSettings: _openSettings,
      onNewChat: () => _onRailSelect(2),
      onQuit: () {
        if (DesktopTray.isSupported) {
          unawaited(DesktopTray.instance.quit());
        }
      },
      onAdjacentChat: (delta) {
        final next = ChatListScreen.adjacentChat(
          _selected.value?.chatId,
          delta,
        );
        if (next != null) _onChatSelected(next);
      },
      onCopyMessage: ChatScreen.copyVisibleSelection,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          DesktopUiScale.value,
          AppDesktopDensity.current,
          _listWidth,
          DesktopWindow.micaEnabled,
        ]),
        builder: (context, _) {
          return ValueListenableBuilder<DesktopChatSelection?>(
            valueListenable: _selected,
            builder: (context, selected, _) {
              return PopScope(
                canPop: selected == null,
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) return;
                  if (_selected.value != null) _closeChat();
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final hinge = AppBreakpoints.hingeOf(
                      MediaQuery.of(context),
                    );
                    if (!AppBreakpoints.useSplitView(
                      constraints.maxWidth,
                      hinge: hinge,
                    )) {
                      return _withRail(const ChatListScreen());
                    }
                    final totalWidth = constraints.maxWidth;
                    final hingeWidth = hinge == null
                        ? null
                        : AppBreakpoints.hingeListWidth(hinge, totalWidth);
                    final cs = Theme.of(context).colorScheme;
                    final highContrast = MediaQuery.highContrastOf(context);
                    final mica = DesktopWindow.micaEnabled.value;
                    return _withRail(
                      Scaffold(
                        backgroundColor: mica
                            ? cs.surface.withValues(
                                alpha: highContrast ? 0.92 : 0.72,
                              )
                            : cs.surface,
                        body: Row(
                          children: [
                            ValueListenableBuilder<double>(
                              valueListenable: _listWidth,
                              builder: (context, width, _) {
                                final hingeLocked = hingeWidth;
                                final effectiveListWidth =
                                    (hingeLocked ?? width).clamp(
                                      _minListWidth,
                                      KometLayout.listLimit(
                                        totalWidth,
                                        DesktopDensity.s,
                                        false,
                                      ),
                                    );
                                return SizedBox(
                                  width: effectiveListWidth,
                                  child:
                                      ValueListenableBuilder<
                                        DesktopChatSelection?
                                      >(
                                        valueListenable: _selected,
                                        builder: (context, selected, _) {
                                          return ChatListScreen(
                                            onChatSelected: _onChatSelected,
                                            activeChatId: selected?.chatId,
                                          );
                                        },
                                      ),
                                );
                              },
                            ),
                            _ResizeDivider(
                              hitWidth: _dividerHitWidth,
                              lineWidth: _dividerLineWidth,
                              color: cs.outlineVariant.withValues(alpha: 0.35),
                              onDrag: (dx) => _onDrag(dx, totalWidth),
                              onDragEnd: _persistListWidth,
                            ),
                            Expanded(
                              child: ValueListenableBuilder<DesktopChatSelection?>(
                                valueListenable: _selected,
                                builder: (context, selected, _) {
                                  final pane = AnimatedSwitcher(
                                    duration: KometTokens.motion(context, 160),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeOut,
                                    layoutBuilder: (current, previous) {
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ...previous,
                                          if (current != null) current,
                                        ],
                                      );
                                    },
                                    child: selected == null
                                        ? _EmptyChatPane(
                                            key: const ValueKey('empty'),
                                            colorScheme: cs,
                                          )
                                        : ChatScreen(
                                            key: ValueKey(
                                              '${selected.chatId}:${selected.initialMessageId ?? ''}',
                                            ),
                                            chatId: selected.chatId,
                                            name: selected.name,
                                            imageUrl: selected.imageUrl,
                                            chatType: selected.chatType,
                                            initialMessageId:
                                                selected.initialMessageId,
                                            initialMessageTime:
                                                selected.initialMessageTime,
                                            embedded: true,
                                            onClose: _closeChat,
                                            onOpenEmbeddedInfo:
                                                DesktopDensity.enabled
                                                ? _toggleInfo
                                                : null,
                                          ),
                                  );
                                  final iosPane =
                                      defaultTargetPlatform ==
                                      TargetPlatform.iOS;
                                  return SwipeToPop(
                                    enabled: selected != null && iosPane,
                                    onPop: _closeChat,
                                    child: pane,
                                  );
                                },
                              ),
                            ),
                            if (DesktopDensity.enabled &&
                                _infoOpen &&
                                selected != null &&
                                KometLayout.dockInspector(
                                  totalWidth,
                                  _listWidth.value.clamp(
                                    _minListWidth,
                                    KometLayout.listLimit(
                                      totalWidth,
                                      DesktopDensity.s,
                                      false,
                                    ),
                                  ),
                                  DesktopDensity.s,
                                ))
                              SizedBox(
                                width: DesktopDensity.infoPaneWidth,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: cs.outlineVariant.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: ChatInfoScreen(
                                    key: ValueKey('info-${selected.chatId}'),
                                    chatId: selected.chatId,
                                    name: selected.name,
                                    imageUrl: selected.imageUrl,
                                    chatType: selected.chatType,
                                    openedFromChat: true,
                                    onClose: _closeInfo,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _withRail(Widget child) {
    if (!DesktopDensity.enabled) return child;
    return Row(
      children: [
        DesktopNavRail(
          index: _railIndex,
          onSelect: _onRailSelect,
          onSettings: _openSettings,
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ResizeDivider extends StatefulWidget {
  final double hitWidth;
  final double lineWidth;
  final Color color;
  final ValueChanged<double> onDrag;
  final Future<void> Function() onDragEnd;

  const _ResizeDivider({
    required this.hitWidth,
    required this.lineWidth,
    required this.color,
    required this.onDrag,
    required this.onDragEnd,
  });

  @override
  State<_ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<_ResizeDivider> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final highlight = _dragging || _hovering;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) async {
          setState(() => _dragging = false);
          await widget.onDragEnd();
        },
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        child: SizedBox(
          width: widget.hitWidth,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: widget.lineWidth,
              color: highlight
                  ? cs.primary.withValues(alpha: 0.6)
                  : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChatPane extends StatefulWidget {
  final ColorScheme colorScheme;

  const _EmptyChatPane({super.key, required this.colorScheme});

  @override
  State<_EmptyChatPane> createState() => _EmptyChatPaneState();
}

class _EmptyChatPaneState extends State<_EmptyChatPane> {
  ProfileData? _profile;
  List<CachedChat> _recents = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final profile = await AppDatabase.loadActiveProfile();
      var recents = <CachedChat>[];
      if (profile != null) {
        recents = await AppScope.read(context).chats.getChats(profile.id);
        recents = recents.take(6).toList();
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _recents = recents;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final name = _profile == null
        ? 'Komet'
        : [
            _profile!.firstName,
            _profile!.lastName ?? '',
          ].where((s) => s.trim().isNotEmpty).join(' ');
    return ColoredBox(
      color: cs.surfaceContainerLow,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.surfaceContainerHighest,
                  backgroundImage: (_profile?.baseUrl ?? '').isNotEmpty
                      ? CachedNetworkImageProvider(_profile!.baseUrl!)
                      : null,
                  child: (_profile?.baseUrl ?? '').isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'K',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name.isEmpty ? 'Komet' : name,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ctrl+K поиск · Ctrl+N контакты · Ctrl+, настройки',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                if (_recents.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Недавние',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final chat in _recents)
                    _RecentRow(
                      chat: chat,
                      colorScheme: cs,
                      onTap: () {
                        final shell = context
                            .findAncestorStateOfType<_AdaptiveShellState>();
                        shell?._onChatSelected(
                          DesktopChatSelection(
                            chatId: chat.id,
                            name: chat.title ?? '',
                            imageUrl: chat.iconUrl ?? '',
                            chatType: chat.type,
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.chat,
    required this.colorScheme,
    required this.onTap,
  });

  final CachedChat chat;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final title = chat.title ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cs.surfaceContainerHighest,
                backgroundImage: (chat.iconUrl ?? '').isNotEmpty
                    ? CachedNetworkImageProvider(chat.iconUrl!)
                    : null,
                child: (chat.iconUrl ?? '').isEmpty
                    ? Text(
                        title.isNotEmpty ? title[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (chat.lastMsgTime != null)
                Text(
                  formatChatListTime(chat.lastMsgTime),
                  style: TextStyle(color: cs.outline, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
