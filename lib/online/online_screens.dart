import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/game.dart';
import '../game/table_screen.dart';
import '../settings/app_settings.dart';
import '../settings/profile_dialog.dart';
import '../theme/tokens.dart';
import '../ui/dice.dart';
import '../ui/strings.dart';
import 'online_room.dart';
import 'room_chat_view.dart';
import 'room_transport.dart';

/// Where an online game begins: create a room, or join one by its code.
class OnlineHomeScreen extends StatefulWidget {
  const OnlineHomeScreen({
    super.key,
    required this.settings,
    required this.transports,
  });

  final AppSettings settings;
  final TransportFactory? transports;

  @override
  State<OnlineHomeScreen> createState() => _OnlineHomeScreenState();
}

class _OnlineHomeScreenState extends State<OnlineHomeScreen> {
  final _code = TextEditingController();

  AppSettings get _settings => widget.settings;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _enter({String? code}) async {
    final transports = widget.transports;
    if (transports == null) return;
    final transport = transports(_settings.deviceId);
    final room = code == null
        ? HostRoom(
            transport: transport,
            code: newRoomCode(),
            name: _settings.playerName,
            color: _settings.diceColor,
            botLevel: _settings.botLevel,
          )
        : GuestRoom(
            transport: transport,
            code: code,
            name: _settings.playerName,
            color: _settings.diceColor,
          );
    unawaited(room.open());
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => RoomScreen(room: room, settings: _settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _code.text.trim().toUpperCase();
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.playOnline)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Tokens.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: widget.transports == null
                  ? const Text(
                      Strings.onlineNotConfigured,
                      key: Key('online-unavailable'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Tokens.mutedText, fontSize: 17),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          Strings.onlineIntro,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Tokens.mutedText,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: Tokens.space6),
                        FilledButton(
                          key: const Key('online-create'),
                          onPressed: _enter,
                          child: const Text(Strings.onlineCreate),
                        ),
                        const SizedBox(height: Tokens.space6),
                        TextField(
                          key: const Key('online-code'),
                          controller: _code,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            fontSize: 28,
                            letterSpacing: 10,
                            fontWeight: FontWeight.w800,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[a-zA-Z]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: Strings.onlineCodeLabel,
                            hintText: Strings.onlineCodeHint,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: Tokens.space3),
                        FilledButton.tonal(
                          key: const Key('online-join'),
                          onPressed: code.length == 4
                              ? () => _enter(code: code)
                              : null,
                          child: const Text(Strings.onlineJoin),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A room, from the wait for players to the table. Leaving the screen
/// leaves the room.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.room, required this.settings});

  final OnlineRoom room;
  final AppSettings settings;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  OnlineRoom get _room => widget.room;

  @override
  void initState() {
    super.initState();
    _room.addListener(_rebuild);
  }

  @override
  void dispose() {
    _room.removeListener(_rebuild);
    _room.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Once dealt, the table stays up even if the host then closes the room.
    if (_room.snapshot.value != null && _room.status != RoomStatus.refused) {
      return TableScreen(feed: _room, settings: widget.settings, room: _room);
    }
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.onlineRoomTitle)),
      body: SafeArea(
        child: switch (_room.status) {
          RoomStatus.connecting => const _Message(
            Strings.onlineConnecting,
            busy: true,
          ),
          RoomStatus.refused => _Message(
            Strings.onlineRefused(_room.refusal ?? 'unknown'),
          ),
          RoomStatus.closed => const _Message(Strings.onlineClosed),
          RoomStatus.lobby || RoomStatus.playing => _lobby(_room.lobby!),
        },
      ),
    );
  }

  Widget _lobby(Lobby lobby) {
    final room = _room;
    final self = lobby.players.firstWhere(
      (player) => player.id == room.selfId,
      orElse: () => lobby.players.first,
    );
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space3),
      children: [
        Center(
          child: InkWell(
            key: const Key('online-room-code'),
            borderRadius: BorderRadius.circular(Tokens.radiusButton),
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text(Strings.onlineCodeCopied)),
                );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                room.code,
                style: const TextStyle(
                  color: Tokens.gold,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                ),
              ),
            ),
          ),
        ),
        const Text(
          Strings.onlineShareCode,
          textAlign: TextAlign.center,
          style: TextStyle(color: Tokens.mutedText, fontSize: 15),
        ),
        const SizedBox(height: Tokens.space3),
        for (final (index, player) in lobby.players.indexed)
          ListTile(
            key: Key('online-player-${player.id}'),
            dense: true,
            leading: DieView(
              face: 5,
              color: Tokens.dice(player.color),
              size: 30,
            ),
            title: Text(
              player.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            trailing: Text(
              [
                if (index == 0) Strings.onlineHostTag,
                if (player.id == room.selfId) Strings.you,
              ].join(' · '),
              style: const TextStyle(color: Tokens.mutedText),
            ),
          ),
        for (var bot = 0; bot < lobby.bots; bot++)
          const ListTile(
            dense: true,
            leading: Icon(Icons.smart_toy_outlined, size: 30),
            title: Text('Bot', style: TextStyle(fontSize: 17)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space4,
            vertical: Tokens.space2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(Strings.onlinePickColor),
              const SizedBox(height: Tokens.space1),
              DiceColorPicker(
                selected: self.color,
                taken: lobby.takenColors,
                onPick: room.pickColor,
              ),
            ],
          ),
        ),
        if (room is HostRoom)
          ..._hostControls(room, lobby)
        else
          const Padding(
            padding: EdgeInsets.all(Tokens.space4),
            child: Text(
              Strings.onlineWaitingHost,
              key: Key('online-waiting-host'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Tokens.mutedText, fontSize: 16),
            ),
          ),
        LobbyChat(chat: room.chat, fromName: room.chat.selfName),
      ],
    );
  }

  List<Widget> _hostControls(HostRoom room, Lobby lobby) => [
    ListTile(
      title: const Text(Strings.onlineBots),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('online-bots-minus'),
            onPressed: lobby.bots > 0
                ? () => room.setBots(lobby.bots - 1)
                : null,
            icon: const Icon(Icons.remove),
          ),
          Text(
            '${lobby.bots}',
            key: const Key('online-bots'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          IconButton(
            key: const Key('online-bots-plus'),
            onPressed: lobby.bots < room.maxBots
                ? () => room.setBots(lobby.bots + 1)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    ),
    ListTile(
      title: const Text(Strings.diceCount),
      subtitle: const Text(Strings.diceCountNote),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('online-dice-minus'),
            onPressed: lobby.dice > GameOptions.minDice
                ? () => room.setDice(lobby.dice - 1)
                : null,
            icon: const Icon(Icons.remove),
          ),
          Text(
            '${lobby.dice}',
            key: const Key('online-dice'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          IconButton(
            key: const Key('online-dice-plus'),
            onPressed: lobby.dice < GameOptions.maxDice
                ? () => room.setDice(lobby.dice + 1)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    ),
    SwitchListTile(
      key: const Key('online-calza'),
      title: const Text(Strings.calzaOption),
      value: lobby.calza,
      onChanged: room.setCalza,
    ),
    Padding(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const Key('online-start'),
            onPressed: room.canStart ? room.start : null,
            child: const Text(Strings.start),
          ),
          if (!room.canStart)
            const Padding(
              padding: EdgeInsets.only(top: Tokens.space2),
              child: Text(
                Strings.onlineNeedPlayers,
                textAlign: TextAlign.center,
                style: TextStyle(color: Tokens.mutedText),
              ),
            ),
        ],
      ),
    ),
  ];
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.busy = false});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Tokens.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: Tokens.space4),
          ],
          Text(
            text,
            key: const Key('online-message'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Tokens.text, fontSize: 18),
          ),
        ],
      ),
    ),
  );
}
