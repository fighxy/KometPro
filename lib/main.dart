import 'dart:async';

import 'core/config/desktop_density_mode.dart';
import 'dart:ui' as ui;

import 'package:kolibri/kolibri.dart' show initKolibri;
import 'package:flutter/material.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend/api.dart';
import 'backend/app_deps.dart';
import 'core/cache/info_cache.dart';
import 'core/config/build_profile.dart';
import 'core/utils/logger.dart';
import 'core/cache/self_presence.dart';
import 'core/storage/app_instance.dart';
import 'core/storage/draft_store.dart';
import 'core/storage/archived_chats_store.dart';
import 'core/storage/chat_encryption_store.dart';
import 'core/config/app_accent.dart';
import 'core/config/app_amoled.dart';
import 'core/config/app_show_extra_info.dart';
import 'core/config/app_spectrum_background.dart';
import 'core/config/app_bubble_behavior.dart';
import 'core/config/komet_settings.dart';
import 'core/config/call_no_mute.dart';
import 'core/config/debug_test.dart';
import 'core/config/app_bubble_shape.dart';
import 'core/config/app_cache_extent.dart';
import 'core/config/app_fonts.dart';
import 'core/config/desktop_ui_scale.dart';
import 'core/config/custom_font_service.dart';
import 'core/config/app_message_actions_style.dart';
import 'core/config/app_microphone.dart';
import 'core/config/app_swipe_back_desktop.dart';
import 'core/config/app_pranks.dart';
import 'core/config/app_stories.dart';
import 'core/config/app_commands.dart';
import 'core/config/app_phonebook_names.dart';
import 'core/contacts/device_contacts_service.dart';
import 'core/config/app_link_preview.dart';
import 'core/config/app_media_cache.dart';
import 'core/config/app_video_note_quality.dart';
import 'core/config/app_pill_gradient.dart';
import 'core/config/app_visual_style.dart';
import 'core/config/app_chat_chrome.dart';
import 'core/config/app_composer_background.dart';
import 'core/config/app_composer_style.dart';
import 'core/config/app_nav_pill_style.dart';
import 'core/config/app_wallpaper_tint.dart';
import 'core/config/app_theme_mode.dart';
import 'core/config/app_theme_schedule.dart';
import 'core/config/app_digital_id_mode.dart';
import 'backend/modules/account.dart';
import 'backend/modules/chats.dart';
import 'backend/modules/comments.dart';
import 'backend/modules/contacts.dart';
import 'backend/modules/file_uploader.dart';
import 'backend/modules/folders.dart';
import 'backend/modules/messages.dart';
import 'backend/modules/polls.dart';
import 'backend/modules/stickers.dart';
import 'backend/modules/animoji.dart';
import 'backend/modules/stories.dart';
import 'backend/modules/shared_content.dart';
import 'backend/modules/webapp.dart';
import 'backend/modules/digital_id.dart';
import 'core/links/deep_link_service.dart';
import 'core/push/fkm_controller.dart';
import 'core/push/windows_notifier.dart';
import 'core/desktop/desktop_tray.dart';
import 'core/storage/app_database.dart';
import 'core/transport/tls_config.dart';
import 'core/transport/traffic_monitor.dart';
import 'core/transport/vpn_bypass.dart';
import 'core/storage/token_storage.dart';
import 'core/utils/haptics.dart';
import 'core/utils/debug_session_log.dart';
import 'frontend/widgets/liquid_glass.dart';
import 'frontend/komet_app.dart';

final api = Api();
final accountModule = AccountModule(api);
final messagesModule = MessagesModule(api);
final commentsModule = CommentsModule(api);
final sharedContentModule = SharedContentModule(api);
final pollsModule = PollsModule(api);
final stickersModule = StickersModule(api);
final animojiModule = AnimojiModule(api);
final webAppModule = WebAppModule(api);
final digitalIdModule = DigitalIdModule(webAppModule);
final fileUploader = FileUploader(api: api, messages: messagesModule);
final storiesModule = StoriesModule(api);
final bannersModule = accountModule.banners;
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

