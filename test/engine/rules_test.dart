import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:perudo/engine/engine.dart';

bool legal(Bid bid, Bid? last, {bool palifico = false, int total = 25}) =>
    Rules.isLegal(bid, last: last, palifico: palifico, totalDice: total);

/// A game whose dice are known: [hands] are dealt in order, round after round.
PerudoGame rigged(
  List<List<int>> hands, {
  int players = 3,
  bool calza = true,
}) => PerudoGame(
  GameOptions(players: players, calza: calza),
  random: _Scripted([for (final hand in hands) ...hand]),
  firstSeat: 0,
);

class _Scripted implements Random {
  _Scripted(this._faces);

  final List<int> _faces;
  int _next = 0;

  @override
  int nextInt(int max) => _next < _faces.length ? _faces[_next++] - 1 : 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  group('bids', () {
    test('a round cannot open on pacos, except in palifico', () {
      expect(legal(const Bid(2, 1), null), isFalse);
      expect(legal(const Bid(2, 3), null), isTrue);
      expect(legal(const Bid(1, 1), null, palifico: true), isTrue);
    });

    test('a raise is more dice, or as many of a higher face', () {
      const last = Bid(4, 3);
      expect(legal(const Bid(5, 2), last), isTrue);
      expect(legal(const Bid(4, 5), last), isTrue);
      expect(legal(const Bid(4, 3), last), isFalse);
      expect(legal(const Bid(4, 2), last), isFalse);
      expect(legal(const Bid(3, 6), last), isFalse);
    });

    test('going to pacos halves the count, rounded up', () {
      expect(legal(const Bid(4, 1), const Bid(7, 5)), isTrue);
      expect(legal(const Bid(3, 1), const Bid(7, 5)), isFalse);
      expect(legal(const Bid(4, 1), const Bid(8, 5)), isTrue);
    });

    test('leaving pacos takes twice as many plus one', () {
      expect(legal(const Bid(9, 2), const Bid(4, 1)), isTrue);
      expect(legal(const Bid(8, 6), const Bid(4, 1)), isFalse);
      expect(legal(const Bid(5, 1), const Bid(4, 1)), isTrue);
      expect(legal(const Bid(4, 1), const Bid(4, 1)), isFalse);
    });

    test('in palifico only the count goes up', () {
      const last = Bid(2, 4);
      expect(legal(const Bid(3, 4), last, palifico: true), isTrue);
      expect(legal(const Bid(3, 5), last, palifico: true), isFalse);
      expect(legal(const Bid(2, 6), last, palifico: true), isFalse);
      expect(legal(const Bid(1, 1), last, palifico: true), isFalse);
    });

    test('never more dice than are on the table', () {
      expect(legal(const Bid(6, 2), null, total: 5), isFalse);
      expect(
        Rules.minCount(2, last: const Bid(5, 6), palifico: false, totalDice: 5),
        isNull,
      );
    });
  });

  group('a round', () {
    // Seat 0: 1 2 2 3 4 · seat 1: 2 5 5 6 6 · seat 2: 1 1 3 4 6
    const hands = [
      [1, 2, 2, 3, 4],
      [2, 5, 5, 6, 6],
      [1, 1, 3, 4, 6],
    ];

    test('dudo on a bid that holds costs the doubter a die', () {
      final game = rigged(hands);
      game.bid(0, const Bid(6, 2)); // three 2s and three pacos
      game.dudo(1);
      final result = game.result!;
      expect(result.actual, 6);
      expect(result.seat, 1);
      expect(game.counts, [5, 4, 5]);
      expect(game.phase, Phase.reveal);
      game.nextRound();
      expect(game.current, 1, reason: 'whoever lost a die opens');
      expect(game.round, 2);
    });

    test('dudo on a bid that fails costs the bidder a die', () {
      final game = rigged(hands);
      game.bid(0, const Bid(7, 2));
      game.dudo(1);
      expect(game.result!.callerRight, isTrue);
      expect(game.counts, [4, 5, 5]);
    });

    test('pacos bid as pacos count alone', () {
      final game = rigged(hands);
      game.bid(0, const Bid(3, 2));
      game.bid(1, const Bid(3, 1));
      game.dudo(2);
      expect(game.result!.actual, 3);
      expect(game.counts, [5, 5, 4]);
    });

    test('calza wins a die back when exact, never above the start', () {
      final game = rigged(hands);
      game.bid(0, const Bid(6, 2));
      game.calza(1);
      expect(game.result!.callerRight, isTrue);
      expect(game.result!.delta, 0);
      expect(game.counts, [5, 5, 5]);
      game.nextRound();
      expect(game.current, 1, reason: 'whoever called calza opens');
    });

    test('a wrong calza costs a die', () {
      final game = rigged(hands);
      game.bid(0, const Bid(5, 2));
      game.calza(1);
      expect(game.counts, [5, 4, 5]);
    });

    test('calza can be switched off, and is not for duels', () {
      final off = rigged(hands, calza: false)..bid(0, const Bid(5, 2));
      expect(() => off.calza(1), throwsA(isA<IllegalMove>()));
      final duel = rigged(hands, players: 2)..bid(0, const Bid(2, 2));
      expect(duel.viewFor(1).canCalza, isFalse);
    });

    test('only the seat whose turn it is may speak', () {
      final game = rigged(hands);
      expect(() => game.bid(1, const Bid(1, 2)), throwsA(isA<IllegalMove>()));
      expect(() => game.dudo(0), throwsA(isA<IllegalMove>()));
    });
  });

