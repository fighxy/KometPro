import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_shape.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/haptics.dart';
import '../komet_app.dart' show KometApp;
import '../screens/auth/login_screen.dart';
import '../screens/digital_id/digital_id_web_screen.dart';
import 'adaptive_shell.dart';
import 'app_scope.dart';
import 'custom_notification.dart';
import 'komet_avatar.dart';
import 'sheet_helpers.dart';

/// The profile flows every entry point shares: the chat list's long-press
/// switcher, the phone settings tab and the desktop settings page all call
/// these so adding and switching behave identically wherever they start.
abstract final class AccountFlows {
  /// Parks the current session and opens a login screen for a new profile.
  ///
  /// The session is not signed out — the token stays in storage and the login
  /// screen carries the account to return to, so backing out of it restores
  /// exactly what was running before.
  static Future<void> addProfile(BuildContext context) async {
    final navigator = Navigator.of(context);
    final account = AppScope.read(context).account;
    final previousId = await TokenStorage.getActiveAccountId();
    await resetDigitalIdSession();
    try {
      await account.beginAddAccount();
    } catch (_) {}
    if (!context.mounted) return;
    await navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(returnToAccountId: previousId),
      ),
      (route) => false,
    );
  }

  /// Brings [accountId] online and restarts the shell on top of it.
  static Future<bool> switchTo(BuildContext context, int accountId) async {
    final navigator = Navigator.of(context);
    final account = AppScope.read(context).account;
    await resetDigitalIdSession();
    try {
      await account.switchAccount(accountId);
    } catch (_) {
      if (context.mounted) {
        showCustomNotification(context, 'Не удалось переключить аккаунт');
      }
      return false;
    }
    if (!context.mounted) return true;
    await navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdaptiveShell()),
      (route) => false,
    );
    return true;
  }

  /// Signs the active profile out and falls back to the next signed-in one.
  ///
  /// A logout removes only that account, so while another profile is still
  /// alive the app switches into it instead of dropping the user on a login
  /// screen they have no reason to see.
  static Future<void> logout(BuildContext context) async {
    final deps = AppScope.read(context);
    final navigator =
        KometApp.navigatorKey.currentState ?? Navigator.of(context);
    try {
      await deps.account.logout();
    } catch (e) {
      if (context.mounted) {
        showCustomNotification(context, 'Не удалось выйти: $e');
      }
      return;
    }
    await resetDigitalIdSession();

    final remaining = await deps.account.otherAccounts();
    if (remaining.isNotEmpty) {
      try {
        await deps.account.switchAccount(remaining.first.id);
        await navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdaptiveShell()),
          (route) => false,
        );
        return;
      } catch (_) {}
    }

    try {
      await deps.api.connect();
    } catch (_) {}
    await navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Lists every signed-in profile plus a way to add one more.
  static Future<void> showPicker(BuildContext context) async {
    final others = await AppScope.read(context).account.otherAccounts();
    if (!context.mounted) return;
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final profile in others)
              ListTile(
                leading: KometAvatar(
                  name: _displayName(profile),
                  imageUrl: profile.baseUrl,
                  size: 40,
                ),
                title: Text(_displayName(profile)),
                subtitle: Text('ID ${profile.id}'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(switchTo(context, profile.id));
                },
              ),
            ListTile(
              leading: Icon(Symbols.person_add, color: cs.primary),
              title: Text(
                'Добавить профиль',
                style: TextStyle(color: cs.primary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(addProfile(context));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _displayName(ProfileData profile) {
    final last = profile.lastName ?? '';
    final name = '${profile.firstName} $last'.trim();
    return name.isEmpty ? 'ID ${profile.id}' : name;
  }
}

/// A capsule naming the profile a switch would go back to, with a way to
/// reach the rest of them.
///
/// It renders nothing while the device holds a single account, so the
/// settings screens can place it unconditionally.
class AccountSwitchBar extends StatefulWidget {
  const AccountSwitchBar({super.key, this.compact = false});

  /// Desktop packs the capsule beside the name and ID, where it carries
  /// neither the trailing label nor the list padding.
  final bool compact;

  @override
  State<AccountSwitchBar> createState() => _AccountSwitchBarState();
}

class _AccountSwitchBarState extends State<AccountSwitchBar> {
  List<ProfileData> _others = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final others = await AppScope.read(context).account.otherAccounts();
    if (!mounted) return;
    setState(() => _others = others);
  }

  @override
  Widget build(BuildContext context) {
    if (_others.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final previous = _others.first;
    final name = AccountFlows._displayName(previous);

    final capsule = Material(
      color: cs.surfaceContainerHighest,
      borderRadius: AppShape.pillRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Haptics.tap();
          unawaited(
            _others.length == 1
                ? AccountFlows.switchTo(context, previous.id)
                : AccountFlows.showPicker(context),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KometAvatar(name: name, imageUrl: previous.baseUrl, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.compact) return capsule;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Flexible(child: capsule),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () {
              Haptics.tap();
              unawaited(AccountFlows.showPicker(context));
            },
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Сменить аккаунт'),
          ),
        ],
      ),
    );
  }
}
