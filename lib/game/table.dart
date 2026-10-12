import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../bots/bot.dart';
import '../engine/engine.dart';

/// Who sits at a seat.
final class SeatInfo {
  const SeatInfo({
    required this.name,
    required this.color,
    this.isBot = false,
    this.away = false,
  });

  final String name;

  /// An index into the dice colours; no two seats of a table share one.
  final int color;
  final bool isBot;

  /// A player of an online game whose phone is not heard from: a bot speaks
  /// for them meanwhile.
  final bool away;

  SeatInfo copyWith({bool? away}) =>
      SeatInfo(name: name, color: color, isBot: isBot, away: away ?? this.away);

  Map<String, Object?> toJson() => {
    'name': name,
    'color': color,
    'bot': isBot,
    'away': away,
  };

  static SeatInfo fromJson(Map<Object?, Object?> json) => SeatInfo(
    name: json['name'] as String? ?? '?',
    color: (json['color'] as num?)?.toInt() ?? 0,
    isBot: json['bot'] as bool? ?? false,
    away: json['away'] as bool? ?? false,
  );
}

/// What a player does at the table.
sealed class TableAction {
  const TableAction();

  Map<String, Object?> toJson() => switch (this) {
    BidAction(:final bid) => {'do': 'bid', 'bid': bid.toJson()},
    DudoAction() => {'do': 'dudo'},
    CalzaAction() => {'do': 'calza'},
    ReadyAction() => {'do': 'ready'},
  };

  static TableAction? fromJson(Map<Object?, Object?> json) {
    try {
      return switch (json['do']) {
        'bid' => BidAction(Bid.fromJson(json['bid'])),
        'dudo' => const DudoAction(),
        'calza' => const CalzaAction(),
        'ready' => const ReadyAction(),
        _ => null,
      };
    } on Object {
      return null;
    }
  }
}

final class BidAction extends TableAction {
  const BidAction(this.bid);

  final Bid bid;
}

final class DudoAction extends TableAction {
  const DudoAction();
}

final class CalzaAction extends TableAction {
  const CalzaAction();
}

/// « I have seen the result »: the next round may be rolled.
final class ReadyAction extends TableAction {
  const ReadyAction();
}

/// Everything a phone needs to draw the table for one seat.
final class TableSnapshot {
  const TableSnapshot({
    required this.game,
    required this.seats,
    required this.you,
    required this.view,
    required this.ready,
  });

  /// Which game of the table this is: one more with each rematch.
  final int game;
  final List<SeatInfo> seats;

  /// The seat this was made for.
  final int you;
  final GameView view;

  /// The seats that have seen the result of the round.
  final Set<int> ready;

  bool get myTurn => view.phase == Phase.bidding && view.current == you;

  Map<String, Object?> toJson() => {
    'game': game,
    'seats': [for (final seat in seats) seat.toJson()],
    'you': you,
    'view': view.toJson(),
    'ready': ready.toList(),
  };

  static TableSnapshot fromJson(Map<Object?, Object?> json) => TableSnapshot(
    game: (json['game'] as num).toInt(),
    seats: [
      for (final seat in json['seats'] as List) SeatInfo.fromJson(seat as Map),
    ],
    you: (json['you'] as num).toInt(),
    view: GameView.fromJson(json['view'] as Map),
    ready: {for (final seat in json['ready'] as List) (seat as num).toInt()},
  );
}

/// What a table screen shows and where it sends what its player does,
/// wherever the game runs: on this phone or on the host's.
abstract interface class TableFeed {
  ValueListenable<TableSnapshot?> get snapshot;

  void act(TableAction action);
}

/// How long the bots take, and how long a result stays up.
final class TablePace {
  const TablePace({
    this.botThinks = const Duration(milliseconds: 1500),
    this.afterRoll = const Duration(milliseconds: 2200),
    this.unattendedReveal = const Duration(seconds: 5),
    this.revealLimit,
  });

  /// No waiting at all, for tests.
  static const instant = TablePace(
    botThinks: Duration.zero,
    afterRoll: Duration.zero,
    unattendedReveal: Duration.zero,
  );

  final Duration botThinks;

  /// Added before the first bid of a round, while the dice roll.
  final Duration afterRoll;

  /// How long a result stays when nobody is there to dismiss it.
  final Duration unattendedReveal;