  test('falling to one die opens a palifico round, once', () {
    final game = PerudoGame(
      const GameOptions(players: 3),
      random: Random(4),
      firstSeat: 0,
    );
    // Seat 0 overbids until it has one die left.
    while (game.counts[0] > 1) {
      game.bid(game.current, Bid(game.viewFor(0).totalDice, 6));
      game.dudo(game.current);
      expect(game.result!.callerRight, isTrue);
      game.nextRound();
      // Hand the turn back to seat 0 by harmless bids.
      var count = 1;
      while (game.current != 0) {
        game.bid(game.current, Bid(count++, 2));
      }
      if (game.counts[0] > 1) {
        expect(game.palifico, isFalse);
        // Seat 0 cannot overbid on a running round here: end it cleanly.
        if (game.history.isNotEmpty) {
          game.bid(0, Bid(game.viewFor(0).totalDice, 6));
          game.dudo(game.current);
          game.nextRound();
          while (game.current != 0) {
            game.bid(game.current, Bid(1, 2));
          }
        }
      }
    }
    expect(game.palifico, isTrue);
    expect(game.current, 0);
    final view = game.viewFor(0);
    expect(view.wild, isFalse);
    expect(view.isLegal(const Bid(1, 1)), isTrue);
    expect(view.canCalza, isFalse);
    game.bid(0, const Bid(1, 4));
    expect(game.viewFor(1).isLegal(const Bid(2, 5)), isFalse);
    expect(game.viewFor(1).isLegal(const Bid(2, 4)), isTrue);
  });

  test('random games always end with one winner', () {
    for (var seed = 0; seed < 200; seed++) {
      final random = Random(seed);
      final players = 2 + random.nextInt(5);
      final game = PerudoGame(
        GameOptions(players: players, calza: seed.isEven),
        random: random,
      );
      var steps = 0;
      while (game.phase != Phase.finished) {
        expect(steps++, lessThan(5000));
        if (game.phase == Phase.reveal) {
          game.nextRound();
          continue;
        }
        final seat = game.current;
        final view = game.viewFor(seat);
        expect(view.myDice.length, view.counts[seat]);
        final bids = [
          for (var face = 1; face <= 6; face++)
            if (view.minCount(face) case final min?) Bid(min, face),
        ];
        final roll = random.nextInt(10);
        if (view.canCalza && roll == 0) {
          game.calza(seat);
        } else if (view.canDudo && (roll < 4 || bids.isEmpty)) {
          game.dudo(seat);
        } else {
          game.bid(seat, bids[random.nextInt(bids.length)]);
        }
      }
      expect(game.alive, 1);
      expect(game.counts[game.winner!], greaterThan(0));
      expect(game.viewFor(0).out.length, players - 1);
      // What a seat sees survives the trip to another phone.
      final view = game.viewFor(0);
      expect(GameView.fromJson(view.toJson()).toJson(), view.toJson());
    }
  });
}
