import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/strings.dart';
import 'room_chat.dart';

/// The lines of a room's chat, resting on the last one: when it shows, and
/// each time a message comes.
class ChatLines extends StatelessWidget {
  const ChatLines({super.key, required this.chat});

  final RoomChat chat;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: chat,
    builder: (context, _) {
      final lines = chat.lines;
      if (lines.isEmpty) {
        return const Center(
          child: Text(
            Strings.chatEmpty,
            style: TextStyle(color: Tokens.mutedText, fontSize: 16),
          ),
        );
      }
      // Upside down: the view rests on the last message.
      return ListView.builder(
        key: const Key('chat-lines'),
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space3),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[lines.length - 1 - index];
          return Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.fromName,
                  style: const TextStyle(
                    color: Tokens.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line.text,
                  style: const TextStyle(
                    color: Tokens.text,
                    fontSize: 17,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Where a message is written and sent to the room, under [fromName].
class ChatInput extends StatefulWidget {
  const ChatInput({super.key, required this.chat, required this.fromName});

  final RoomChat chat;
  final String fromName;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _input = TextEditingController();

  void _send() {
    widget.chat.send(_input.text, fromName: widget.fromName);
    _input.clear();
  }

  /// Slips [emoji] into the message where the cursor is, or at its end.
  void _insert(String emoji) {
    final text = _input.text;
    final selection = _input.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    _input.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // One line of emojis to slip into the message, scrolled sideways.
      SingleChildScrollView(
        key: const Key('chat-emojis'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space2),
        child: Row(
          children: [
            for (final emoji in RoomChat.emojis)
              InkWell(
                key: Key('chat-emoji-$emoji'),
                borderRadius: BorderRadius.circular(Tokens.radiusButton),
                onTap: () => _insert(emoji),
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space2),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space3,
          0,
          Tokens.space2,
          Tokens.space3,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('chat-input'),
                controller: _input,
                style: const TextStyle(fontSize: 17),
                decoration: const InputDecoration(hintText: Strings.chatHint),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              key: const Key('chat-send'),
              onPressed: _send,
              icon: const Icon(Icons.send),
              tooltip: Strings.chatSend,
            ),
          ],
        ),
      ),
    ],
  );
}

/// The room's chat laid out in the waiting room itself, for whoever waits:
/// the last messages and the field to answer, with nothing to open.
class LobbyChat extends StatelessWidget {
  const LobbyChat({super.key, required this.chat, required this.fromName});

  final RoomChat chat;
  final String fromName;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('lobby-chat'),
    margin: const EdgeInsets.fromLTRB(
      Tokens.space4,
      0,
      Tokens.space4,
      Tokens.space4,
    ),
    decoration: BoxDecoration(
      color: Tokens.panel,
      borderRadius: BorderRadius.circular(Tokens.radiusButton),
      border: Border.all(color: Tokens.outline),
    ),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(Tokens.space3),
          child: Text(
            Strings.chatTitle,
            style: TextStyle(
              color: Tokens.gold,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(height: 170, child: ChatLines(chat: chat)),
        ChatInput(chat: chat, fromName: fromName),
      ],
    ),
  );
}