  /// How long a result stays at most, when several people must dismiss it.
  final Duration? revealLimit;
}

/// A table where a game is played: the engine, the bots that fill seats, and
/// the pauses between rounds. The one authority on the game, on a solo
/// phone as on the host of an online room.
class GameTable {
  GameTable({
    required List<SeatInfo> seats,
    required this.options,
    this.botLevel = BotLevel.normal,
    this.pace = const TablePace(),
    this.number = 1,
    Random? random,
  }) : assert(seats.length == options.players),
       seats = List.of(seats),
       _random = random ?? Random() {
    game = PerudoGame(options, random: _random);
    _bot = PerudoBot(botLevel, _random);
    _plan();
  }

  final GameOptions options;
  final BotLevel botLevel;
  final TablePace pace;
  final int number;
  final List<SeatInfo> seats;
  final Random _random;
  late final PerudoGame game;
  late final PerudoBot _bot;
  final Set<int> _ready = {};
  Timer? _timer;
  bool _disposed = false;

  /// Called after every change of the game or of who is there.
  VoidCallback? onChanged;

  TableSnapshot snapshotFor(int seat) => TableSnapshot(
    game: number,
    seats: List.of(seats),
    you: seat,
    view: game.viewFor(seat),
    ready: Set.of(_ready),
  );

  /// Whether a bot speaks for [seat] right now.
  bool _automatic(int seat) => seats[seat].isBot || seats[seat].away;

  void setAway(int seat, bool away) {
    if (seats[seat].away == away) return;
    seats[seat] = seats[seat].copyWith(away: away);
    _changed();
  }

  /// Does [action] for [seat]. Returns false when the rules refuse it.
  bool act(int seat, TableAction action) {
    if (_disposed || seat < 0 || seat >= seats.length) return false;
    try {
      switch (action) {
        case BidAction(:final bid):
          game.bid(seat, bid);
        case DudoAction():
          game.dudo(seat);
        case CalzaAction():
          game.calza(seat);
        case ReadyAction():
          if (game.phase != Phase.reveal) return false;
          _ready.add(seat);
      }
    } on IllegalMove {
      return false;
    }
    _changed();
    return true;
  }

  void _changed() {
    _plan();
    onChanged?.call();
  }

  /// Decides what happens next without anyone touching the table.
  void _plan() {
    _timer?.cancel();
    _timer = null;
    if (_disposed) return;
    switch (game.phase) {
      case Phase.bidding:
        final seat = game.current;
        if (!_automatic(seat)) return;
        final thinks = pace.botThinks * (0.7 + _random.nextDouble() * 0.6);
        final wait =
            thinks + (game.history.isEmpty ? pace.afterRoll : Duration.zero);
        _timer = Timer(wait, () {
          if (game.phase == Phase.bidding && game.current == seat) {
            act(seat, _bot.decide(game.viewFor(seat)));
          }
        });
      case Phase.reveal:
        // Those still in the game and at their phone must have seen it.
        final awaited = [
          for (var seat = 0; seat < seats.length; seat++)
            if (!_automatic(seat) && game.counts[seat] > 0) seat,
        ];
        final anyone = _ready.any((seat) => !_automatic(seat));
        if (awaited.isEmpty ? anyone : awaited.every(_ready.contains)) {
          _advance();
          return;
        }
        final limit = awaited.isEmpty
            ? pace.unattendedReveal
            : pace.revealLimit;
        if (limit != null) _timer = Timer(limit, _advance);
      case Phase.finished:
    }
  }

  void _advance() {
    if (_disposed || game.phase != Phase.reveal) return;
    _ready.clear();
    game.nextRound();
    _changed();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

/// A table played on this phone, seen from one seat.
class LocalTableFeed implements TableFeed {
  LocalTableFeed(this.table, {this.seat = 0})
    : _snapshot = ValueNotifier(table.snapshotFor(seat)) {
    table.onChanged = () => _snapshot.value = table.snapshotFor(seat);
  }

  final GameTable table;
  final int seat;
  final ValueNotifier<TableSnapshot?> _snapshot;

  @override
  ValueListenable<TableSnapshot?> get snapshot => _snapshot;

  @override
  void act(TableAction action) => table.act(seat, action);

  void dispose() {
    table.dispose();
    _snapshot.dispose();
  }
}
