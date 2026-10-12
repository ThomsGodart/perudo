import 'dart:math';

import 'bid.dart';

enum Phase { bidding, reveal, finished }

enum Challenge { dudo, calza }

/// Thrown when a seat does what the rules do not allow right now.
final class IllegalMove implements Exception {
  const IllegalMove(this.reason);

  final String reason;

  @override
  String toString() => 'IllegalMove: $reason';
}

/// What a game is played with.
final class GameOptions {
  const GameOptions({
    required this.players,
    this.startDice = 5,
    this.calza = true,
  });

  final int players;
  final int startDice;

  /// Whether « Calza » (the bid is exactly right) may be called.
  final bool calza;

  static const minPlayers = 2;
  static const maxPlayers = 6;

  GameOptions copyWith({int? players, bool? calza}) => GameOptions(
    players: players ?? this.players,
    startDice: startDice,
    calza: calza ?? this.calza,
  );

  Map<String, Object?> toJson() => {
    'players': players,
    'startDice': startDice,
    'calza': calza,
  };

  static GameOptions fromJson(Map<Object?, Object?> json) => GameOptions(
    players: (json['players'] as num).toInt(),
    startDice: (json['startDice'] as num?)?.toInt() ?? 5,
    calza: json['calza'] as bool? ?? true,
  );
}

/// A bid and who made it.
final class BidEntry {
  const BidEntry(this.seat, this.bid);

  final int seat;
  final Bid bid;

  List<int> toJson() => [seat, bid.count, bid.face];

  static BidEntry fromJson(Object? json) {
    final list = [for (final value in json as List) (value as num).toInt()];
    return BidEntry(list[0], Bid(list[1], list[2]));
  }
}

/// How a round ended, with every cup lifted.
final class RoundResult {
  const RoundResult({
    required this.kind,
    required this.caller,
    required this.bidder,
    required this.bid,
    required this.actual,
    required this.wild,
    required this.seat,
    required this.delta,
    required this.dice,
  });

  final Challenge kind;

  /// Who called dudo or calza.
  final int caller;

  /// Who made the bid that was called.
  final int bidder;
  final Bid bid;

  /// How many dice really counted for the bid.
  final int actual;

  /// Whether pacos counted as jokers in that round.
  final bool wild;

  /// The seat whose number of dice changes, by [delta] (−1, 0 or +1).
  final int seat;
  final int delta;

  /// Every seat's dice as they were rolled.
  final List<List<int>> dice;

  /// Whether the caller was right.
  bool get callerRight => switch (kind) {
    Challenge.dudo => actual < bid.count,
    Challenge.calza => actual == bid.count,
  };

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'caller': caller,
    'bidder': bidder,
    'bid': bid.toJson(),
    'actual': actual,
    'wild': wild,
    'seat': seat,
    'delta': delta,
    'dice': dice,
  };

  static RoundResult fromJson(Map<Object?, Object?> json) => RoundResult(
    kind: Challenge.values.byName(json['kind'] as String),
    caller: (json['caller'] as num).toInt(),
    bidder: (json['bidder'] as num).toInt(),
    bid: Bid.fromJson(json['bid']),
    actual: (json['actual'] as num).toInt(),
    wild: json['wild'] as bool,
    seat: (json['seat'] as num).toInt(),
    delta: (json['delta'] as num).toInt(),
    dice: [
      for (final hand in json['dice'] as List)
        [for (final die in hand as List) (die as num).toInt()],
    ],
  );
}

/// What one seat may see of a game. A table is drawn from this alone.
final class GameView {
  const GameView({
    required this.options,
    required this.round,
    required this.phase,
    required this.palifico,
    required this.current,
    required this.counts,
    required this.history,
    required this.myDice,
    required this.result,
    required this.winner,
    required this.out,
  });

  final GameOptions options;

  /// 1 for the first round.
  final int round;
  final Phase phase;

