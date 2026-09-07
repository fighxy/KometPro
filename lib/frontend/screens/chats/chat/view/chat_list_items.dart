import 'package:flutter/widgets.dart';
import 'package:komet/backend/modules/messages.dart';

class DateSeparatorItem {
  final DateTime date;
  final GlobalKey key;
  DateSeparatorItem(this.date, this.key);
}

class ChatListMessageItem {
  final CachedMessage message;
  final int index;
  const ChatListMessageItem(this.message, this.index);
}

class UnreadSeparatorItem {
  const UnreadSeparatorItem();
}
