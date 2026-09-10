import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/build_profile.dart';
import '../../../core/config/komet_settings.dart';
import '../../../core/cache/self_presence.dart';
import '../../../core/config/desktop_density.dart';
import '../../../core/config/desktop_density_mode.dart';
import '../../../core/design/komet_tokens.dart';
import '../../../core/config/desktop_ui_scale.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/update_checker.dart';
import '../../../l10n/app_localizations.dart';
import 'package:komet/frontend/komet_app.dart' show KometApp;
import '../../widgets/app_scope.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/update_dialog.dart';
import '../auth/login_screen.dart';
import '../auth/proxy_settings_sheet.dart';
import 'app_icon_screen.dart';
import 'appearance_screen.dart';
import 'chat_background_screen.dart';
import 'cloud_storage_screen.dart';
import 'debug_menu_screen.dart';
import 'devices_screen.dart';
import 'edit_profile_screen.dart';
import 'font_settings_screen.dart';
import 'komet_settings_screen.dart';
import 'message_actions_screen.dart';
import 'notifications_screen.dart';
import 'profile_qr_sheet.dart';
import 'security_screen.dart';
import 'spoof_screen.dart';
import 'theme_settings_screen.dart';

enum DesktopSettingsSection {
  account,
  appearance,
  notifications,
  privacy,
  spoof,
  devices,
  network,
  storage,
  advanced,
  about,
}

class DesktopSettingsPage extends StatefulWidget {
  const DesktopSettingsPage({
    super.key,
    this.initial = DesktopSettingsSection.account,
  });

  final DesktopSettingsSection initial;

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const DesktopSettingsPage(),
        ),
      ),
    );
  }

  @override
  State<DesktopSettingsPage> createState() => _DesktopSettingsPageState();
}

class _DesktopSettingsPageState extends State<DesktopSettingsPage> {
  late DesktopSettingsSection _section;
  Widget? _subpage;
  String? _subpageTitle;
  ProfileData? _profile;
  String? _version;
  bool _checkingUpdate = false;
  StreamSubscription? _profileSub;

