import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../bots/bot.dart';
import '../engine/engine.dart';
import '../game/table.dart';
import '../theme/tokens.dart';
import 'room_chat.dart';
import 'room_transport.dart';

/// Bumped whenever phones of different versions could no longer play the
/// same game together.
const protocolVersion = 1;

/// How often each phone says it is still there, and what it last received.
const heartbeat = Duration(seconds: 3);

/// How many heartbeats a phone may miss before it is taken to be gone.
/// Counted in beats rather than on the clock: a phone whose app was asleep
/// has not been waiting for anyone.
const missedBeats = 4;

int? _int(Object? value) => value is num ? value.toInt() : null;

/// Someone in a room.
final class RoomPlayer {
  const RoomPlayer({required this.id, required this.name, required this.color});

  final String id;
  final String name;

  /// An index into the dice colours, unlike anyone else's in the room.
  final int color;

  Json toJson() => {'id': id, 'name': name, 'color': color};

  static RoomPlayer fromJson(Map<Object?, Object?> json) => RoomPlayer(
    id: json['id'] as String,
    name: json['name'] as String? ?? '?',
    color: _int(json['color']) ?? 0,
  );
}

/// What everyone in a room knows before the game starts.
final class Lobby {
  const Lobby({
    required this.players,
    required this.bots,
    required this.dice,
    required this.calza,
  });

  /// The host first, then the guests in the order they came.
  final List<RoomPlayer> players;

  /// How many bots will fill the table.
  final int bots;

  /// How many dice everyone will start with.
  final int dice;
  final bool calza;

  Set<int> get takenColors => {for (final player in players) player.color};

  Json toJson() => {
    'players': [for (final player in players) player.toJson()],
    'bots': bots,
    'dice': dice,
    'calza': calza,
  };

  static Lobby fromJson(Map<Object?, Object?> json) => Lobby(
    players: [
      for (final player in json['players'] as List)
        RoomPlayer.fromJson(player as Map),
    ],
    bots: _int(json['bots']) ?? 0,
    dice: _int(json['dice']) ?? GameOptions.maxDice,
    calza: json['calza'] as bool? ?? true,
  );
}

enum RoomStatus { connecting, lobby, playing, refused, closed }

/// A short code friends can read out to each other.
String newRoomCode([Random? random]) {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  final source = random ?? Random.secure();
  return List.generate(
    4,
    (_) => letters[source.nextInt(letters.length)],
  ).join();
}

const botNames = ['Paco', 'Inti', 'Chaska', 'Amaru', 'Killa', 'Tupac', 'Nina'];

/// This phone's place in an online room, as host or as guest. Once the game
/// has started it is also the feed the table is drawn from.
abstract class OnlineRoom extends ChangeNotifier implements TableFeed {
  OnlineRoom({
    required this.transport,
    required this.code,
    required String name,
  }) : chat = RoomChat(
         transport: transport,
         selfId: transport.selfId,
         selfName: name,
       );

  final RoomTransport transport;
  final String code;
  final RoomChat chat;
  final ValueNotifier<TableSnapshot?> _snapshot = ValueNotifier(null);
  StreamSubscription<RoomMessage>? _messages;
  Timer? _beat;
  bool _left = false;

  String get selfId => transport.selfId;
  bool get isHost;

  RoomStatus status = RoomStatus.connecting;

  /// Why this phone is not let in: `full`, `started` or `version` when the
  /// host said so, `unknown` when no host answered under this code,
  /// `network` when the room could not be reached at all.
  String? refusal;
  Lobby? lobby;

  /// False on a guest's phone while the host is not heard from: the game
  /// stands still meanwhile.
  bool get hostPresent => true;

  @override
  ValueListenable<TableSnapshot?> get snapshot => _snapshot;

  /// Joins the room. Completes once connected; the lobby follows.
  Future<void> open() async {
    try {
      await transport.connect(code);
    } on Object {
      if (_left) return;
      _refuse('network');
      return;
    }
    if (_left) return;
    _messages = transport.messages.listen(_onMessage);
    _beat = Timer.periodic(heartbeat, (_) => _onBeat());
    _opened();
  }

