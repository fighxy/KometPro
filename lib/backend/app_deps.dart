import 'api.dart';
import 'modules/account.dart';
import 'modules/animoji.dart';
import 'modules/chats.dart';
import 'modules/comments.dart';
import 'modules/digital_id.dart';
import 'modules/file_uploader.dart';
import 'modules/messages.dart';
import 'modules/polls.dart';
import 'modules/shared_content.dart';
import 'modules/stickers.dart';
import 'modules/stories.dart';
import 'modules/webapp.dart';

class AppDeps {
  AppDeps({
    required this.api,
    required this.account,
    required this.messages,
    required this.comments,
    required this.sharedContent,
    required this.polls,
    required this.stickers,
    required this.animoji,
    required this.webApp,
    required this.digitalId,
    required this.fileUploader,
    required this.stories,
    required this.chats,
  });

  final Api api;
  final AccountModule account;
  final MessagesModule messages;
  final CommentsModule comments;
  final SharedContentModule sharedContent;
  final PollsModule polls;
  final StickersModule stickers;
  final AnimojiModule animoji;
  final WebAppModule webApp;
  final DigitalIdModule digitalId;
  final FileUploader fileUploader;
  final StoriesModule stories;
  final ChatsModule chats;

  static AppDeps? _shared;

  static AppDeps get shared {
    final bound = _shared;
    if (bound == null) {
      throw StateError('AppDeps.bind was not called');
    }
    return bound;
  }

  static void bind(AppDeps deps) {
    _shared = deps;
  }
}