  @override
  void initState() {
    super.initState();
    _section = widget.initial;
    unawaited(_load());
    final app = KometApp.stateOf(context);
    _profileSub = app?.profileUpdateStream.listen((_) => _load());
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await AppDatabase.loadActiveProfile();
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _version = '${info.version} (${info.buildNumber})';
    });
  }

  void _openSub(String title, Widget page) {
    Haptics.tap();
    setState(() {
      _subpageTitle = title;
      _subpage = page;
    });
  }

  void _closeSub() {
    setState(() {
      _subpage = null;
      _subpageTitle = null;
    });
  }

  Future<void> _logout() async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Сессия на этом устройстве будет завершена.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = KometApp.navigatorKey.currentState;
    try {
      await AppScope.read(context).account.logout();
    } catch (e) {
      if (mounted) showCustomNotification(context, 'Не удалось выйти: $e');
      return;
    }
    if (nav != null) {
      await nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final update = await UpdateChecker.check();
      if (!mounted) return;
      if (update == null) {
        showCustomNotification(context, 'Обновлений нет');
      } else {
        await showUpdateDialog(context, update);
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showOwnHeader = _subpage == null &&
        (_section == DesktopSettingsSection.account ||
            _section == DesktopSettingsSection.appearance ||
            _section == DesktopSettingsSection.privacy ||
            _section == DesktopSettingsSection.spoof ||
            _section == DesktopSettingsSection.about);
    return PopScope(
      canPop: _subpage == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _subpage != null) _closeSub();
      },
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLow,
        body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              section: _section,
              profile: _profile,
              onClose: () => Navigator.of(context).maybePop(),
              onSelect: (section) {
                setState(() {
                  _section = section;
                  _subpage = null;
                  _subpageTitle = null;
                });
              },
            ),
            VerticalDivider(
              width: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
            Expanded(
              child: ColoredBox(
                color: cs.surface,
                child: LayoutBuilder(
                  builder: (context, constraints) => Center(
                    child: SizedBox(
                      width: math.min(840.0, constraints.maxWidth),
                      height: constraints.maxHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showOwnHeader)
                            _PaneHeader(
                              title: _titleFor(_section),
                              showBack: false,
                              onBack: _closeSub,
                            ),
                          Expanded(child: _subpage ?? _paneBody()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _titleFor(DesktopSettingsSection section) {
    switch (section) {
      case DesktopSettingsSection.account:
        return 'Аккаунт';
      case DesktopSettingsSection.appearance:
        return 'Оформление';
      case DesktopSettingsSection.notifications:
        return 'Уведомления';
      case DesktopSettingsSection.privacy:
        return 'Конфиденциальность';
      case DesktopSettingsSection.spoof:
        return 'Подмена данных';
      case DesktopSettingsSection.devices:
        return 'Устройства';
      case DesktopSettingsSection.network:
        return 'Сеть';
      case DesktopSettingsSection.storage:
        return 'Хранилище';
      case DesktopSettingsSection.advanced:
        return 'Дополнительно';
      case DesktopSettingsSection.about:
        return 'О приложении';
    }
  }

  Widget _paneBody() {
    switch (_section) {
      case DesktopSettingsSection.account:
        return _AccountPane(
          profile: _profile,
          onEdit: () => _openSub('Профиль', const EditProfileScreen()),
          onQr: () {
            if (_profile == null) return;
            final name = [
              _profile!.firstName,
              _profile!.lastName ?? '',
            ].where((s) => s.trim().isNotEmpty).join(' ');
            showProfileQrSheet(
              context,
              name: name,
              avatarUrl: _profile!.baseUrl,
            );
          },
          onLogout: _logout,
        );
      case DesktopSettingsSection.appearance:
        return _AppearancePane(onOpen: _openSub);
      case DesktopSettingsSection.notifications:
        return const NotificationsScreen();
      case DesktopSettingsSection.privacy:
        return const SecurityScreen(embedded: true);
      case DesktopSettingsSection.spoof:
        return const SpoofScreen(embedded: true);
      case DesktopSettingsSection.devices:
        return const DevicesScreen();
      case DesktopSettingsSection.network:
        return const ProxySettingsSheet();
      case DesktopSettingsSection.storage:
        return const CloudStorageScreen();
      case DesktopSettingsSection.advanced:
        return const KometSettingsScreen();
      case DesktopSettingsSection.about:
        return _AboutPane(
          version: _version,
          checking: _checkingUpdate,
          onCheckUpdate: BuildProfile.selfUpdate ? _checkUpdate : null,
          onDebug: BuildProfile.devTools
              ? () => _openSub('Для разработчиков', const DebugMenuScreen())
              : null,
        );
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.profile,
    required this.onSelect,
    required this.onClose,
  });

  final DesktopSettingsSection section;
  final ProfileData? profile;
  final ValueChanged<DesktopSettingsSection> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = profile == null
        ? 'Komet'
        : [
            profile!.firstName,
            profile!.lastName ?? '',
          ].where((s) => s.trim().isNotEmpty).join(' ');
    return SizedBox(
      width: 256,
      child: ColoredBox(
        color: cs.surfaceContainerLow,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: onClose,
                    icon: const Icon(Symbols.close, size: 20),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Настройки',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Material(
                color: section == DesktopSettingsSection.account
                    ? cs.primary.withValues(alpha: 0.10)
                    : cs.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(DesktopSettingsSection.account),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: cs.surfaceContainerHighest,
                          backgroundImage: (profile?.baseUrl ?? '').isNotEmpty
                              ? CachedNetworkImageProvider(profile!.baseUrl!)
                              : null,
                          child: (profile?.baseUrl ?? '').isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'K',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                children: [
                          _NavTile(
                            icon: Symbols.palette,
                            label: 'Оформление',
                            selected:
                                section == DesktopSettingsSection.appearance,
                            onTap: () =>
                                onSelect(DesktopSettingsSection.appearance),
                          ),
                          _NavTile(
                            icon: Symbols.notifications_active,
                            label: 'Уведомления',
                            selected:
                                section == DesktopSettingsSection.notifications,
                            onTap: () =>
                                onSelect(DesktopSettingsSection.notifications),
                          ),
                          _NavTile(
                            icon: Symbols.lock,
                            label: 'Конфиденциальность',
                            selected: section == DesktopSettingsSection.privacy,
                            onTap: () =>
                              onSelect(DesktopSettingsSection.privacy),
                          ),
                          if (BuildProfile.spoofUi)
                            _NavTile(
                              icon: Symbols.phonelink_setup,
                              label: 'Подмена данных',
                              selected: section == DesktopSettingsSection.spoof,
                              onTap: () =>
                                  onSelect(DesktopSettingsSection.spoof),
                            ),
                          _NavTile(
                            icon: Symbols.devices,
                            label: 'Устройства',
                            selected: section == DesktopSettingsSection.devices,
                            onTap: () =>
                                onSelect(DesktopSettingsSection.devices),
                          ),
                          _NavTile(
                            icon: Symbols.vpn_lock,
                            label: 'Сеть',
                            selected: section == DesktopSettingsSection.network,
                            onTap: () =>
                                onSelect(DesktopSettingsSection.network),
                          ),
                          _NavTile(
                            icon: Symbols.cloud,
                            label: 'Хранилище',
                            selected: section == DesktopSettingsSection.storage,
                            onTap: () =>
                                onSelect(DesktopSettingsSection.storage),
                          ),
                          _NavTile(
                            icon: Symbols.tune,
                            label: 'Дополнительно',
                            selected:
                                section == DesktopSettingsSection.advanced,
                            onTap: () =>
                                onSelect(DesktopSettingsSection.advanced),
                          ),
                          _NavTile(
                            icon: Symbols.info,
                            label: 'О приложении',
                            selected: section == DesktopSettingsSection.about,
                            onTap: () => onSelect(DesktopSettingsSection.about),
                          ),
                        ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? KometTokens.of(context).selected : Colors.transparent,
        borderRadius: KometTokens.controlRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: KometTokens.controlRadius,
          hoverColor: cs.onSurface.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? KometTokens.of(context).onSelected
                      : cs.onSurfaceVariant,
                  weight: selected ? 600 : 400,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? KometTokens.of(context).onSelected
                          : cs.onSurface,
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                tooltip: 'Назад',
                onPressed: onBack,
                icon: const Icon(Symbols.arrow_back, size: 20),
              )
            else
              const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountPane extends StatelessWidget {
  const _AccountPane({
    required this.profile,
    required this.onEdit,
    required this.onQr,
    required this.onLogout,
  });

  final ProfileData? profile;
  final VoidCallback onEdit;
  final VoidCallback onQr;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (profile == null) return const Center(child: SmallSpinner(size: 32));
    final name = [
      profile!.firstName,
      profile!.lastName ?? '',
    ].where((s) => s.trim().isNotEmpty).join(' ');
    final phone = profile!.phone == 0 ? '' : '+${profile!.phone}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
      children: [
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: cs.surfaceContainerHighest,
                    backgroundImage: (profile!.baseUrl ?? '').isNotEmpty
                        ? CachedNetworkImageProvider(profile!.baseUrl!)
                        : null,
                    child: (profile!.baseUrl ?? '').isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'K',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 24,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (phone.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              phone,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ValueListenableBuilder<bool>(
                          valueListenable: KometSettings.selfOnlineCheck,
                          builder: (context, enabled, _) {
                            if (!enabled) return const SizedBox.shrink();
                            return ValueListenableBuilder<bool>(
                              valueListenable: SelfPresence.isOnline,
                              builder: (context, online, _) =>
                                  ValueListenableBuilder<int?>(
                                valueListenable: SelfPresence.lastSeenSeconds,
                                builder: (context, seen, _) => Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: online
                                              ? const Color(0xFF35B979)
                                              : cs.outline,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        online
                                            ? 'Онлайн · self-check'
                                            : seen != null
                                            ? '${formatLastSeen(seen)} · self-check'
                                            : 'Офлайн · self-check',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCard(
          children: [
            SettingsNavTile(
              icon: Symbols.edit,
              label: 'Изменить профиль',
              onTap: onEdit,
            ),
            SettingsNavTile(
              icon: Symbols.qr_code,
              label: 'QR-код',
              onTap: onQr,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCard(
          children: [
            SettingsNavTile(
              icon: Symbols.logout,
              label: 'Выйти из аккаунта',
              tint: cs.error,
              onTap: onLogout,
            ),
          ],
        ),
      ],
    );
  }
}

class _AppearancePane extends StatelessWidget {
  const _AppearancePane({required this.onOpen});

  final void Function(String title, Widget page) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
      children: [
        ValueListenableBuilder<DesktopDensityMode>(
          valueListenable: AppDesktopDensity.current,
          builder: (context, mode, _) => SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Плотность списка чатов'),
                    const SizedBox(height: 12),
                    SegmentedButton<DesktopDensityMode>(
                      segments: const [
                        ButtonSegment(
                          value: DesktopDensityMode.comfortable,
                          label: Text('Обычная'),
                        ),
                        ButtonSegment(
                          value: DesktopDensityMode.compact,
                          label: Text('Компактная'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (values) =>
                          AppDesktopDensity.save(values.single),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _InterfaceScaleCard(),
        const SizedBox(height: 16),
        SettingsCard(
          children: [
            SettingsNavTile(
              icon: Symbols.dark_mode,
              label: 'Тема',
              onTap: () => onOpen('Тема', const ThemeSettingsScreen()),
            ),
            SettingsNavTile(
              icon: Symbols.styler,
              label: 'Внешний вид',
              onTap: () => onOpen('Внешний вид', const AppearanceScreen()),
            ),
            SettingsNavTile(
              icon: Symbols.wallpaper,
              label: 'Фон чатов',
              onTap: () => onOpen('Фон чатов', const ChatBackgroundScreen()),
            ),
            SettingsNavTile(
              icon: Symbols.text_fields,
              label: 'Шрифты',
              onTap: () => onOpen('Шрифты', const FontSettingsScreen()),
            ),
            SettingsNavTile(
              icon: Symbols.touch_app,
              label: 'Меню действий',
              onTap: () =>
                  onOpen('Меню действий', const MessageActionsScreen()),
            ),
            SettingsNavTile(
              icon: Symbols.apps,
              label: 'Иконка приложения',
              onTap: () => onOpen('Иконка приложения', const AppIconScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

class _InterfaceScaleCard extends StatelessWidget {
  const _InterfaceScaleCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: DesktopUiScale.value,
      builder: (context, scale, _) {
        final percent = DesktopUiScale.percent;
        return SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Symbols.zoom_in, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Масштаб интерфейса',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Slider(
                value: scale,
                min: DesktopUiScale.min,
                max: DesktopUiScale.max,
                divisions:
                    ((DesktopUiScale.max - DesktopUiScale.min) /
                            DesktopUiScale.step)
                        .round(),
                label: '$percent%',
                onChanged: (v) => DesktopUiScale.set(v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Text(
                    '${(DesktopUiScale.min * 100).round()}%',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: percent == 100
                        ? null
                        : () => DesktopUiScale.set(DesktopUiScale.def),
                    child: const Text('100%'),
                  ),
                  const Spacer(),
                  Text(
                    '${(DesktopUiScale.max * 100).round()}%',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _ScalePreview(scale: scale),
            ),
          ],
        );
      },
    );
  }
}

class _ScalePreview extends StatelessWidget {
  const _ScalePreview({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatar = DesktopDensity.avatarRadius;
    final title = DesktopDensity.titleSize;
    final time = DesktopDensity.timeSize;
    final row = DesktopDensity.rowInnerHeight;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: KometTokens.controlRadius,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: avatar,
              backgroundColor: cs.primary.withValues(alpha: 0.18),
              child: Icon(Symbols.person, size: avatar, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: row,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Пример чата',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: title,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '12:04',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: time,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Так растут строка, аватар и кегль',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: DesktopDensity.previewSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPane extends StatelessWidget {
  const _AboutPane({
    required this.version,
    required this.checking,
    required this.onCheckUpdate,
    required this.onDebug,
  });

  final String? version;
  final bool checking;
  final VoidCallback? onCheckUpdate;
  final VoidCallback? onDebug;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
      children: [
        SettingsCard(
          children: [
            if (onCheckUpdate != null)
              SettingsNavTile(
                icon: Symbols.system_update,
                label: checking
                    ? AppLocalizations.of(context)!.updateChecking
                    : AppLocalizations.of(context)!.updateCheck,
                onTap: checking ? null : onCheckUpdate,
              ),
            if (onDebug != null)
              SettingsNavTile(
                icon: Symbols.construction,
                label: 'Для разработчиков',
                onTap: onDebug,
              ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            version ?? '',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.label,
    this.tint,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tint ?? cs.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tint ?? cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Symbols.chevron_right, size: 18, color: cs.outline),
          ],
        ),
      ),
    );
  }
}
