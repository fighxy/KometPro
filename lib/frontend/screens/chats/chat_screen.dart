import 'dart:async';
import 'dart:convert' show base64Encode;
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:komet/backend/modules/chat_preview.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/comments.dart';
import 'package:komet/backend/modules/upload_service.dart';
import 'package:komet/backend/modules/webapp.dart';
import 'package:komet/frontend/screens/webapp/open_mini_app.dart';
import 'package:komet/frontend/widgets/sending_clock_icon.dart';
import 'package:komet/core/media/desktop_video_probe.dart';
import 'package:komet/core/media/video_transcoder.dart';
import 'package:komet/core/media/clipboard/clipboard_media.dart';
import 'package:komet/core/media/clipboard/pasted_attachment.dart';
import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/frontend/screens/chats/chat_info_screen.dart';
import 'package:komet/frontend/screens/contacts/open_contact_profile.dart';
import 'package:komet/frontend/screens/chats/chat_list_screen.dart';
import 'package:komet/frontend/screens/chats/poll_create_screen.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/chat_menu_overlay.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../l10n/app_localizations.dart';
import '../../../backend/api.dart';
import '../../../backend/modules/messages.dart';
import '../../../backend/modules/contacts.dart';
import '../../../backend/modules/animoji.dart';
import '../../../models/animoji.dart';
import '../../../backend/modules/complaints.dart';
import '../../../core/calls/call_controller.dart';
import '../../../core/media/rlottie/rlottie.dart';
import '../calls/call_screen.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/push/notification_bridge.dart';
import '../../../core/push/push_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/chat_activity_store.dart';
import '../../../core/storage/chat_members_store.dart';
import '../../../core/crypto/chat_crypto_service.dart';
import '../../../core/crypto/encrypted_photo.dart';
import '../../../core/crypto/message_decryption_cache.dart';
import '../../../core/storage/chat_encryption_store.dart';
import '../../../core/storage/chat_wallpaper_store.dart';
import '../../../core/storage/draft_store.dart';
import '../../../core/storage/archived_chats_store.dart';
import '../../../core/cache/info_cache.dart';
import '../../../core/cache/message_session_cache.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/chat_layout.dart';
import '../../../core/utils/emoji_keyword_index.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/route_settle.dart';
import '../../../core/config/app_cache_extent.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/app_message_actions_style.dart';
import '../../../core/config/app_swipe_back_desktop.dart';
import 'chat/chat_prank_controller.dart';
import 'chat/chat_controller.dart';
import 'chat/read_marker_gate.dart';
import 'chat/voice_record_controller.dart';
import 'chat/video_note_controller.dart';
import 'chat/command_panel_controller.dart';
import 'chat/sticker_panel_controller.dart';
import 'chat/chat_search_controller.dart';
import 'chat/message_search_result.dart';
import 'chat/typing_label.dart';
import 'chat/upload_status.dart';
import 'chat/view/chat_chrome.dart';
import 'chat/view/chat_list_items.dart';
import 'chat/view/edit_message_sheet.dart';
import 'chat/view/message_row_animations.dart';
import 'chat/view/pinned_message_banner.dart';
import 'chat/view/selectable_message_row.dart';
import 'chat/view/swipe_to_reply.dart';
import 'chat/view/search_view.dart';
import 'chat/view/composer_input.dart';
import 'chat/view/sticker_panel_view.dart';
import 'chat/view/command_panel_view.dart';
import 'chat/view/mention_panel_view.dart';
import 'chat/mention_panel_controller.dart';
import 'chat/view/selection_bar.dart';
import 'chat/view/chat_header.dart';
import 'chat/view/shimmer_loading.dart';
import '../../widgets/app_scope.dart';
import '../../../backend/app_deps.dart';
import '../../../core/config/app_commands.dart';
import '../../../core/config/app_visual_style.dart';
import '../../../core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_composer_background.dart';
import 'package:komet/core/config/app_frost.dart';
import 'package:komet/core/config/app_composer_style.dart';
import '../../../core/config/komet_settings.dart';
import '../../../models/attachment.dart';
import '../../../models/contact_info.dart';
import '../../../models/sticker.dart';
import '../../commands/command_registry.dart';
import '../../commands/slash_command.dart';
import '../../widgets/rich_message_controller.dart';
import '../../../core/utils/text_format.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/photo_viewer.dart';
import '../../widgets/message_actions_overlay.dart';
import '../../widgets/lottie_image.dart';
import '../../widgets/attachment_panel.dart';
import '../../widgets/attachment/attachment_sheet.dart';
import '../../widgets/attachment/paste_preview_sheet.dart';
import '../../widgets/sticker_pack_sheet.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/swipe_to_pop.dart';
import '../../widgets/reload_on_reconnect.dart';
import '../../widgets/schedule_time_picker.dart';
import '../../widgets/chat_wallpaper_sheet.dart';
import '../../widgets/chat_wallpaper_view.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/liquid_glass.dart';
import 'scheduled_messages_screen.dart';
import 'chat_encryption_screen.dart';
import 'chat_wallpaper_preview_screen.dart';
import 'profile_action_sheets.dart';
import '../../../core/media/media_playback.dart';
import '../../widgets/media_playback_pill.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/config/app_shape.dart';


part 'chat/view/chat_screen_app_bar.dart';
part 'chat/view/chat_screen_composer.dart';
part 'chat/view/chat_screen_transcript.dart';
part 'chat/view/chat_screen_history.dart';
part 'chat/view/chat_screen_navigation.dart';
part 'chat/view/chat_screen_selection.dart';
part 'chat/view/chat_screen_send.dart';

class ForwardRequest {
  final int sourceChatId;
  final String sourceChatName;
  final String sourceChatIconUrl;
  final String sourceChatType;
  final List<CachedMessage> messages;

  ForwardRequest({
    required this.sourceChatId,
    required this.sourceChatName,
    required this.sourceChatIconUrl,
    required this.sourceChatType,
    required List<CachedMessage> messages,
  }) : messages = List.unmodifiable(messages);

  ForwardRequest withMessages(List<CachedMessage> value) => ForwardRequest(
    sourceChatId: sourceChatId,
    sourceChatName: sourceChatName,
    sourceChatIconUrl: sourceChatIconUrl,
    sourceChatType: sourceChatType,
    messages: value,
  );
}

class ReplyRequest {
  final int sourceChatId;
  final CachedMessage message;

