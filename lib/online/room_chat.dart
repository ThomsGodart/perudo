import 'dart:async';

import 'package:flutter/foundation.dart';

import 'room_transport.dart';

/// One line of the in-game chat.
final class ChatLine {
  const ChatLine({
    required this.fromId,
    required this.fromName,
    required this.text,
    required this.at,
  });

  final String fromId;
  final String fromName;
  final String text;
  final DateTime at;
}

/// A face someone pulled at the table, for everyone to see for a moment.
final class Reaction {
  const Reaction({
    required this.fromId,
    required this.fromName,
    required this.emoji,
  });

  final String fromId;
  final String fromName;
  final String emoji;
}

/// A small chat shared by everyone in an online room.
class RoomChat extends ChangeNotifier {
  RoomChat({
    required this.transport,
    required this.selfId,
    this.selfName = '',
  }) {
    _subscription = transport.messages.listen(_onMessage);
  }

  final RoomTransport transport;
  final String selfId;
  String selfName;

  /// The faces and signs that can be shown at the table as a reaction, or
  /// slipped into a message. As a reaction, anything else a phone sends is
  /// dropped.
  static const emojis = [
    // Hands: well played, badly played, thanks, hello, deal.
    '👍', '👎', '👏', '🙏', '👋', '🤝',
    // Faces: glad, laughing, innocent, smug, thinking, shocked, sad, angry.
    '😄', '😂', '😇', '😎', '🤔', '😱', '😢', '😡',
    // The game: luck, a hot hand, sunk, the dice, a win, cheers.
    '🍀', '🔥', '💀', '🎲', '🎉', '🍻',
  ];

  final _reactions = StreamController<Reaction>.broadcast();

  /// Each reaction as it happens, this phone's own included.
  Stream<Reaction> get reactions => _reactions.stream;

  final List<ChatLine> _lines = [];
  int _unread = 0;
  bool _open = false;
  StreamSubscription<RoomMessage>? _subscription;

  List<ChatLine> get lines => List.unmodifiable(_lines);
  int get unread => _unread;

  void markOpen(bool open) {
    _open = open;
    if (open && _unread != 0) {
      _unread = 0;
      notifyListeners();
    }
  }

  void send(String text, {required String fromName}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final line = ChatLine(
      fromId: selfId,
      fromName: fromName,
      text: trimmed,
      at: DateTime.now(),
    );
    _lines.add(line);
    transport.send({'type': 'chat', 'name': fromName, 'text': trimmed});
    notifyListeners();
  }

  /// Shows [emoji] to everyone at the table, this phone included.
  void react(String emoji, {required String fromName}) {
    if (!emojis.contains(emoji)) return;
    transport.send({'type': 'reaction', 'name': fromName, 'emoji': emoji});
    _reactions.add(Reaction(fromId: selfId, fromName: fromName, emoji: emoji));
  }

  void _onMessage(RoomMessage message) {
    final payload = message.payload;
    if (payload['type'] == 'reaction') {
      final emoji = payload['emoji'];
      if (emoji is! String || !emojis.contains(emoji)) return;
      _reactions.add(
        Reaction(
          fromId: message.from,
          fromName: payload['name'] as String? ?? '?',
          emoji: emoji,
        ),
      );
      return;
    }
    if (payload['type'] != 'chat') return;
    final text = (payload['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return;
    _lines.add(
      ChatLine(
        fromId: message.from,
        fromName: payload['name'] as String? ?? '?',
        text: text,
        at: DateTime.now(),
      ),
    );
    if (!_open) _unread++;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reactions.close();
    super.dispose();
  }
}