  /// True in the round opened by a player who just fell to one die: pacos
  /// are not jokers and the announced face cannot change.
  final bool palifico;

  /// Whose turn it is to speak.
  final int current;

  /// How many dice each seat has left.
  final List<int> counts;

  /// The bids of this round, the oldest first.
  final List<BidEntry> history;

  /// The dice under this seat's cup.
  final List<int> myDice;
  final RoundResult? result;
  final int? winner;

  /// The seats that lost all their dice, the first out first.
  final List<int> out;

  bool get wild => !palifico;
  int get totalDice => counts.fold(0, (sum, count) => sum + count);
  int get lostDice => options.players * options.startDice - totalDice;
  int get alive => counts.where((count) => count > 0).length;
  BidEntry? get lastBid => history.lastOrNull;

  /// The latest bid of [seat] in this round, if it made one.
  Bid? bidOf(int seat) {
    for (final entry in history.reversed) {
      if (entry.seat == seat) return entry.bid;
    }
    return null;
  }

  bool isLegal(Bid bid) => Rules.isLegal(
    bid,
    last: lastBid?.bid,
    palifico: palifico,
    totalDice: totalDice,
  );

  int? minCount(int face) => Rules.minCount(
    face,
    last: lastBid?.bid,
    palifico: palifico,
    totalDice: totalDice,
  );

  bool get canDudo => phase == Phase.bidding && history.isNotEmpty;

  /// Calza is kept out of palifico rounds and of duels, as is customary.
  bool get canCalza => canDudo && options.calza && !palifico && alive > 2;

  Map<String, Object?> toJson() => {
    'options': options.toJson(),
    'round': round,
    'phase': phase.name,
    'palifico': palifico,
    'current': current,
    'counts': counts,
    'history': [for (final entry in history) entry.toJson()],
    'myDice': myDice,
    'result': result?.toJson(),
    'winner': winner,
    'out': out,
  };

  static List<int> _ints(Object? json) => [
    for (final value in json as List) (value as num).toInt(),
  ];

  static GameView fromJson(Map<Object?, Object?> json) => GameView(
    options: GameOptions.fromJson(json['options'] as Map),
    round: (json['round'] as num).toInt(),
    phase: Phase.values.byName(json['phase'] as String),
    palifico: json['palifico'] as bool,
    current: (json['current'] as num).toInt(),
    counts: _ints(json['counts']),
    history: [
      for (final entry in json['history'] as List) BidEntry.fromJson(entry),
    ],
    myDice: _ints(json['myDice']),
    result: switch (json['result']) {
      final Map<Object?, Object?> result => RoundResult.fromJson(result),
      _ => null,
    },
    winner: (json['winner'] as num?)?.toInt(),
    out: _ints(json['out']),
  );
}

/// A game of Perudo: the dice, whose turn it is, and the rules.
///
/// Seats are numbered clockwise from 0. Pure Dart: whoever drives it (a
/// table with bots, the host of an online room) calls [bid], [dudo],
/// [calza], then [nextRound] once the result has been shown.
class PerudoGame {
  PerudoGame(this.options, {Random? random, int? firstSeat})
    : assert(
        options.players >= GameOptions.minPlayers &&
            options.players <= GameOptions.maxPlayers,
      ),
      _random = random ?? Random(),
      counts = List.filled(options.players, options.startDice) {
    _startRound(firstSeat ?? _random.nextInt(options.players), palifico: false);
  }

  final GameOptions options;
  final Random _random;

  /// How many dice each seat has left.
  final List<int> counts;
  final List<List<int>> _dice = [];
  final List<BidEntry> _history = [];
  final Set<int> _hadPalifico = {};
  final List<int> _out = [];

  int round = 0;
  Phase phase = Phase.bidding;
  bool palifico = false;
  int current = 0;
  RoundResult? result;
  int? winner;