  void _opened();
  void _onMessage(RoomMessage message);
  void _onBeat();

  /// Asks for another dice colour; it is given if nobody has it.
  void pickColor(int color);

  void _refuse(String reason) {
    refusal = reason;
    _set(RoomStatus.refused);
  }

  void _set(RoomStatus next) {
    status = next;
    if (!_left) notifyListeners();
  }

  /// Leaves the room for good.
  Future<void> leave() async {
    if (_left) return;
    _left = true;
    _sayGoodbye();
    _beat?.cancel();
    await _messages?.cancel();
    // Let the goodbye go before the line is cut.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await transport.disconnect().catchError((Object _) {});
  }

  void _sayGoodbye();

  @override
  void dispose() {
    unawaited(leave());
    chat.dispose();
    _snapshot.dispose();
    super.dispose();
  }
}

/// The phone that runs the game for a room: it holds the table and sends
/// each guest what their seat may see.
class HostRoom extends OnlineRoom {
  HostRoom({
    required super.transport,
    required super.code,
    required String name,
    required int color,
    this.botLevel = BotLevel.normal,
    this.pace = const TablePace(revealLimit: Duration(seconds: 25)),
    Random? random,
  }) : _random = random ?? Random(),
       super(name: name) {
    _players.add(RoomPlayer(id: transport.selfId, name: name, color: color));
    _publishLobby();
  }

  final BotLevel botLevel;
  final TablePace pace;
  final Random _random;

  final List<RoomPlayer> _players = [];
  int _bots = 0;
  int _dice = GameOptions.maxDice;
  bool _calza = true;

  /// Goes up with every change of the lobby or of the game, so that a phone
  /// can tell it has missed something.
  int _rev = 0;

  /// For each guest, the heartbeats gone by since it was last heard.
  final Map<String, int> _heard = {};

  GameTable? _table;

  /// The id of whoever sits at each seat, null for a bot.
  List<String?> _seatIds = const [];

  @override
  bool get isHost => true;

  int get maxBots => GameOptions.maxPlayers - _players.length;
  bool get canStart => _players.length + _bots >= GameOptions.minPlayers;

  @override
  void _opened() => _set(RoomStatus.lobby);

  void _publishLobby() {
    _rev++;
    lobby = Lobby(
      players: List.of(_players),
      bots: _bots,
      dice: _dice,
      calza: _calza,
    );
    transport.send({'type': 'lobby', 'rev': _rev, ...lobby!.toJson()});
    if (status != RoomStatus.connecting) notifyListeners();
  }

  void setBots(int bots) {
    _bots = bots.clamp(0, maxBots);
    _publishLobby();
  }

  void setDice(int dice) {
    _dice = dice.clamp(GameOptions.minDice, GameOptions.maxDice);
    _publishLobby();
  }

  void setCalza(bool calza) {
    _calza = calza;
    _publishLobby();
  }

  @override
  void pickColor(int color) => _recolor(selfId, color);

  void _recolor(String id, int color) {
    if (_table != null) return;
    if (color < 0 || color >= Tokens.diceColors.length) return;
    final index = _players.indexWhere((player) => player.id == id);
    if (index < 0 || lobby!.takenColors.contains(color)) return;
    _players[index] = RoomPlayer(
      id: id,
      name: _players[index].name,
      color: color,
    );
    _publishLobby();
  }

  int _freeColor(int wanted) {
    final taken = lobby!.takenColors;
    if (wanted >= 0 &&
        wanted < Tokens.diceColors.length &&
        !taken.contains(wanted)) {
      return wanted;
    }
    return List.generate(
      Tokens.diceColors.length,
      (index) => index,
    ).firstWhere((index) => !taken.contains(index));
  }

