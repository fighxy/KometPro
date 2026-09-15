import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/modules/chats.dart';
import '../../backend/modules/messages.dart' show ContactCache;
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

  static _AdaptiveShellState? _current;

  /// Opens [chat] in the desktop chat pane instead of a full-screen route.
  /// With [withInfo] the docked info pane is opened too, when the window is
  /// wide enough to hold it. Returns false when there is no desktop shell.
  static bool openInPane(DesktopChatSelection chat, {bool withInfo = false}) {
    final state = _current;
    if (state == null || !state.mounted || !DesktopDensity.enabled) {
      return false;
    }
    state._onChatSelected(chat);
    if (withInfo) state._openInfoIfDockable();
    return true;
  }

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
  ValueNotifier<int>? _chatsChanged;

  @override
  void initState() {
    super.initState();
    AdaptiveShell._current = this;
    WidgetsBinding.instance.addObserver(this);
    _loadListWidth();
    DesktopWindow.openChatId.addListener(_onJumpChat);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hadHinge = AppBreakpoints.hingeOf(MediaQuery.of(context)) != null;
      _chatsChanged = AppScope.read(context).chats.chatsChanged;
      _chatsChanged!.addListener(_onChatsChanged);
      _runStartupPrompts();
      _onJumpChat();
    });
  }

  @override
  void dispose() {
    if (identical(AdaptiveShell._current, this)) AdaptiveShell._current = null;
    _chatsChanged?.removeListener(_onChatsChanged);
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

  void _onChatsChanged() {
    final selected = _selected.value;
    if (selected == null) return;
    unawaited(_closeIfChatRemoved(selected.chatId));
  }

  Future<void> _closeIfChatRemoved(int chatId) async {
    final profile = await AppDatabase.loadActiveProfile();
    if (profile == null || !mounted) return;
    final rows = await AppScope.read(context).chats.getChat(profile.id, chatId);
    if (!mounted) return;
    if (rows.isEmpty && _selected.value?.chatId == chatId) {
      _closeChat();
    }
  }

  bool _inspectorFits() {
    final width = MediaQuery.sizeOf(context).width;
    final list = _listWidth.value.clamp(
      _minListWidth,
      KometLayout.listLimit(width, DesktopDensity.s, false),
    );
    return KometLayout.dockInspector(width, list, DesktopDensity.s);
  }

  void _openInfoIfDockable() {
    if (_infoOpen || !_inspectorFits()) return;
    setState(() => _infoOpen = true);
  }

  void _toggleInfo() {
    final chat = _selected.value;
    if (chat == null) return;
    if (!_inspectorFits()) {
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
              onChatRemoved: () {
                Navigator.of(dialogContext).pop();
                _closeChat();
              },
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
                              color: cs.outlineVariant.withValues(alpha: 0.6),
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
                                    child: _island(cs, pane),
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
                                width: DesktopDensity.infoPaneWidth +
                                    (_islandEnabled ? _islandGap : 0),
                                child: _island(
                                  cs,
                                  ChatInfoScreen(
                                    key: ValueKey('info-${selected.chatId}'),
                                    chatId: selected.chatId,
                                    name: selected.name,
                                    imageUrl: selected.imageUrl,
                                    chatType: selected.chatType,
                                    openedFromChat: true,
                                    onClose: _closeInfo,
                                    onChatRemoved: _closeChat,
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

  static const double _islandInset = 8;
  static const double _islandGap = _islandInset * 2;

  static bool get _islandEnabled => DesktopDensity.enabled;

  /// Wraps a desktop pane into a rounded card floating over the window
  /// background instead of a pane flush with the window edges.
  Widget _island(ColorScheme cs, Widget child) {
    if (!_islandEnabled) return child;
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: const EdgeInsets.all(_islandInset),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: ClipRRect(borderRadius: radius, child: child),
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

class _RecentChat {
  const _RecentChat({
    required this.id,
    required this.title,
    required this.avatarUrl,
    required this.type,
    required this.time,
  });

  final int id;
  final String title;
  final String avatarUrl;
  final String type;
  final int? time;
}

class _EmptyChatPane extends StatefulWidget {
  final ColorScheme colorScheme;

  const _EmptyChatPane({super.key, required this.colorScheme});

  @override
  State<_EmptyChatPane> createState() => _EmptyChatPaneState();
}

class _EmptyChatPaneState extends State<_EmptyChatPane> {
  ProfileData? _profile;
  List<_RecentChat> _recents = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final profile = await AppDatabase.loadActiveProfile();
      var recents = <_RecentChat>[];
      if (profile != null) {
        final chats = await AppScope.read(context).chats.getChats(profile.id);
        recents = _resolve(chats, profile.id).take(5).toList();
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _recents = recents;
      });
    } catch (_) {}
  }

  Iterable<_RecentChat> _resolve(List<CachedChat> chats, int selfId) sync* {
    for (final chat in chats) {
      if (chat.id == 0) continue;
      var title = (chat.title ?? '').trim();
      var avatar = (chat.iconUrl ?? '').trim();
      if (chat.type == 'DIALOG') {
        var peerId = 0;
        for (final entry in chat.participants.entries) {
          if (entry.key != selfId) {
            peerId = entry.key;
            break;
          }
        }
        if (peerId != 0) {
          title = (ContactCache.get(peerId) ?? title).trim();
          avatar = (ContactCache.getAvatar(peerId) ?? avatar).trim();
        }
      }
      if (title.isEmpty) continue;
      yield _RecentChat(
        id: chat.id,
        title: title,
        avatarUrl: avatar,
        type: chat.type,
        time: chat.lastMsgTime,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final name = _profile == null
        ? ''
        : [
            _profile!.firstName,
            _profile!.lastName ?? '',
          ].where((s) => s.trim().isNotEmpty).join(' ');
    return ColoredBox(
      color: cs.surfaceContainerLow,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.forum_rounded,
                      color: cs.onPrimaryContainer,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Выберите чат',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name.isEmpty
                        ? 'Откройте переписку слева или воспользуйтесь поиском'
                        : '$name, откройте переписку слева или воспользуйтесь поиском',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _EmptyPaneAction(
                        icon: Icons.search_rounded,
                        label: 'Поиск',
                        colorScheme: cs,
                        onTap: ChatListScreen.openSearch,
                      ),
                      const SizedBox(width: 10),
                      _EmptyPaneAction(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Новый чат',
                        colorScheme: cs,
                        onTap: () => context
                            .findAncestorStateOfType<_AdaptiveShellState>()
                            ?._onRailSelect(2),
                      ),
                    ],
                  ),
                  if (_recents.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Material(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Text(
                                'Недавние чаты',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            for (final chat in _recents)
                              _RecentRow(
                                chat: chat,
                                colorScheme: cs,
                                onTap: () {
                                  final shell = context
                                      .findAncestorStateOfType<
                                          _AdaptiveShellState>();
                                  shell?._onChatSelected(
                                    DesktopChatSelection(
                                      chatId: chat.id,
                                      name: chat.title,
                                      imageUrl: chat.avatarUrl,
                                      chatType: chat.type,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPaneAction extends StatelessWidget {
  const _EmptyPaneAction({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: cs.onSurface.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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

  final _RecentChat chat;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: cs.onSurface.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: cs.surfaceContainerHighest,
                backgroundImage: chat.avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(chat.avatarUrl)
                    : null,
                child: chat.avatarUrl.isEmpty
                    ? Text(
                        chat.title.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (chat.time != null) ...[
                const SizedBox(width: 10),
                Text(
                  formatChatListTime(chat.time),
                  style: TextStyle(color: cs.outline, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