  List<BidEntry> get history => List.unmodifiable(_history);
  List<int> diceOf(int seat) => List.unmodifiable(_dice[seat]);
  int get alive => counts.where((count) => count > 0).length;

  GameView viewFor(int seat) => GameView(
    options: options,
    round: round,
    phase: phase,
    palifico: palifico,
    current: current,
    counts: List.of(counts),
    history: List.of(_history),
    myDice: seat >= 0 && seat < options.players
        ? List.of(_dice[seat])
        : const [],
    result: result,
    winner: winner,
    out: List.of(_out),
  );

  void _startRound(int starter, {required bool palifico}) {
    round++;
    this.palifico = palifico;
    phase = Phase.bidding;
    result = null;
    _history.clear();
    _dice
      ..clear()
      ..addAll([
        for (final count in counts)
          List.generate(count, (_) => _random.nextInt(6) + 1)..sort(),
      ]);
    current = counts[starter] > 0 ? starter : _nextAlive(starter);
  }

  int _nextAlive(int seat) {
    var next = seat;
    do {
      next = (next + 1) % options.players;
    } while (counts[next] == 0);
    return next;
  }

  void _expectTurn(int seat) {
    if (phase != Phase.bidding) throw const IllegalMove('no bidding now');
    if (seat != current) throw const IllegalMove('not this seat\'s turn');
  }

  void bid(int seat, Bid bid) {
    _expectTurn(seat);
    if (!viewFor(seat).isLegal(bid)) throw IllegalMove('cannot bid $bid');
    _history.add(BidEntry(seat, bid));
    current = _nextAlive(seat);
  }

  /// [seat] doubts the last bid: whoever is wrong loses a die.
  void dudo(int seat) {
    _expectTurn(seat);
    if (_history.isEmpty) throw const IllegalMove('nothing to doubt');
    final last = _history.last;
    final actual = _count(last.bid.face);
    _settle(
      Challenge.dudo,
      caller: seat,
      actual: actual,
      seat: actual >= last.bid.count ? seat : last.seat,
      delta: -1,
    );
  }

  /// [seat] claims the last bid is exactly right: a die back if so (never
  /// more than at the start), a die lost otherwise.
  void calza(int seat) {
    _expectTurn(seat);
    if (!viewFor(seat).canCalza) throw const IllegalMove('no calza now');
    final last = _history.last;
    final actual = _count(last.bid.face);
    final exact = actual == last.bid.count;
    _settle(
      Challenge.calza,
      caller: seat,
      actual: actual,
      seat: seat,
      delta: !exact
          ? -1
          : counts[seat] < options.startDice
          ? 1
          : 0,
    );
  }

  int _count(int face) =>
      Rules.count(_dice.expand((hand) => hand), face, wild: !palifico);

  void _settle(
    Challenge kind, {
    required int caller,
    required int actual,
    required int seat,
    required int delta,
  }) {
    final last = _history.last;
    result = RoundResult(
      kind: kind,
      caller: caller,
      bidder: last.seat,
      bid: last.bid,
      actual: actual,
      wild: !palifico,
      seat: seat,
      delta: delta,
      dice: [for (final hand in _dice) List.of(hand)],
    );
    counts[seat] += delta;
    if (counts[seat] == 0) _out.add(seat);
    phase = Phase.reveal;
  }

  /// Rolls the next round once the result has been seen, or ends the game.
  /// Whoever lost or won a die opens it; if they are out, the next seat.
  void nextRound() {
    if (phase != Phase.reveal) throw const IllegalMove('no result to leave');
    final last = result!;
    if (alive == 1) {
      winner = counts.indexWhere((count) => count > 0);
      phase = Phase.finished;
      return;
    }
    // Once per player, and never in a duel.
    final palifico =
        last.delta < 0 &&
        counts[last.seat] == 1 &&
        alive > 2 &&
        _hadPalifico.add(last.seat);
    _startRound(last.seat, palifico: palifico);
  }
}
