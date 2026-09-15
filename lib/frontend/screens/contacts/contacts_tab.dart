import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/cache/info_cache.dart';
import '../../../core/utils/format.dart';
import '../../../core/config/debug_test.dart';
import '../../../core/contacts/contact_labels.dart';
import '../../../core/contacts/device_contacts_service.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../../../backend/modules/contacts.dart';
import '../../../backend/modules/messages.dart' show ContactCache;
import 'package:komet/backend/app_services.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/contact_info.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/spectrum_tint.dart';
import '../../widgets/springy_tap.dart';
import '../chats/chat_info_screen.dart';
import 'add_contact_sheet.dart';
import 'nfc_exchange_sheet.dart';
import 'open_contact_profile.dart';
import '../../../core/config/app_frost.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/config/app_shape.dart';

enum _SearchMode { phone, id }

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> with SpectrumSurface {
  List<CachedContact> _contacts = [];
  bool _isLoading = true;
  bool _searchOpen = false;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  static bool get _nfcSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _loadContacts();
    ContactsModule.revision.addListener(_loadContacts);
    PresenceFetch.revision.addListener(_onPresenceChanged);
    _loadDeviceContacts();
  }

  void _onPresenceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDeviceContacts() async {
    final changed = await DeviceContactsService.ensureLoadedInteractive();
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    ContactsModule.revision.removeListener(_loadContacts);
    PresenceFetch.revision.removeListener(_onPresenceChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _openNfcExchange() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: AppFrost.scrim(),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => const Align(
        alignment: Alignment.topCenter,
        child: NfcExchangeSheet(),
      ),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  Future<void> _openAddContact() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (_) => _AddContactSheet(
        onManualAdd: () => showAddContactSheet(context),
        onNfcExchange: _nfcSupported ? _openNfcExchange : null,
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _query = '';
      }
    });
    if (_searchOpen) _searchFocus.requestFocus();
  }

  List<CachedContact> get _visibleContacts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    final digits = query.replaceAll(RegExp(r'[^\d]'), '');
    return _contacts.where((c) {
      final name = [
        c.firstName,
        c.lastName ?? '',
      ].where((s) => s.isNotEmpty).join(' ').toLowerCase();
      if (name.contains(query)) return true;
      if (digits.isNotEmpty) {
        if (c.phone.toString().contains(digits)) return true;
        if (c.id.toString().contains(digits)) return true;
      }
      return false;
    }).toList();
  }

  String? _presenceSubtitle(CachedContact contact) {
    final presence = PresenceFetch.live(contact.id);
    if (presence == null) return null;
    final status = presence['status'] as int?;
    if (status == 1) return 'В сети';
    if (status == 2 || status == 3) return 'Был(-а) недавно';
    final seen = presence['seen'] as int?;
    if (seen != null && seen > 0) return formatLastSeen(seen);
    return null;
  }

  Future<void> _loadContacts() async {
    if (DebugTest.enabled) {
      final debug = ContactsModule.debugContacts()
        ..sort((a, b) => a.firstName.compareTo(b.firstName));
      if (mounted) {
        setState(() {
          _contacts = debug;
          _isLoading = false;
        });
      }
      return;
    }

    final p = await AppDatabase.loadActiveProfile();
    if (p == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final contacts = await ContactsModule.getContacts(p.id);
    contacts.sort((a, b) => a.firstName.compareTo(b.firstName));
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    }
    unawaited(PresenceFetch.ensureFor(contacts.map((c) => c.id)));
  }

  Widget _buildContactItem(
    BuildContext context,
    ColorScheme cs,
    CachedContact contact,
  ) {
    final labels = contactLabels(
      idLabel: AppLocalizations.of(context)!.contactIdFallback('${contact.id}'),
      firstName: contact.firstName,
      lastName: contact.lastName,
      phone: contact.phone,
    );
    final nameToDisplay = labels.title;
    final subtitle = _presenceSubtitle(contact) ?? labels.subtitle;

    return SpringyTap(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openContactDialogProfile(
            context,
            contactId: contact.id,
            name: nameToDisplay,
            avatarUrl: contact.baseUrl,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: KometAvatar(
                    name: nameToDisplay,
                    imageUrl: contact.baseUrl,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              nameToDisplay,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Symbols.verified,
                              color: cs.primary,
                              size: 16,
                              weight: 600,
                              fill: 1,
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: spectrumSurfaceColor(cs),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Контакты',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            fontFamily: displayFontOf(context),
                          ),
                        ),
                        const ConnectionStatusLine(),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Добавить контакт',
                    icon: Icon(Symbols.person_add, color: cs.onSurface),
                    onPressed: _openAddContact,
                  ),
                  IconButton(
                    tooltip: 'Поиск по контактам',
                    icon: Icon(
                      _searchOpen ? Symbols.close : Symbols.search,
                      color: cs.onSurface,
                    ),
                    onPressed: _toggleSearch,
                  ),
                ],
              ),
            ),
            if (_searchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: (value) => setState(() => _query = value),
                  style: TextStyle(color: cs.onSurface, fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    hintText: 'Имя, номер или ID',
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Symbols.search,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              Symbols.cancel,
                              color: cs.onSurfaceVariant,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoading) {
                    return const Center(child: SmallSpinner(size: 36));
                  }
                  final visible = _visibleContacts;
                  if (visible.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _contacts.isEmpty
                                  ? 'Нет контактов'
                                  : 'Ничего не найдено',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                            if (_contacts.isNotEmpty && _query.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _openAddContact,
                                icon: const Icon(Symbols.person_search,
                                    size: 18),
                                label: const Text('Найти по номеру или ID'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: visible.length,
                    itemBuilder: (context, index) =>
                        _buildContactItem(context, cs, visible[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({required this.onManualAdd, this.onNfcExchange});

  final VoidCallback onManualAdd;
  final VoidCallback? onNfcExchange;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _controller = TextEditingController();
  _SearchMode _mode = _SearchMode.phone;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setMode(_SearchMode mode) {
    if (_mode == mode || _loading) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_mode == _SearchMode.phone) {
      await _submitPhone();
    } else {
      await _submitId();
    }
  }

  String? _phoneCandidate(String query) {
    if (!RegExp(r'^[+\d\s\-()]+$').hasMatch(query)) return null;
    final digits = query.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 5) return null;
    return query;
  }

  Future<void> _submitPhone() async {
    final query = _phoneCandidate(_controller.text.trim());
    if (query == null) {
      setState(() => _error = 'Введите корректный номер телефона');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ContactsModule.findByPhone(api, query);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _loading = false;
          _error = 'Контакт с таким номером не найден';
        });
        return;
      }
      final navigator = Navigator.of(context);
      final accountId = await TokenStorage.getActiveAccountId();
      final existing = accountId == null
          ? null
          : await AppDatabase.findDialogChatByParticipant(accountId, result.id);
      final chatId = existing ?? ((accountId ?? 0) ^ result.id);
      if (!mounted) return;
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatInfoScreen(
            chatId: chatId,
            name:
                ContactCache.get(result.id) ??
                result.name ??
                AppLocalizations.of(
                  context,
                )!.contactIdFallback('${result.id}'),
            imageUrl: result.avatarUrl ?? '',
            chatType: 'DIALOG',
            dialogPeerId: result.id,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка: $e';
        });
      }
    }
  }

  Future<void> _submitId() async {
    final raw = _controller.text.trim();
    final id = int.tryParse(raw);
    if (id == null) {
      setState(() => _error = 'Введите числовой ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final packet = await api.sendRequest(Opcode.contactInfo, {
        'contactIds': [id],
      });
      final contacts = (packet.payload as Map?)?['contacts'] as List?;
      if (contacts == null || contacts.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Контакт с таким ID не найден';
          });
        }
        return;
      }
      final raw = Map<String, dynamic>.from(contacts.first as Map);
      final info = ContactInfo.fromMap(raw);
      ContactsModule.primeContactCache(raw);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final accountId = await TokenStorage.getActiveAccountId();
      final existing = accountId == null
          ? null
          : await AppDatabase.findDialogChatByParticipant(accountId, id);
      final chatId = existing ?? ((accountId ?? 0) ^ id);
      if (!mounted) return;
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatInfoScreen(
            chatId: chatId,
            name:
                ContactCache.get(id) ??
                info.displayName ??
                AppLocalizations.of(context)!.contactIdFallback('$id'),
            imageUrl: info.avatarUrl ?? '',
            chatType: 'DIALOG',
            dialogPeerId: id,
          ),
        ),
      );
    } on PacketError catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Добавить контакт',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<_SearchMode>(
                segments: const [
                  ButtonSegment(
                    value: _SearchMode.phone,
                    label: Text('Номер'),
                    icon: Icon(Symbols.call, size: 18),
                  ),
                  ButtonSegment(
                    value: _SearchMode.id,
                    label: Text('ID'),
                    icon: Icon(Symbols.tag, size: 18),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _setMode(s.first),
                showSelectedIcon: false,
                style: ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: _mode == _SearchMode.phone
                    ? TextInputType.phone
                    : TextInputType.number,
                enabled: !_loading,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: TextStyle(color: cs.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: _mode == _SearchMode.phone
                      ? 'Введите номер телефона'
                      : 'Введите ID контакта',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    _mode == _SearchMode.phone ? Symbols.call : Symbols.tag,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.error_outline,
                        size: 18,
                        color: cs.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  shape: AppShape.buttonBorder,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SmallSpinner(size: 20)
                    : const Text('Найти'),
              ),
              const SizedBox(height: 8),
              _AddContactAction(
                icon: Symbols.person_add,
                label: 'Добавить вручную',
                hint: 'Номер телефона и имя',
                onTap: () {
                  Navigator.pop(context);
                  widget.onManualAdd();
                },
              ),
              if (widget.onNfcExchange != null)
                _AddContactAction(
                  icon: Symbols.nfc,
                  label: 'Обменяться по NFC',
                  hint: 'Приложите телефоны друг к другу',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNfcExchange!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _AddContactAction extends StatelessWidget {
  const _AddContactAction({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: cs.onSurfaceVariant, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Symbols.chevron_right, color: cs.outline, size: 18),
          ],
        ),
      ),
    );
  }
}
