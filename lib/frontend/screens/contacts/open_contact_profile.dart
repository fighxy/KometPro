import 'package:flutter/material.dart';

import '../../../core/config/desktop_density.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../chats/chat_info_screen.dart';

Future<void> openContactDialogProfile(
  BuildContext context, {
  required int contactId,
  required String name,
  String? avatarUrl,
}) async {
  final accountId = await TokenStorage.getActiveAccountId();
  final existing = accountId == null
      ? null
      : await AppDatabase.findDialogChatByParticipant(accountId, contactId);
  final chatId = existing ?? ((accountId ?? 0) ^ contactId);
  if (!context.mounted) return;
  if (DesktopDensity.enabled) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: DesktopDensity.infoPaneWidth,
          height: MediaQuery.sizeOf(dialogContext).height * 0.86,
          child: ChatInfoScreen(
            chatId: chatId,
            name: name,
            imageUrl: avatarUrl ?? '',
            chatType: 'DIALOG',
            dialogPeerId: contactId,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatInfoScreen(
        chatId: chatId,
        name: name,
        imageUrl: avatarUrl ?? '',
        chatType: 'DIALOG',
        dialogPeerId: contactId,
      ),
    ),
  );
}