  @override
  void _onMessage(RoomMessage message) {
    final payload = message.payload;
    final from = message.from;
    switch (payload['type']) {
      case 'hello':
        _onHello(from, payload);
      case 'color':
        _heard[from] = 0;
        _recolor(from, _int(payload['color']) ?? -1);
      case 'act':
        _heard[from] = 0;
        final seat = _seatIds.indexOf(from);
        final action = switch (payload['action']) {
          final Map<Object?, Object?> json => TableAction.fromJson(json),
          _ => null,
        };
        if (seat < 0 ||
            action == null ||
            _int(payload['game']) != _table?.number) {
          return;
        }
        // Refused: the guest acted on something stale, and is shown anew.
        if (!_table!.act(seat, action)) _sendState(seat);
      case 'leave':
        _heard.remove(from);
        _gone(from);
    }
  }

  void _onHello(String from, Json payload) {
    if (_int(payload['v']) != protocolVersion) {
      transport.send({'type': 'refused', 'reason': 'version'}, to: from);
      return;
    }
    _heard[from] = 0;
    final behind = _int(payload['rev']) != _rev;
    final table = _table;
    if (table != null) {
      final seat = _seatIds.indexOf(from);
      if (seat < 0) {
        transport.send({'type': 'refused', 'reason': 'started'}, to: from);
        return;
      }
      table.setAway(seat, false);
      if (behind) _sendState(seat);
      return;
    }
    if (_players.any((player) => player.id == from)) {
      if (behind) {
        transport.send({
          'type': 'lobby',
          'rev': _rev,
          ...lobby!.toJson(),
        }, to: from);
      }
      return;
    }
    if (_players.length >= GameOptions.maxPlayers) {
      transport.send({'type': 'refused', 'reason': 'full'}, to: from);
      return;
    }
    final name = (payload['name'] as String? ?? '').trim();
    _players.add(
      RoomPlayer(
        id: from,
        name: name.isEmpty ? 'Invité' : name,
        color: _freeColor(_int(payload['color']) ?? -1),
      ),
    );
    // A newcomer takes the chair of a bot when the table is full.
    _bots = _bots.clamp(0, maxBots);
    _publishLobby();
  }

  /// [id] left or went silent.
  void _gone(String id) {
    final table = _table;
    if (table != null) {
      final seat = _seatIds.indexOf(id);
      if (seat >= 0) table.setAway(seat, true);
      return;
    }
    final before = _players.length;
    _players.removeWhere((player) => player.id == id && id != selfId);
    if (_players.length != before) _publishLobby();
  }

  @override
  void _onBeat() {
    transport.send({'type': 'beat', 'rev': _rev});
    _heard.updateAll((id, beats) => beats + 1);
    final silent = [
      for (final MapEntry(:key, :value) in _heard.entries)
        if (value > missedBeats) key,
    ];
    for (final id in silent) {
      _heard.remove(id);
      _gone(id);
    }
  }

  /// Starts the game with whoever is in the room and the bots asked for.
  /// Seats are shuffled so that people and bots are mixed.
  void start() {
    if (!canStart || _table != null) return;
    final taken = lobby!.takenColors;
    final free = [
      for (var index = 0; index < Tokens.diceColors.length; index++)
        if (!taken.contains(index)) index,
    ]..shuffle(_random);
    final names = List.of(botNames)..shuffle(_random);
    final seats = <(String?, SeatInfo)>[
      for (final player in _players)
        (player.id, SeatInfo(name: player.name, color: player.color)),
      for (var bot = 0; bot < _bots; bot++)
        (null, SeatInfo(name: names[bot], color: free[bot], isBot: true)),
    ]..shuffle(_random);
    _seatIds = [for (final (id, _) in seats) id];
    _deal([for (final (_, seat) in seats) seat], number: 1);
  }

  /// Plays again in the same room: same seats, same options, new dice.
  void rematch() {
    final table = _table;
    if (table == null || table.game.phase != Phase.finished) return;
    table.dispose();
    _deal(table.seats, number: table.number + 1);
  }

  void _deal(List<SeatInfo> seats, {required int number}) {
    final table = _table = GameTable(
      seats: seats,
      options: GameOptions(
        players: seats.length,
        startDice: _dice,
        calza: _calza,
      ),
      botLevel: botLevel,
      pace: pace,
      number: number,
      random: _random,
    );
    table.onChanged = _publishState;
    status = RoomStatus.playing;
    _publishState();
  }

