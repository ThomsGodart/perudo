import 'dart:math';

import '../engine/engine.dart';
import '../game/table.dart';

enum BotLevel { easy, normal, hard }

/// A bot that weighs each announcement by its odds, given its own dice.
///
/// The higher the level, the less noise in its estimates and the better it
/// compares doubting with raising.
class PerudoBot {
  PerudoBot(this.level, [Random? random]) : _random = random ?? Random();

  final BotLevel level;
  final Random _random;

  /// How far off the bot's estimates may be.
  double get _noise => switch (level) {
    BotLevel.easy => 0.28,
    BotLevel.normal => 0.12,
    BotLevel.hard => 0.04,
  };

  TableAction decide(GameView view) {
    final last = view.lastBid?.bid;
    if (last == null) return BidAction(_opening(view));

    final holds = _fuzzy(_atLeast(view, last));
    final raise = _bestRaise(view);
    if (view.canCalza && level != BotLevel.easy) {
      final exact = _exactly(view, last);
      // A die back is worth a risk, more so when few are left.
      final wanted = view.myDice.length < view.options.startDice ? 0.38 : 0.6;
      if (exact > wanted && exact > 1 - holds) return const CalzaAction();
    }
    if (raise == null) return const DudoAction();
    final (bid, odds) = raise;
    // Doubting wins when the bid fails; raising is safe when the raise
    // holds, and often even when it does not, since it may not be called.
    final doubt = 1 - holds;
    final carryOn = odds + (1 - odds) * 0.25;
    return doubt > carryOn ? const DudoAction() : BidAction(bid);
  }

  double _fuzzy(double odds) =>
      (odds + (_random.nextDouble() * 2 - 1) * _noise).clamp(0.0, 1.0);

  Bid _opening(GameView view) {
    final faces = [
      for (var face = 1; face <= 6; face++)
        if (view.minCount(face) != null) face,
    ];
    // The face it holds most of, pacos included when they are jokers.
    int held(int face) => Rules.count(view.myDice, face, wild: view.wild);
    faces.shuffle(_random);
    faces.sort((a, b) => held(b).compareTo(held(a)));
    final face = level == BotLevel.easy && _random.nextBool()
        ? faces[_random.nextInt(faces.length)]
        : faces.first;
    final others = view.totalDice - view.myDice.length;
    final expected = held(face) + others * _chance(view, face);
    final count = (expected * 0.75).floor().clamp(1, view.totalDice);
    return Bid(count, face);
  }

  /// The raise most likely to hold, with its odds.
  (Bid, double)? _bestRaise(GameView view) {
    (Bid, double)? best;
    for (var face = 1; face <= 6; face++) {
      final min = view.minCount(face);
      if (min == null) continue;
      final bid = Bid(min, face);
      final odds = _fuzzy(_atLeast(view, bid));
      if (best == null || odds > best.$2) best = (bid, odds);
    }
    return best;
  }

  double _chance(GameView view, int face) =>
      view.wild && face != 1 ? 1 / 3 : 1 / 6;

  /// The odds that [bid] holds, the bot's own dice being known.
  double _atLeast(GameView view, Bid bid) {
    final need =
        bid.count - Rules.count(view.myDice, bid.face, wild: view.wild);
    final others = view.totalDice - view.myDice.length;
    var odds = 0.0;
    for (var k = max(need, 0); k <= others; k++) {
      odds += _binomial(others, k, _chance(view, bid.face));
    }
    return odds;
  }

  double _exactly(GameView view, Bid bid) {
    final need =
        bid.count - Rules.count(view.myDice, bid.face, wild: view.wild);
    final others = view.totalDice - view.myDice.length;
    if (need < 0 || need > others) return 0;
    return _binomial(others, need, _chance(view, bid.face));
  }

  static double _binomial(int n, int k, double p) {
    var ways = 1.0;
    for (var i = 1; i <= k; i++) {
      ways = ways * (n - k + i) / i;
    }
    return ways * pow(p, k) * pow(1 - p, n - k);
  }
}
