import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perudo/bots/bot.dart';
import 'package:perudo/engine/engine.dart';
import 'package:perudo/game/table.dart';

List<SeatInfo> seats(int humans, int bots) => [
  for (var seat = 0; seat < humans; seat++)
    SeatInfo(name: 'H$seat', color: seat),
  for (var seat = 0; seat < bots; seat++)
    SeatInfo(name: 'B$seat', color: humans + seat, isBot: true),
];

void main() {
  for (final level in BotLevel.values) {
    test('bots at $level play a whole game by themselves', () {
      fakeAsync((async) {
        for (var seed = 0; seed < 20; seed++) {
          final table = GameTable(
            seats: seats(0, 4),
            options: const GameOptions(players: 4),
            botLevel: level,
            pace: TablePace.instant,
            random: Random(seed),
          );
          async.elapse(const Duration(minutes: 1));
          expect(table.game.phase, Phase.finished, reason: 'seed $seed');
          table.dispose();
        }
      });
    });
  }

  test('the table waits for its player, then for them to see the result', () {
    fakeAsync((async) {
      final table = GameTable(
        seats: seats(1, 2),
        options: const GameOptions(players: 3),
        pace: TablePace.instant,
        random: Random(1),
      );
      final feed = LocalTableFeed(table);
      async.elapse(const Duration(seconds: 5));
      expect(table.game.phase, Phase.bidding);
      expect(feed.snapshot.value!.myTurn, isTrue);

      // An illegal move is refused and changes nothing.
      expect(
        table.act(0, BidAction(Bid(table.game.viewFor(0).totalDice + 1, 2))),
        isFalse,
      );
      expect(table.act(1, const DudoAction()), isFalse);

      final view = feed.snapshot.value!.view;
      feed.act(BidAction(Bid(view.totalDice, view.lastBid?.bid.face ?? 6)));
      async.elapse(const Duration(seconds: 5));
      // Fifteen of a kind: a bot doubts it at once, and the table holds the
      // result until the player has seen it.
      expect(table.game.phase, Phase.reveal);
      async.elapse(const Duration(minutes: 5));
      expect(table.game.phase, Phase.reveal);
      feed.act(const ReadyAction());
      expect(table.game.round, 2);
      feed.dispose();
    });
  });

  test('a bot speaks for a player who is away', () {
    fakeAsync((async) {
      final table = GameTable(
        seats: seats(2, 0),
        options: const GameOptions(players: 2),
        pace: TablePace.instant,
        random: Random(3),
      );
      async.elapse(const Duration(seconds: 1));
      expect(table.game.history, isEmpty);
      table.setAway(table.game.current, true);
      async.elapse(const Duration(seconds: 1));
      expect(table.game.history, isNotEmpty);
      table.dispose();
    });
  });

  test('a snapshot survives the trip to another phone', () {
    final table = GameTable(
      seats: seats(2, 1),
      options: const GameOptions(players: 3),
      pace: const TablePace(),
      random: Random(2),
    );
    final snapshot = table.snapshotFor(1);
    expect(
      TableSnapshot.fromJson(snapshot.toJson()).toJson(),
      snapshot.toJson(),
    );
    table.dispose();
  });
}