  void _publishState() {
    final table = _table;
    if (table == null || _left) return;
    _rev++;
    for (var seat = 0; seat < _seatIds.length; seat++) {
      if (_seatIds[seat] == selfId) {
        _snapshot.value = table.snapshotFor(seat);
      } else if (_seatIds[seat] != null) {
        _sendState(seat);
      }
    }
    notifyListeners();
  }

  void _sendState(int seat) => transport.send({
    'type': 'state',
    'rev': _rev,
    'snap': _table!.snapshotFor(seat).toJson(),
  }, to: _seatIds[seat]);

  @override
  void act(TableAction action) => _table?.act(_seatIds.indexOf(selfId), action);

  @override
  void _sayGoodbye() {
    transport.send({'type': 'closed'});
    _table?.dispose();
  }
}

/// A phone that joined a room: it shows what the host sends for its seat and
/// sends back what its player does.
class GuestRoom extends OnlineRoom {
  GuestRoom({
    required super.transport,
    required super.code,
    required this.name,
    required this.color,
  }) : super(name: name);

  final String name;
  final int color;

  int _rev = -1;
  String? _hostId;

  /// The heartbeats gone by since the host was last heard.
  int _quiet = 0;
  bool _everHeard = false;
  bool _hostPresent = true;

  /// What the player did that the host has not answered yet: sent again
  /// with each heartbeat, in case it was lost.
  TableAction? _pending;

  @override
  bool get isHost => false;

  @override
  bool get hostPresent => _hostPresent;

  @override
  void _opened() => _hello();

  void _hello() => transport.send({
    'type': 'hello',
    'v': protocolVersion,
    'name': name,
    'color': color,
    'rev': _rev,
  }, to: _hostId);

  void _hostHeard(String from) {
    _hostId = from;
    _quiet = 0;
    _everHeard = true;
    if (!_hostPresent) {
      _hostPresent = true;
      notifyListeners();
    }
  }

  @override
  void _onMessage(RoomMessage message) {
    if (status == RoomStatus.refused || status == RoomStatus.closed) return;
    final payload = message.payload;
    switch (payload['type']) {
      case 'lobby':
        _hostHeard(message.from);
        // A lobby after the game began would be a stale message.
        if (status == RoomStatus.playing) return;
        _rev = _int(payload['rev']) ?? _rev;
        lobby = Lobby.fromJson(payload);
        // Sent to all when someone else came in: this phone may not be in yet.
        if (!lobby!.players.any((player) => player.id == selfId)) {
          _rev = -1;
          return;
        }
        _set(RoomStatus.lobby);
      case 'state':
        _hostHeard(message.from);
        final TableSnapshot snapshot;
        try {
          snapshot = TableSnapshot.fromJson(payload['snap'] as Map);
        } on Object {
          return;
        }
        _rev = _int(payload['rev']) ?? _rev;
        _pending = null;
        _snapshot.value = snapshot;
        _set(RoomStatus.playing);
      case 'beat':
        _hostHeard(message.from);
        if (_int(payload['rev']) != _rev) _hello();
      case 'refused':
        _refuse(payload['reason'] as String? ?? 'unknown');
      case 'closed':
        _set(RoomStatus.closed);
    }
  }

  @override
  void _onBeat() {
    if (status == RoomStatus.refused || status == RoomStatus.closed) return;
    _hello();
    if (_pending case final action?) _sendAction(action);
    final quiet = ++_quiet > missedBeats;
    if (!_everHeard) {
      // Any code opens a channel: silence is the only sign of a wrong one.
      if (_quiet > 2) _refuse('unknown');
    } else if (quiet == _hostPresent) {
      _hostPresent = !quiet;
      notifyListeners();
    }
  }

  @override
  void pickColor(int color) =>
      transport.send({'type': 'color', 'color': color}, to: _hostId);

  @override
  void act(TableAction action) {
    _pending = action;
    _sendAction(action);
  }

  void _sendAction(TableAction action) => transport.send({
    'type': 'act',
    'game': _snapshot.value?.game,
    'action': action.toJson(),
  }, to: _hostId);

  @override
  void _sayGoodbye() => transport.send({'type': 'leave'}, to: _hostId);
}