final AppDeps appDeps = AppDeps(
  api: api,
  account: accountModule,
  messages: messagesModule,
  comments: commentsModule,
  sharedContent: sharedContentModule,
  polls: pollsModule,
  stickers: stickersModule,
  animoji: animojiModule,
  webApp: webAppModule,
  digitalId: digitalIdModule,
  fileUploader: fileUploader,
  stories: storiesModule,
  chats: chats,
  banners: bannersModule,
  routes: appRouteObserver,
);

Future<Locale> _loadInitialLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString('app_locale');
  if (code != null && (code == 'en' || code == 'ru')) {
    return Locale(code);
  }
  final platform = WidgetsBinding.instance.platformDispatcher.locale;
  if (platform.languageCode == 'en' || platform.languageCode == 'ru') {
    return Locale(platform.languageCode);
  }
  return const Locale('ru');
}

void _installLogCapture() {
  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      final t = DateTime.now();
      final stamp =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}.${t.millisecond.toString().padLeft(3, '0')}';
      DebugSessionLog.instance.recordLogLine('  |$stamp P $message');
    }
    previousDebugPrint(message, wrapWidth: wrapWidth);
  };

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    DebugSessionLog.instance.recordLogLine(
      '  |         FlutterError: ${details.exceptionAsString()}',
    );
    if (details.stack != null) {
      DebugSessionLog.instance.recordLogLine(details.stack.toString());
    }
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformOnError = ui.PlatformDispatcher.instance.onError;
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    DebugSessionLog.instance.recordLogLine('  |         Uncaught: $error');
    DebugSessionLog.instance.recordLogLine(stack.toString());
    if (previousPlatformOnError != null) {
      return previousPlatformOnError(error, stack);
    }
    return false;
  };
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDeps.bind(appDeps);
  await initKolibri();
  DebugTest.parse(args);
  CallNoMute.parse(args);
  _installLogCapture();
  VideoPlayerMediaKit.ensureInitialized(
    windows: true,
    linux: true,
    macOS: true,
  );
  if (AppInstance.isNamed) {
    SharedPreferences.setPrefix('flutter.${AppInstance.id}.');
  }
  await TlsConfig.applyMincifryTrust();
  await AppDatabase.init();
  final activeAccountId = await TokenStorage.getActiveAccountId();
  if (activeAccountId != null) {
    await ContactsModule.primeCacheFromDb(activeAccountId);
  }
  attachInfoCacheApi(api);
  chats.attachGlobalPushHandlers(api);
  unawaited(FkmController.instance.init(api));
  unawaited(WindowsNotifier.instance.init(api));
  FoldersModule.attachGlobalPushHandlers(api);
  TranscriptionPushHandler.attach(api);
  commentsModule.attachPushHandlers(api);
  storiesModule.attach();
  unawaited(storiesModule.loadCache());
  unawaited(DeepLinkService.instance.init());

  final packageInfoFuture = PackageInfo.fromPlatform();
  final localeFuture = _loadInitialLocale();
  final hapticsFuture = Haptics.load();
  final prefsFuture = SharedPreferences.getInstance();
  final accentFuture = AppAccent.load();
  final bubbleShapeFuture = AppBubbleShape.load();
  final bubbleBehaviorFuture = AppBubbleBehavior.load();
  final cacheExtentFuture = AppCacheExtent.load();
  final themeModeFuture = AppThemeModeConfig.load();
  final amoledFuture = AppAmoled.load();
  final pillGradientFuture = AppPillGradient.load();
  final visualStyleFuture = AppVisualStyle.load();
  final liquidGlassFuture = LiquidGlass.load();
  final chatChromeFuture = AppChatChrome.load();
  final composerStyleFuture = AppComposerStyle.load();
  final composerBackgroundFuture = AppComposerBackground.load();
  final navPillStyleFuture = AppNavPillStyle.load();
  final wallpaperTintFuture = AppWallpaperTint.load();
  final themeScheduleFuture = AppThemeSchedule.load();
  final messageActionsFuture = AppMessageActionsStyle.load();
  final swipeBackFuture = AppSwipeBackDesktop.load();
  final microphoneFuture = AppMicrophone.load();
  final pranksFuture = AppPranks.load();
  final storiesFuture = AppStories.load();
  final commandsFuture = AppCommands.load();
  final phonebookNamesFuture = AppPhonebookNames.load();
  final linkPreviewFuture = AppLinkPreview.load();
  final cacheLimitFuture = AppMediaCacheLimit.load();
  final videoNoteResolutionFuture = AppVideoNoteResolution.load();
  final videoNoteFpsFuture = AppVideoNoteFps.load();
  final videoNoteRearCameraFuture = AppVideoNoteRearCamera.load();
  final digitalIdNativeFuture = AppDigitalIdNative.load();
  final showExtraInfoFuture = AppShowExtraInfo.load();
  final spectrumBackgroundFuture = AppSpectrumBackground.load();
  final trafficCaptureFuture = TrafficMonitor.instance.load();
  final debugLogFuture = DebugSessionLog.instance.init();

  await packageInfoFuture;

  final initialLocale = await localeFuture;

  await hapticsFuture;

  final prefs = await prefsFuture;
  await FileHistoryCache.load(prefs);
  await DraftStore.instance.load();
  await ArchivedChatsStore.instance.load();
  await ChatEncryptionStore.instance.load();
  await KometSettings.load();
  await DesktopUiScale.load();
  await AppDesktopDensity.load();
  if (KometSettings.ghostMode.value) SelfPresence.markOffline();
  await ContactCache.load();
  final initialFpsOverlay = prefs.getBool('dev_fps_overlay') ?? false;
  final initialVpnBypass =
      BuildProfile.insecureTransport &&
      (prefs.getBool(VpnBypassService.prefKey) ?? false);
  final initialTlsInsecure =
      BuildProfile.insecureTransport &&
      (prefs.getBool(TlsConfig.prefKey) ?? false);
  final initialFontId =
      prefs.getString(AppFonts.prefKey) ?? AppFonts.fallback.id;
  final initialFontScale = AppFonts.clampScale(
    prefs.getDouble(AppFonts.scalePrefKey) ?? AppFonts.defaultScale,
  );
  if (AppFonts.resolve(initialFontId).isCustom) {
    await CustomFontService.preloadCached();
  } else {
    unawaited(CustomFontService.preloadCached());
  }
  final initialAccentSeed = await accentFuture;
  await Future.wait<dynamic>([
    bubbleShapeFuture,
    bubbleBehaviorFuture,
    cacheExtentFuture,
    themeModeFuture,
    amoledFuture,
    pillGradientFuture,
    visualStyleFuture,
    liquidGlassFuture,
    chatChromeFuture,
    composerStyleFuture,
    composerBackgroundFuture,
    navPillStyleFuture,
    wallpaperTintFuture,
    themeScheduleFuture,
    messageActionsFuture,
    swipeBackFuture,
    microphoneFuture,
    pranksFuture,
    storiesFuture,
    commandsFuture,
    phonebookNamesFuture,
    linkPreviewFuture,
    cacheLimitFuture,
    videoNoteResolutionFuture,
    videoNoteFpsFuture,
    videoNoteRearCameraFuture,
    digitalIdNativeFuture,
    showExtraInfoFuture,
    spectrumBackgroundFuture,
  ]);
  await DeviceContactsService.loadFromStartup();
  await trafficCaptureFuture;
  await debugLogFuture;
  await DesktopTray.instance.init();
  runApp(
    KometApp(
      initialLocale: initialLocale,
      initialFpsOverlay: initialFpsOverlay,
      initialVpnBypass: initialVpnBypass,
      initialTlsInsecure: initialTlsInsecure,
      initialFontId: initialFontId,
      initialFontScale: initialFontScale,
      initialAccentSeed: initialAccentSeed,
    ),
  );
}