  const ReplyRequest({required this.sourceChatId, required this.message});
}

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;
  final bool? channelSubscribed;
  final bool embedded;
  final VoidCallback? onClose;
  final ForwardRequest? forwardRequest;
  final ReplyRequest? replyRequest;
  final String? initialMessageId;
  final int? initialMessageTime;
  final String? commentPostId;
  final CachedMessage? postMessage;
  final String? botStartPayload;
  final String? initialText;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    this.channelSubscribed,
    this.embedded = false,
    this.onClose,
    this.forwardRequest,
    this.replyRequest,
    this.initialMessageId,
    this.initialMessageTime,
    this.commentPostId,
    this.postMessage,
    this.botStartPayload,
    this.initialText,
  });

  static final List<_ChatScreenState> _open = [];

  static bool startBotInVisibleChat(int chatId, String startPayload) {
    for (final screen in _open.reversed) {
      if (screen.widget.chatId != chatId) continue;
      if (!screen.mounted || !screen._isRouteCurrent) continue;
      unawaited(screen._sendBotStart(startPayload));
      return true;
    }
    return false;
  }

  static bool openSearchInVisibleChat() {
    for (final screen in _open.reversed) {
      if (!screen.mounted || !screen._isRouteCurrent) continue;
      screen._openSearch();
      return true;
    }
    return false;
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, ReloadOnReconnect {
  final RichMessageController _messageController = RichMessageController();
  final FocusNode _messageFocusNode = FocusNode();
  double _keyboardReserve = 0;
  bool _keyboardWasOpen = false;
  bool _keyboardBeforeStickers = false;
  final ScrollController _scrollController = ScrollController();
  bool _userDidScroll = false;
  int _userGestureEpoch = 0;
  String? _pinnedMessageId;
  double _pinnedAlignment = 0;
  int? _unreadAnchorTime;
  bool _awaitingPosition = false;
  bool _navigatingToTarget = false;
  bool _initialPositionDone = false;
  bool _positioningInFlight = false;
  bool _initialTargetHandled = false;
  int _historyAutoloadSuppressCount = 0;
  bool get _historyAutoloadSuppressed => _historyAutoloadSuppressCount > 0;
  int _readMarkTime = 0;
  late final ReadMarkerGate _readMarker = ReadMarkerGate(
    onFlush: _updateReadMarker,
  );
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _unreadSeparatorKey = GlobalKey();
  final Object _profileHeroTag = UniqueKey();
  final ValueNotifier<bool> _hasText = ValueNotifier(false);
  bool _isLoading = true;
  bool _encryptionEnabled = false;
  final ValueNotifier<bool> _showAttachmentPanel = ValueNotifier(false);
  bool _pastePending = false;
  late final StickerPanelController _stickers;
  final ValueNotifier<UploadStatus> _uploadStatus = ValueNotifier(
    const UploadStatus(),
  );
  String? _uploadStatusJobId;
  ValueListenable<UploadBytes>? _uploadStatusBytes;
  StreamSubscription<Packet>? _pushSub;
  StreamSubscription<MessageEvent>? _messageEventSub;
  StreamSubscription<Map<String, CommentsInfo>>? _commentsInfoSub;
  StreamSubscription<CommentAddedEvent>? _commentSub;
  final Map<String, int> _commentCounts = {};
  final Set<String> _commentCountsRequested = {};
  bool get _commentsMode => widget.commentPostId != null;
  bool _commentsLoadingMore = false;
  bool _commentsHasMore = true;
  StreamSubscription<SessionState>? _connSub;
  final Map<String, ValueNotifier<Map<String, dynamic>?>> _reactionNotifiers =
      {};
  final ValueNotifier<ReactionAnimationEvent?> _reactionAnimation =
      ValueNotifier(null);
  int _reactionAnimationToken = 0;
  final ValueNotifier<int> _scheduledCount = ValueNotifier(0);

  late final VoiceRecordController _voiceRec = VoiceRecordController(
    contextOf: () => context,
    isMounted: () => mounted,
    myId: () => _myId,
    onRecorded: _sendVoice,
  );

  late final VideoNoteController _note = VideoNoteController(
    contextOf: () => context,
    isMounted: () => mounted,
    onRecorded: _sendVideoNote,
    formatElapsed: formatVoiceElapsed,
    bottomInset: () => _composerHeight.value,
  );

  StreamSubscription<UploadJobEvent>? _uploadEventSub;

  ValueListenable<List<double>>? _photoProgressFor(CachedMessage m) =>
      UploadService.instance.progressFor(m.id);

  ValueNotifier<Map<String, dynamic>?> _reactionNotifierFor(CachedMessage m) {
    final existing = _reactionNotifiers[m.id];
    if (existing != null) return existing;
    final info = m.payload?['reactionInfo'];
    final notifier = ValueNotifier<Map<String, dynamic>?>(
      info is Map ? Map<String, dynamic>.from(info) : null,
    );
    _reactionNotifiers[m.id] = notifier;
    return notifier;
  }

  void _reactToMessage(CachedMessage message, String emoji) {
    if (message.isControl || message.id.startsWith('temp_')) return;
    final notifier = _reactionNotifierFor(message);
    final previous = notifier.value;
    final applied = _applyLocalReaction(previous, emoji);
    notifier.value = applied;
    final isToggleOff = applied == null || applied['yourReaction'] == null;
    unawaited(_sendReaction(message, emoji, isToggleOff, previous));
  }

  Future<void> _sendReaction(
    CachedMessage message,
    String emoji,
    bool isToggleOff,
    Map<String, dynamic>? previous,
  ) async {
    ({bool ok, Map<String, dynamic>? info}) result;
    try {
      result = isToggleOff
          ? await _deps.messages.cancelReaction(widget.chatId, message.id)
          : await _deps.messages.setReaction(widget.chatId, message.id, emoji);
    } catch (_) {
      result = (ok: false, info: null);
    }
    if (!mounted) return;
    final notifier = _reactionNotifiers[message.id];
    if (notifier == null) return;
    if (!result.ok) {
      notifier.value = previous;
      Haptics.error();
      showCustomNotification(context, 'Не удалось обновить реакцию');
      return;
    }
    notifier.value = result.info;
    _applyReactionInfoToMessage(message.id, result.info);
    final appliedReaction = result.info?['yourReaction']?.toString();
    if (!isToggleOff &&
        appliedReaction != null &&
        EmojiKeywordIndex.normalize(appliedReaction) ==
            EmojiKeywordIndex.normalize(emoji)) {
      final event = ReactionAnimationEvent(
        messageId: message.id,
        emoji: appliedReaction,
        token: ++_reactionAnimationToken,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reactionAnimation.value = event;
      });
    }
  }

  void _applyReactionInfoToMessage(
    String messageId,
    Map<String, dynamic>? info,
  ) {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final payload = <String, dynamic>{...?_messages[idx].payload};
    if (info == null) {
      payload.remove('reactionInfo');
    } else {
      payload['reactionInfo'] = info;
    }
    _messages[idx] = _messages[idx].copyWith(payload: payload);
  }

  Map<String, dynamic>? _applyLocalReaction(
    Map<String, dynamic>? current,
    String emoji,
  ) {
    final counters = <String, int>{};
    final order = <String>[];
    final rawCounters = current?['counters'];
    if (rawCounters is List) {
      for (final c in rawCounters) {
        if (c is! Map) continue;
        final r = c['reaction']?.toString();
        if (r == null || r.isEmpty) continue;
        final n = c['count'];
        counters[r] = n is int ? n : 0;
        order.add(r);
      }
    }

    void decrement(String key) {
      final next = (counters[key] ?? 1) - 1;
      if (next <= 0) {
        counters.remove(key);
        order.remove(key);
      } else {
        counters[key] = next;
      }
    }

    final prev = current?['yourReaction']?.toString();
    String? your;
    if (prev != null &&
        EmojiKeywordIndex.normalize(prev) ==
            EmojiKeywordIndex.normalize(emoji)) {
      decrement(prev);
      your = null;
    } else {
      if (prev != null && prev.isNotEmpty) decrement(prev);
      if (!counters.containsKey(emoji)) order.add(emoji);
      counters[emoji] = (counters[emoji] ?? 0) + 1;
      your = emoji;
    }

    if (counters.isEmpty) return null;
    final total = counters.values.fold<int>(0, (a, b) => a + b);
    return {
      'counters': [
        for (final key in order) {'reaction': key, 'count': counters[key]},
      ],
      'yourReaction': ?your,
      'totalCount': total,
    };
  }

  void _pruneReactionNotifiers() {
    final liveIds = _messages.map((m) => m.id).toSet();
    final dead = _reactionNotifiers.keys
        .where((id) => !liveIds.contains(id))
        .toList();
    for (final id in dead) {
      _reactionNotifiers.remove(id)?.dispose();
    }
    _messageKeys.removeWhere((id, _) => !liveIds.contains(id));
  }

  int _otherStatus = 0;
  int? _otherSeenTime;

  final ValueNotifier<CachedMessage?> _replyTo = ValueNotifier(null);
  final ValueNotifier<List<CachedMessage>> _pendingForwards = ValueNotifier(
    const [],
  );
  static const bool _crossChatReplySupported = false;
  int? _replySourceChatId;
  ForwardRequest? _forwardRequest;
  bool _forwardSending = false;
  final ValueNotifier<String?> _highlightMessageId = ValueNotifier(null);
  Timer? _highlightTimer;
  final ValueNotifier<double?> _jumpCacheExtent = ValueNotifier<double?>(null);
  Timer? _goToMessageSettleTimer;
  static const double _jumpCacheExtentPx = 800.0;

  late final RouteSettle _routeSettle = RouteSettle(isMounted: () => mounted);

  late final ChatSearchController _search;
  late final AnimationController _searchAnim;
  final FocusNode _searchFocusNode = FocusNode();

  late final ChatPrankController _prank = ChatPrankController(
    vsync: this,
    contextOf: () => context,
    isMounted: () => mounted,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );
  final ValueNotifier<String> _headerStatusNotifier = ValueNotifier('');
  final ValueNotifier<int> _otherReadTime = ValueNotifier(0);
  int _tempIdCounter = 0;
  late final AnimationController _attachAnim;
  late final CommandPanelController _commandPanel;
  late final MentionPanelController _mentionPanel;

  String _nextTempId() =>
      'temp_${++_tempIdCounter}_${DateTime.now().microsecondsSinceEpoch}';
  late AnimationController _shimmerController;
  Timer? _shimmerStartTimer;
  bool _previewChat = false;
  bool _subscribing = false;
  String? _channelLink;
  late final AppDeps _deps;
  late final ChatController _chatController;

  List<CachedMessage> get _messages => _chatController.messages;
  set _messages(List<CachedMessage> v) => _chatController.messages = v;
  ValueNotifier<int> get _messagesRev => _chatController.messagesRev;
  bool get _historyKickedOff => _chatController.historyKickedOff;
  set _historyKickedOff(bool v) => _chatController.historyKickedOff = v;

  final GlobalKey _messageListKey = GlobalKey();
  _ChatMessageList? _messageListWidget;
  final Set<String> _deletingIds = {};

  static const double _avgMessageHeight = 72.0;
  static const double _historyPrefetchExtent = _avgMessageHeight * 8;
  static const double _scrollDownRevealExtent = _avgMessageHeight * 30;
  static const double _scrollDownRevealFactor = 0.6;
  static const double _scrollDownTeleportFactor = 2.0;
  static const double _glossyHeaderHeight = 76.0;
  static const double _glossySearchHeight = 58.0;
  static const double _pinnedBannerLift = 6.0;
  static const double _edgeFadeHeight = 24.0;
  static const double _scrollDownSize = 46.0;
  static const double _materialIconSlot = 48.0;
  static const double _unreadSeparatorHeight = 30.0;
  static const double _unreadSeparatorInset = 72.0;
  static const double _unreadAnchorFallbackAlignment = 0.3;
  static const int _jumpStallLimit = 8;
  static const int _jumpFrameLimit = 240;
  static const double _jumpStepMaxScreens = 4.0;

  final BackdropKey _barBackdrop = BackdropKey();
  final BackdropKey _pillBackdrop = BackdropKey();
  bool get _isLoadingMore => _chatController.isLoadingMore;
  set _isLoadingMore(bool v) => _chatController.isLoadingMore = v;
  bool get _hasMoreHistory => _chatController.hasMoreHistory;
  set _hasMoreHistory(bool v) => _chatController.hasMoreHistory = v;
  List<Object>? _combinedItemsCache;
  int? _combinedItemsKey;
  bool _floatingDateScheduled = false;
  int get _myId => _chatController.myId;
  set _myId(int v) => _chatController.myId = v;

  bool _sessionAlive([int? gen]) =>
      mounted && (gen == null || _chatController.accept(gen));
  CachedChat? chat;
  bool _peerIsBot = false;
  bool _botStartRequested = false;
  ChatWallpaper? _wallpaper;

  bool get _composerFrosted =>
      AppComposerBackground.current.value != ComposerBackground.standard;

  bool get _composerUnderlap =>
      AppChatChrome.current.value != ChatChromeStyle.color || _composerFrosted;

  bool get _materialComposer =>
      !ComposerChrome.isGlossy(AppComposerStyle.current.value);

  bool get _composerPaintsSurface {
    if (!_commentsMode &&
        widget.chatType == 'CHANNEL' &&
        _pendingForwards.value.isEmpty) {
      return false;
    }
    return _materialComposer && !_composerFrosted;
  }

  bool get _liquidChrome =>
      AppVisualStyle.current.value.glossyChrome &&
      ChatChromeMaterial.isLiquid(AppChatChrome.current.value);

  ChatChromeStyle get _effectiveChrome {
    final chrome = AppChatChrome.current.value;
    if (chrome == ChatChromeStyle.liquidGlass) {
      return ChatChromeStyle.transparent;
    }
    return chrome;
  }

  bool get _chromeVignette =>
      _effectiveChrome == ChatChromeStyle.none && _wallpaper == null;

  final ValueNotifier<double> _composerHeight = ValueNotifier(96);
  final ValueNotifier<double> _pinnedBannerHeight = ValueNotifier(0);

  final ValueNotifier<DateTime?> _floatingDate = ValueNotifier(null);
  Timer? _floatingDateTimer;
  late final AnimationController _floatingDateAnimController;
  late final CurvedAnimation _floatingDateCurved;
  late final AnimationController _scrollDownAnimController;
  late final CurvedAnimation _scrollDownCurved;
  bool _scrollDownVisible = false;
  final ValueNotifier<int> _newMessageCount = ValueNotifier(0);
  bool _clearCountScheduled = false;
  final Set<String> _deferredIds = <String>{};
  int _listEpoch = 0;
  final List<({String id, double pixels, double alignment})> _returnStack = [];
  bool _returningToAnchor = false;
  final Map<int, GlobalKey> _separatorKeys = {};
  String? _lastSentId;
  final ValueNotifier<int> _otherUnread = ValueNotifier(0);
  final ValueNotifier<bool> _animojiHold = ValueNotifier(true);

  final ValueNotifier<Set<String>> _selectedIds = ValueNotifier(const {});
  final ValueNotifier<Offset?> _textSelectionDrag = ValueNotifier(null);
  final ValueNotifier<({String id, Offset pos})?> _textSelection =
      ValueNotifier(null);
  late final AnimationController _selectionAnim;

  bool get _selectionMode => _selectedIds.value.isNotEmpty;

  void _prewarmQuickReactions() {
    if (!mounted || !RlottieEngine.instance.available) return;
    final dpr = (MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0).clamp(
      1.0,
      2.0,
    );
    final px = ((44.0 * dpr).clamp(96.0, 512.0) / 32).ceil() * 32;
    for (final a in _deps.animoji.quickAnimojis) {
      for (final url in [a.lottieUrl, a.lottiePlayUrl]) {
        if (url != null && url.isNotEmpty) {
          unawaited(RlottieEngine.instance.prewarm(url, px));
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _deps = deps;
    _chatController = ChatController(
      api: deps.api,
      messages: deps.messages,
      chats: deps.chats,
    );
    _previewChat = widget.channelSubscribed == false;
    _chatController.attach(chatId: widget.chatId);
    _chatController.isMounted = () => mounted;
    if (!_commentsMode) ChatScreen._open.add(this);
    unawaited(PushService.clearChatNotification(widget.chatId));
    if (!_commentsMode) {
      unawaited(NotificationBridge.instance.pushActiveChat(widget.chatId));
    }
    unawaited(
      _deps.animoji
          .ensureLoaded()
          .then((_) {
            _prewarmQuickReactions();
            if (mounted) _bumpMessages();
          })
          .catchError((_) {}),
    );
    WidgetsBinding.instance.addObserver(this);
    _uploadEventSub = UploadService.instance.events.listen(_onUploadEvent);
    _syncUploadStatus();
    _deps.chats.chatsChanged.addListener(_onChatsBump);
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollForDate);
    _scrollController.addListener(_maybeLoadMoreHistory);
    _scrollController.addListener(_recordScrollPixels);
    _scrollController.addListener(_scheduleReadMarker);
    _scrollController.addListener(_updateScrollDownVisible);
    MediaPlayback.instance.enterChat(widget.chatId);
    if (widget.chatType == 'CHAT') {
      unawaited(_ensureChatRoles());
    }
    AppVisualStyle.current.addListener(_onVisualStyleChanged);
    AppChatChrome.current.addListener(_onVisualStyleChanged);
    AppComposerStyle.current.addListener(_onVisualStyleChanged);
    AppComposerBackground.current.addListener(_onVisualStyleChanged);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _attachAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _stickers = StickerPanelController(
      vsync: this,
      onSendTyping: () => _deps.messages.sendTyping(widget.chatId, 'STICKER'),
    );
    _showAttachmentPanel.addListener(_onAttachPanelToggle);
    _commandPanel = CommandPanelController(
      vsync: this,
      textOf: () => _messageController.text,
      onSelected: _onCommandSelected,
    );
    _mentionPanel = MentionPanelController(
      vsync: this,
      chatId: widget.chatId,
      enabled: _mentionsAvailable,
      selfId: () => _myId,
      valueOf: () => _messageController.value,
      onSelected: _onMentionSelected,
    );
    _selectionAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _searchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _search = ChatSearchController(
      chatId: widget.chatId,
      isMounted: () => mounted,
      messages: _deps.messages,
    );
    final incomingReply = widget.replyRequest;
    if (incomingReply != null) {
      _replyTo.value = incomingReply.message;
      _replySourceChatId = incomingReply.sourceChatId == widget.chatId
          ? null
          : incomingReply.sourceChatId;
    }
    final incomingForward = widget.forwardRequest;
    if (incomingForward != null) {
      _forwardRequest = incomingForward;
      _pendingForwards.value = incomingForward.messages;
    }
    _pushSub = _deps.api.pushStream
        .where(
          (p) =>
              p.opcode == Opcode.notifMark ||
              p.opcode == Opcode.notifTyping ||
              p.opcode == Opcode.notifMsgDelayed,
        )
        .listen(_onIncomingPush);
    _messageEventSub = _deps.chats.messageEvents
        .where((e) => e.chatId == widget.chatId)
        .listen(_onMessageEvent);
    if (_commentsMode) {
      _commentSub = _deps.comments.commentStream
          .where(
            (e) =>
                e.chatId == widget.chatId && e.postId == widget.commentPostId,
          )
          .listen(_onLiveComment);
    } else if (widget.chatType == 'CHANNEL') {
      _commentsInfoSub = _deps.comments.infoStream.listen(_onCommentsInfo);
    }
    ChatActivityStore.instance
        .listenable(widget.chatId)
        .addListener(_recomputeHeaderStatus);
    ChatMembersStore.instance
        .listenable(widget.chatId)
        .addListener(_recomputeHeaderStatus);
    _connSub = _deps.api.stateStream.listen((_) {
      if (mounted) _recomputeHeaderStatus();
    });
    debugForceOffline.addListener(_recomputeHeaderStatus);
    PresenceFetch.revision.addListener(_onPresenceChanged);
    ContactsModule.revision.addListener(_onContactsChanged);
    _floatingDateAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 380),
    );
    _floatingDateCurved = CurvedAnimation(
      parent: _floatingDateAnimController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _scrollDownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scrollDownCurved = CurvedAnimation(
      parent: _scrollDownAnimController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    unawaited(_fastPreloadCache());
    unawaited(_loadParticipantsCount());
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrameRendered);
  }

  @override
  void reloadAfterReconnect() {
    if (!_historyKickedOff) return;
    unawaited(_loadHistory());
    unawaited(_loadParticipantsCount());
  }

  Future<void> _loadParticipantsCount() async {
    if (_commentsMode) return;
    if (widget.chatType != 'CHAT' && widget.chatType != 'CHANNEL') return;
    final info = await _deps.chats.getChatInfo(_deps.api, widget.chatId);
    if (!mounted) return;
    if (widget.chatType == 'CHANNEL') {
      final link = info?['link'];
      if (link is String && link.isNotEmpty) _channelLink = link;
    }
  }

  Future<void> _loadPeerKind() async {
    if (widget.chatType != 'DIALOG' || _myId == 0) return;
    final peerId = widget.chatId ^ _myId;
    if (peerId <= 0) return;
    final cached = ContactInfoFetch.peek(peerId);
    if (cached != null) _applyPeerInfo(peerId, cached);
    final info = await ContactInfoFetch.get(peerId);
    if (info != null) _applyPeerInfo(peerId, info);
    if ((info ?? cached)?.isBot ?? false) {
      unawaited(BotInfoFetch.get(peerId));
    }
  }

  void _applyPeerInfo(int peerId, ContactInfo info) {
    if (!mounted) return;
    final avatar = info.avatarUrl;
    final avatarIsNew =
        avatar != null &&
        avatar.isNotEmpty &&
        ContactCache.getAvatar(peerId) != avatar;
    if (avatarIsNew) ContactCache.putAvatar(peerId, avatar);
    if (_peerIsBot == info.isBot && !avatarIsNew) return;
    setState(() => _peerIsBot = info.isBot);
  }


  @override
  void deactivate() {
    _saveDraft();
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_voiceRec.isRecording.value) {
        unawaited(_voiceRec.stop(cancel: true));
      }
      if (_note.isRecording.value) {
        unawaited(_note.stop(cancel: true));
      }
    }
    if (state != AppLifecycleState.resumed) _saveDraft();
    super.didChangeAppLifecycleState(state);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = View.of(context);
    final keyboardOpen = view.viewInsets.bottom / view.devicePixelRatio > 100;
    if (_keyboardWasOpen && !keyboardOpen && _messageFocusNode.hasFocus) {
      _messageFocusNode.unfocus();
    }
    _keyboardWasOpen = keyboardOpen;
  }

  @override
  void dispose() {
    ChatScreen._open.remove(this);
    if (!_commentsMode) {
      unawaited(NotificationBridge.instance.popActiveChat(widget.chatId));
    }
    _chatController.persistSessionCache();
    if (_previewChat) {
      unawaited(_deps.chats.subscribeChat(_deps.api, widget.chatId, subscribe: false));
    }
    WidgetsBinding.instance.removeObserver(this);
    _uploadEventSub?.cancel();
    _deps.chats.chatsChanged.removeListener(_onChatsBump);
    _otherUnread.dispose();
    _animojiHold.dispose();
    _saveDraft();
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScrollForDate);
    _scrollController.removeListener(_maybeLoadMoreHistory);
    _scrollController.removeListener(_recordScrollPixels);
    _scrollController.removeListener(_scheduleReadMarker);
    _scrollController.removeListener(_updateScrollDownVisible);
    _readMarker.dispose();
    AppVisualStyle.current.removeListener(_onVisualStyleChanged);
    MediaPlayback.instance.leaveChat(widget.chatId);
    AppChatChrome.current.removeListener(_onVisualStyleChanged);
    AppComposerStyle.current.removeListener(_onVisualStyleChanged);
    AppComposerBackground.current.removeListener(_onVisualStyleChanged);
    _composerHeight.dispose();
    _pinnedBannerHeight.dispose();
    _floatingDateTimer?.cancel();
    _floatingDateCurved.dispose();
    _floatingDateAnimController.dispose();
    _floatingDate.dispose();
    _scrollDownCurved.dispose();
    _scrollDownAnimController.dispose();
    _newMessageCount.dispose();
    _hasText.dispose();
    _scheduledCount.dispose();
    _showAttachmentPanel.removeListener(_onAttachPanelToggle);
    _showAttachmentPanel.dispose();
    _detachUploadStatus();
    _pushSub?.cancel();
    _messageEventSub?.cancel();
    _commentsInfoSub?.cancel();
    _commentSub?.cancel();
    _connSub?.cancel();
    _voiceRec.dispose();
    _note.dispose();
    debugForceOffline.removeListener(_recomputeHeaderStatus);
    for (final n in _reactionNotifiers.values) {
      n.dispose();
    }
    _reactionNotifiers.clear();
    _reactionAnimation.dispose();
    ChatActivityStore.instance
        .listenable(widget.chatId)
        .removeListener(_recomputeHeaderStatus);
    ChatMembersStore.instance
        .listenable(widget.chatId)
        .removeListener(_recomputeHeaderStatus);
    PresenceFetch.revision.removeListener(_onPresenceChanged);
    ContactsModule.revision.removeListener(_onContactsChanged);
    if (_wallpaperListening) {
      ChatWallpaperStore.instance.revision.removeListener(
        _applyEffectiveWallpaper,
      );
    }
    if (_encryptionListening) {
      ChatEncryptionStore.instance.revision.removeListener(_applyEncryption);
    }
    _headerStatusNotifier.dispose();
    _otherReadTime.dispose();
    _chatController.dispose();
    _prank.dispose();
    _uploadStatus.dispose();
    _attachAnim.dispose();
    _commandPanel.dispose();
    _mentionPanel.dispose();
    _selectionAnim.dispose();
    _searchAnim.dispose();
    _searchFocusNode.dispose();
    _search.dispose();
    _selectedIds.dispose();
    _textSelection.dispose();
    _textSelectionDrag.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _stickers.dispose();
    _scrollController.dispose();
    _shimmerStartTimer?.cancel();
    _shimmerController.dispose();
    _replyTo.dispose();
    _pendingForwards.dispose();
    _highlightTimer?.cancel();
    _highlightMessageId.dispose();
    _goToMessageSettleTimer?.cancel();
    _jumpCacheExtent.dispose();
    _routeSettle.dispose();
    _messageKeys.clear();
    super.dispose();
  }

  void _onTextChanged() {
    final newHasText = _messageController.text.trim().isNotEmpty;
    if (newHasText != _hasText.value) {
      _hasText.value = newHasText;
    }
    _commandPanel.update();
    _mentionPanel.update();
  }

  bool _mentionsAvailable() =>
      !_commentsMode && (chat?.type ?? widget.chatType) == 'CHAT';

  void _onMentionSelected(MentionCandidate candidate, MentionQuery query) {
    _messageController.insertMention(
      userId: candidate.id,
      name: candidate.name,
      start: query.start,
      end: query.end,
    );
    _mentionPanel.update();
    _messageFocusNode.requestFocus();
  }

  void _onCommandSelected(SlashCommand c) {
    final text = '${c.name} ';
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _messageFocusNode.requestFocus();
  }

  void _restoreDraft() {
    if (_myId == 0 || _commentsMode || _messageController.text.isNotEmpty) {
      return;
    }
    final shared = widget.initialText?.trim();
    final draft = (shared != null && shared.isNotEmpty)
        ? shared
        : DraftStore.instance.get(_myId, widget.chatId);
    if (draft == null || draft.isEmpty) return;
    _messageController.text = draft;
    _messageController.selection = TextSelection.collapsed(
      offset: draft.length,
    );
  }

  void _saveDraft() {
    if (_myId == 0 || _commentsMode) return;
    unawaited(
      DraftStore.instance.set(
        _myId,
        widget.chatId,
        _messageController.buildContent().text,
      ),
    );
  }

  void _onAttachPanelToggle() {
    if (_showAttachmentPanel.value) {
      _attachAnim.forward();
    } else {
      _attachAnim.reverse();
    }
  }

  int _computeOtherReadTime() {
    final c = chat;
    if (c == null) return 0;
    int otherReadTime = 0;
    for (final entry in c.participants.entries) {
      if (entry.key != _myId && entry.value > otherReadTime) {
        otherReadTime = entry.value;
      }
    }
    return otherReadTime;
  }

  void _syncOtherReadTime() {
    final t = _computeOtherReadTime();
    if (_otherReadTime.value != t) _otherReadTime.value = t;
  }

  String? _effectiveStatus(CachedMessage msg) {
    if (msg.senderId != _myId) return null;
    if (msg.status == 'sending' ||
        msg.status == 'pending' ||
        msg.status == 'error') {
      return msg.status;
    }
    return 'sent';
  }

  void _onIncomingPush(Packet packet) {
    if (!mounted) return;
    switch (packet.opcode) {
      case Opcode.notifMark:
        _onMessageRead(packet);
      case Opcode.notifTyping:
        _onTyping(packet);
      case Opcode.notifMsgDelayed:
        final p = packet.payload;
        if (p is Map && p['chatId'] == widget.chatId) {
          // lastDelayedUpdateTime — авторитетный признак от сервера:
          // 0 — отложенных в чате не осталось, иначе они есть. Реагируем
          // мгновенно по пушу, не дожидаясь повторного запроса.
          final t = p['lastDelayedUpdateTime'];
          if (t is int && t == 0) {
            _scheduledCount.value = 0;
          } else {
            if (_scheduledCount.value == 0) _scheduledCount.value = 1;
            _refreshScheduledCount();
          }
        }
    }
  }

  void _markHasScheduled() {
    if (_scheduledCount.value == 0) _scheduledCount.value = 1;
  }

  Future<void> _refreshScheduledCount() async {
    if (_myId == 0) return;
    try {
      final list = await _deps.messages.fetchDelayedMessages(
        _myId,
        widget.chatId,
      );
      if (mounted) _scheduledCount.value = list.length;
    } catch (_) {}
  }

  void _bumpMessages() {
    _combinedItemsCache = null;
    _messagesRev.value++;
  }


  void _onMessageEvent(MessageEvent event) {
    if (!mounted) return;
    if (_commentsMode) return;
    switch (event) {
      case MessageAddedEvent(:final message):
        if (message.senderId == _myId && !message.isControl) return;
        if (_messages.any((m) => m.id == message.id)) return;
        final nearBottom = _isNearBottom();
        if (!nearBottom) _deferredIds.add(message.id);
        _lastSentId = message.id;
        _messages.add(message);
        _bumpMessages();
        _clearTyping(message.senderId);
        Haptics.tap();
        if (nearBottom) {
          _scrollToBottom();
          _scheduleReadMarker();
        } else {
          _noteMissedMessage();
          _reapplyPinIfNeeded();
        }
        _prank.checkTrigger(message);
      case MessageEditedEvent(:final message):
        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx == -1) return;
        _messages[idx] = message;
        _bumpMessages();
      case MessageSentEvent(:final tempId, :final message):
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx == -1) return;
        _lastSentId = message.id;
        _messages[idx] = message;
        _bumpMessages();
      case MessageRemovedEvent(:final messageId):
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx == -1) return;
        _messages.removeAt(idx);
        _bumpMessages();
        _reactionNotifiers.remove(messageId)?.dispose();
      case MessageMarkedDeletedEvent(:final messageId):
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx == -1) return;
        if (_messages[idx].deleted) return;
        _messages[idx] = _messages[idx].copyWith(deleted: true);
        _bumpMessages();
      case MessageReactionsChangedEvent(:final messageId, :final reactionInfo):
        _reactionNotifiers[messageId]?.value = reactionInfo;
    }
  }

  Future<void> _loadOtherPresence() async {
    if (_myId == 0) return;
    final otherId = widget.chatId ^ _myId;
    if (otherId <= 0) return;
    if (PresenceFetch.live(otherId) != null) return;
    try {
      final entry = await PresenceFetch.get(otherId);
      if (!mounted || entry == null) return;
      PresenceFetch.apply(otherId, entry);
    } catch (_) {}
  }

  void _onPresenceChanged() {
    if (!mounted) return;
    final otherId = _resolveOtherId();
    if (otherId == null) return;
    final p = PresenceFetch.live(otherId);
    if (p == null) return;
    _otherStatus = (p['status'] as int?) ?? 0;
    _otherSeenTime = p['seen'] as int?;
    _recomputeHeaderStatus();
  }

  void _onVisualStyleChanged() {
    if (mounted) {
      setState(() {});
      _bumpMessages();
    }
  }

  void _onContactsChanged() {
    if (mounted) setState(() {});
  }

  String _headerAvatarUrl() {
    if (!_commentsMode && widget.chatType == 'DIALOG') {
      final otherId = _resolveOtherId();
      if (otherId != null) {
        final cached = ContactCache.getAvatar(otherId);
        if (cached != null && cached.isNotEmpty) return cached;
      }
    }
    return widget.imageUrl;
  }

  String _headerName() {
    if (_commentsMode) return AppLocalizations.of(context)!.commentsTitle;
    if (widget.chatType == 'DIALOG') {
      final otherId = _resolveOtherId();
      if (otherId != null) {
        final cached = ContactCache.get(otherId);
        if (cached != null && cached.isNotEmpty) return cached;
      }
    }
    return widget.name;
  }


  bool get _hasMiniApp {
    if (widget.chatType != 'DIALOG' || _commentsMode) return false;
    final peerId = _resolveOtherId();
    if (peerId == null) return false;
    if (hasMiniAppOption(ContactCache.getOptions(peerId))) return true;
    return hasMiniAppOption(chat?.options);
  }

  bool get _isPersonOrGroupThread {
    if (_commentsMode) return false;
    if (_peerIsBot) return false;
    final type = chat?.type ?? widget.chatType;
    return type == 'DIALOG' || type == 'CHAT' || type == 'GROUP';
  }

  Future<void> _openMiniApp() async {
    final peerId = _resolveOtherId();
    if (peerId == null) return;
    await openMiniApp(
      context,
      botId: peerId,
      chatId: widget.chatId,
      title: _headerName(),
    );
  }

  void _openChatMenu(BuildContext btnContext) {
    final box = btnContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchorRect = box.localToGlobal(Offset.zero) & box.size;
    showChatMenu(
      context: context,
      anchorRect: anchorRect,
      items: [
        if (_hasMiniApp)
          ChatMenuItem(
            icon: Symbols.apps,
            label: AppLocalizations.of(context)!.miniAppOpen,
            dividerAfter: true,
            onTap: () => unawaited(_openMiniApp()),
          ),
        ChatMenuItem(
          icon: (chat?.isMuted ?? false)
              ? Symbols.volume_off
              : Symbols.volume_up,
          label: (chat?.isMuted ?? false)
              ? 'Включить уведомления'
              : 'Отключить уведомления',
          dividerAfter: true,
          onTap: _toggleChatMute,
        ),
        ChatMenuItem(icon: Symbols.search, label: 'Поиск', onTap: _openSearch),
        ChatMenuItem(
          icon: Symbols.wallpaper,
          label: 'Изменить обои',
          onTap: _openWallpaperSheet,
        ),
        if (_isPersonOrGroupThread)
          ChatMenuItem(
            icon: Symbols.mop,
            label: 'Очистить историю',
            onTap: _clearHistory,
          ),
        if (_isPersonOrGroupThread)
          ChatMenuItem(
            icon: _encryptionEnabled ? Symbols.lock : Symbols.lock_open,
            label: 'Шифрование сообщений',
            onTap: _openEncryptionSettings,
          ),
        ChatMenuItem(
          icon: Symbols.delete,
          label: 'Удалить чат',
          onTap: _deleteChat,
        ),
      ],
    );
  }

  Future<void> _subscribeChannel() async {
    if (_subscribing) return;
    setState(() => _subscribing = true);
    try {
      var link = _channelLink;
      if (link == null || link.isEmpty) {
        final info = await _deps.chats.getChatInfo(_deps.api, widget.chatId);
        link = info?['link'] as String?;
      }
      if (link == null || link.isEmpty) {
        throw const PacketError('Не удалось получить ссылку канала');
      }
      final result = await _deps.chats.joinChannel(_deps.api, link, _myId);
      if (!mounted) return;
      setState(() {
        _previewChat = false;
        _subscribing = false;
        chat = result.chat;
      });
      ChatMembersStore.instance.setCount(
        widget.chatId,
        result.subscribersCount,
      );
      _recomputeHeaderStatus();
      showCustomNotification(context, 'Вы подписались на канал');
    } catch (e) {
      if (!mounted) return;
      setState(() => _subscribing = false);
      showCustomNotification(
        context,
        e is PacketError ? e.message : 'Не удалось подписаться',
      );
    }
  }

  Future<void> _toggleChatMute() async {
    final current = chat;
    if (current == null) return;
    final muted = current.isMuted;
    final target = muted ? ChatsModule.muteOff : ChatsModule.muteForever;
    final error = await _deps.chats.setChatMute(
      api,
      chatId: widget.chatId,
      dontDisturbUntil: target,
    );
    if (!mounted) return;
    if (error != null) {
      showCustomNotification(context, error);
      return;
    }
    setState(() => chat = current.copyWith(dontDisturbUntil: target));
    showCustomNotification(
      context,
      muted ? 'Уведомления включены' : 'Уведомления отключены',
    );
  }

  bool _encryptionListening = false;

  Future<void> _loadEncryption() async {
    await ChatEncryptionStore.instance.load();
    if (!mounted) return;
    if (!_encryptionListening) {
      _encryptionListening = true;
      ChatEncryptionStore.instance.revision.addListener(_applyEncryption);
    }
    _applyEncryption();
  }

  void _applyEncryption() {
    if (!mounted) return;
    final enabled = ChatEncryptionStore.instance.isEnabled(
      _myId,
      widget.chatId,
    );
    if (enabled != _encryptionEnabled) {
      setState(() => _encryptionEnabled = enabled);
    }
    if (enabled && _myId != 0) {
      unawaited(ChatCryptoService.instance.warmKey(_myId, widget.chatId));
    }
  }

  Future<void> _openEncryptionSettings() async {
    if (_myId == 0) return;
    await pushSwipeable(
      context,
      (context) =>
          ChatEncryptionScreen(accountId: _myId, chatId: widget.chatId),
    );
    if (!mounted) return;
    _applyEncryption();
  }

  bool _wallpaperListening = false;

  Future<void> _loadWallpaper() async {
    await ChatWallpaperStore.instance.load();
    if (!mounted) return;
    if (!_wallpaperListening) {
      _wallpaperListening = true;
      ChatWallpaperStore.instance.revision.addListener(
        _applyEffectiveWallpaper,
      );
    }
    _applyEffectiveWallpaper();
  }

  void _applyEffectiveWallpaper() {
    if (!mounted) return;
    final store = ChatWallpaperStore.instance;
    final wp =
        store.get(_myId, widget.chatId) ??
        store.get(_myId, kGlobalWallpaperChatId);
    if (!identical(wp, _wallpaper)) setState(() => _wallpaper = wp);
  }

  Future<void> _openWallpaperSheet() async {
    if (_myId == 0) return;
    final pick = await showChatWallpaperSheet(context, current: _wallpaper);
    if (pick == null || !mounted) return;
    final store = ChatWallpaperStore.instance;
    switch (pick.type) {
      case WallpaperPickType.none:
        await store.clear(_myId, widget.chatId);
        _applyEffectiveWallpaper();
        break;
      case WallpaperPickType.theme:
        final theme = pick.theme;
        if (theme == null) break;
        await store.setTheme(_myId, widget.chatId, theme.id);
        _applyEffectiveWallpaper();
        break;
      case WallpaperPickType.gallery:
        await _pickWallpaperFromGallery();
        break;
    }
  }

  Future<void> _pickWallpaperFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (mounted) showCustomNotification(context, 'Не удалось прочитать файл');
      return;
    }
    if (!mounted) return;
    final settings = await Navigator.of(context).push<WallpaperImageSettings>(
      MaterialPageRoute(
        builder: (_) => ChatWallpaperPreviewScreen(imageBytes: bytes),
      ),
    );
    if (settings == null || !mounted) return;
    final wp = await ChatWallpaperStore.instance.setImage(
      _myId,
      widget.chatId,
      bytes,
      settings: settings,
    );
    if (!mounted) return;
    if (wp == null) {
      showCustomNotification(context, 'Не удалось сохранить обои');
      return;
    }
    _applyEffectiveWallpaper();
  }

  Future<void> _clearHistory() async {
    final current = chat;
    final canClearForAll =
        (widget.chatType == 'CHAT' || widget.chatType == 'CHANNEL') &&
        (current?.iAmAdmin(_myId) ?? false);
    final choice = await showBlurredConfirm(
      context,
      title: 'Очистить историю',
      message:
          'Все сообщения в этом чате будут удалены без возможности '
          'восстановления.',
      confirmLabel: 'Очистить',
      cancelLabel: 'Отмена',
      destructive: true,
      checkboxLabel: canClearForAll ? 'Для всех' : null,
    );
    if (!mounted || !choice.confirmed) return;
    final err = await _deps.chats.clearHistory(
      api,
      chatId: widget.chatId,
      lastEventTime: current?.lastEventTime ?? 0,
      forAll: canClearForAll && choice.checked,
    );
    if (!mounted) return;
    if (err != null) {
      showCustomNotification(context, err);
      return;
    }
    setState(() {
      _messages = [];
      _deferredIds.clear();
      _hasMoreHistory = false;
      _combinedItemsCache = null;
    });
    _messagesRev.value++;
  }

  Future<void> _deleteChat() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить чат',
      message: 'Чат будет удалён вместе со всей перепиской.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    final err = await _deps.chats.deleteChat(
      api,
      chatId: widget.chatId,
      lastEventTime: chat?.lastEventTime ?? 0,
      forAll: false,
    );
    if (!mounted) return;
    if (err != null) {
      showCustomNotification(context, err);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _startCall() async {
    if (widget.chatType != 'DIALOG' || _peerIsBot) {
      showCustomNotification(context, 'Звонки доступны только в диалогах');
      return;
    }
    // Звонок уже идёт (возможно, свёрнут) — просто открываем его экран снова.
    final navigator = Navigator.of(context);
    final active = CallController.instance.activeSession;
    if (active != null) {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            name: widget.name,
            avatarUrl: widget.imageUrl.isNotEmpty ? widget.imageUrl : null,
            session: active,
          ),
        ),
      );
      _onCallScreenClosed();
      return;
    }
    final peerId = widget.chatId ^ _myId;
    if (peerId <= 0) return;
    try {
      final session = await CallController.instance.startOutgoing(peerId);
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            name: widget.name,
            avatarUrl: widget.imageUrl.isNotEmpty ? widget.imageUrl : null,
            session: session,
          ),
        ),
      );
      _onCallScreenClosed();
    } catch (_) {
      if (!mounted) return;
      showCustomNotification(context, 'Не удалось начать звонок');
    }
  }

  void _onCallScreenClosed() {
    if (!mounted) return;
    if (CallController.instance.activeSession != null) return;
    unawaited(_refreshAfterCall());
  }

  Future<void> _refreshAfterCall() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _myId == 0) return;
    try {
      final decoded = await _chatController.refreshLatest();
      if (mounted && decoded.isNotEmpty) _applyMergedMessages(decoded);
    } catch (e) {
      logger.w('Обновление после звонка не удалось: $e');
    }
  }

  void _seedPresenceFromChat() {
    if (_otherStatus != 0 || _otherSeenTime != null) return;
    final otherId = _resolveOtherId();
    if (otherId == null) return;
    final p = PresenceFetch.live(otherId);
    if (p == null) return;
    _otherStatus = (p['status'] as int?) ?? 0;
    _otherSeenTime = p['seen'] as int?;
  }

  void _recomputeHeaderStatus() {
    if (_commentsMode) {
      _headerStatusNotifier.value = '';
      return;
    }
    _headerStatusNotifier.value = _headerStatus();
  }

  int get _memberCount =>
      ChatMembersStore.instance.count(widget.chatId) ??
      chat?.participants.length ??
      0;

  bool get _isGroupChat =>
      widget.chatType == 'CHAT' || widget.chatType == 'CHANNEL';

  Future<void> _ensureChatRoles() async {
    await ChatInfoFetch.get(widget.chatId);
    if (mounted) setState(() {});
  }

  String? _senderRoleLabel(int senderId) {
    if (widget.chatType != 'CHAT') return null;
    final info = ChatInfoFetch.peek(widget.chatId);
    if (info == null) return null;
    final l10n = AppLocalizations.of(context)!;
    final label = info.roleLabel(
      senderId,
      owner: l10n.chatInfoRoleOwner,
      admin: l10n.chatInfoRoleAdmin,
    );
    if (label == null) return null;
    return label.toLowerCase();
  }

  String _headerStatus() {
    final conn = connectionStatusLabel(_deps.api.state);
    if (conn != null) return conn;
    final activity = ChatActivityStore.instance.snapshot(widget.chatId);
    if (activity != null) {
      return chatActivityLabel(activity, withNames: _isGroupChat);
    }
    if (widget.chatType == 'CHAT') {
      final count = _memberCount;
      return '$count участников';
    }
    if (widget.chatType == 'CHANNEL') {
      final count = _memberCount;
      return '$count подписчиков';
    }
    if (_otherStatus == 1) return 'В сети';
    if (_otherStatus == 2 || _otherStatus == 3) return 'Был(-а) недавно';
    final s = _otherSeenTime;
    if (s != null && s > 0) return formatLastSeen(s);
    return '';
  }

  void _onTyping(Packet packet) {
    final payload = packet.payload;
    if (payload is! Map) return;
    if (payload['chatId'] != widget.chatId) return;
    final userId = payload['userId'];
    if (userId is! int || userId == _myId) return;
    ChatActivityStore.instance.mark(
      widget.chatId,
      userId,
      chatActivityFromType(payload['type']),
    );
    unawaited(_ensureTypingName(userId));
  }

  Future<void> _ensureTypingName(int userId) async {
    if (!_isGroupChat) return;
    if (ContactCache.get(userId) != null) return;
    final resolved = await _deps.messages.ensureContactNames({userId});
    if (resolved && mounted) _recomputeHeaderStatus();
  }

  void _clearTyping(int userId) {
    ChatActivityStore.instance.clearUser(widget.chatId, userId);
  }

  void _onMessageRead(Packet packet) {
    final payload = packet.payload;
    if (payload is! Map) return;
    if (payload['chatId'] != widget.chatId) return;
    final userId = payload['userId'];
    if (userId is! int || userId == _myId) return;
    final mark = payload['mark'];
    if (mark is! int) return;
    if (payload['setAsUnread'] == true) return;
    final c = chat;
    if (c == null) return;
    if (c.participants[userId] == mark) return;
    c.participants[userId] = mark;
    _syncOtherReadTime();
  }

  static String _formatLabel(TextFormat format) {
    switch (format) {
      case TextFormat.heading:
        return 'Заголовок';
      case TextFormat.strong:
        return 'Жирный';
      case TextFormat.emphasized:
        return 'Курсив';
      case TextFormat.underline:
        return 'Подчёркнутый';
      case TextFormat.strikethrough:
        return 'Зачёркнутый';
      case TextFormat.monospaced:
        return 'Моноширинный';
      case TextFormat.quote:
        return 'Цитата';
      case TextFormat.link:
        return 'Ссылка';
      case TextFormat.animoji:
        return 'Animoji';
      case TextFormat.userMention:
        return 'Упоминание';
    }
  }

  Widget _formatContextMenu(
    RichMessageController controller,
    BuildContext context,
    EditableTextState editableState, {
    List<ContextMenuButtonItem> extraItems = const [],
  }) {
    final selection = controller.selection;
    final buttonItems = <ContextMenuButtonItem>[];
    if (selection.isValid && !selection.isCollapsed) {
      for (final format in composerFormats) {
        final active = controller.isFormatActive(format);
        buttonItems.add(
          ContextMenuButtonItem(
            label: '${active ? '✓ ' : ''}${_formatLabel(format)}',
            onPressed: () {
              controller.toggleFormat(format);
              editableState.hideToolbar();
            },
          ),
        );
      }
    }
    buttonItems.addAll(extraItems);
    buttonItems.addAll(editableState.contextMenuButtonItems);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  static bool _sameElements(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    String canon(List<Map<String, dynamic>> els) {
      final copy = [...els]
        ..sort((x, y) {
          final t = (x['type'] as String).compareTo(y['type'] as String);
          return t != 0 ? t : (x['from'] as int).compareTo(y['from'] as int);
        });
      return copy
          .map((e) => '${e['type']}:${e['from']}:${e['length']}')
          .join(',');
    }

    return canon(a) == canon(b);
  }

  List<Map<String, dynamic>> _trimmedElements(
    List<Map<String, dynamic>> raw,
    String rawText,
    String text,
  ) {
    if (raw.isEmpty) return const [];
    final leading = rawText.length - rawText.trimLeft().length;
    final result = <Map<String, dynamic>>[];
    for (final element in raw) {
      var from = (element['from'] as int) - leading;
      var length = element['length'] as int;
      if (from < 0) {
        length += from;
        from = 0;
      }
      if (from >= text.length || length <= 0) continue;
      if (from + length > text.length) length = text.length - from;
      if (length <= 0) continue;
      result.add({...element, 'from': from, 'length': length});
    }
    return result;
  }


  @override
  Widget build(BuildContext context) {
    final theme = _prank.active
        ? _prank.pinkTheme(Theme.of(context))
        : Theme.of(context);
    final cs = theme.colorScheme;
    final underlap = _effectiveChrome != ChatChromeStyle.color;

    // TODO: Локализация
    // TODO: Cклонения
    final mq = MediaQuery.of(context);
    final bottomInset = _keyboardReserve > 0
        ? math.max(mq.viewInsets.bottom, _keyboardReserve)
        : mq.viewInsets.bottom;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _selectedIds,
        _search.searchMode,
        _textSelection,
      ]),
      builder: (context, child) => PopScope(
        canPop:
            _selectedIds.value.isEmpty &&
            !_search.searchMode.value &&
            _textSelection.value == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_search.searchMode.value) {
            _closeSearch();
          } else if (_textSelection.value != null) {
            _exitTextSelection();
          } else {
            _clearSelection();
          }
        },
        child: child!,
      ),
      child: MediaQuery(
        data: mq.copyWith(
          viewInsets: mq.viewInsets.copyWith(bottom: bottomInset),
        ),
        child: Theme(
          data: theme,
          child: RepaintBoundary(
            key: _prank.captureKey,
            child: ValueListenableBuilder<bool>(
              valueListenable: AppSwipeBackDesktop.current,
              builder: (context, desktopSwipe, child) => SwipeToPop(
                enabled: widget.embedded && desktopSwipe,
                onPop: widget.onClose,
                child: child!,
              ),
              child: AnimatedBuilder(
                animation: _searchAnim,
                child: LottieHoldScope(
                  isHeld: _animojiHold,
                  child: underlap ? _buildUnderlapBody() : _buildColorBody(),
                ),
                builder: (context, body) => Scaffold(
                  backgroundColor: underlap ? Colors.transparent : cs.surface,
                  extendBodyBehindAppBar: underlap,
                  appBar: _buildAppBar(cs),
                  body: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessageList extends StatefulWidget {
  final _ChatScreenState host;
  const _ChatMessageList(this.host, {super.key});

  @override
  State<_ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<_ChatMessageList> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.host._messagesRev,
      builder: (context, _, _) => widget.host._buildMessagesListContent(),
    );
  }
}
