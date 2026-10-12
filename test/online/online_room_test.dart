import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perudo/bots/bot.dart';
import 'package:perudo/engine/engine.dart';
import 'package:perudo/game/table.dart';
import 'package:perudo/online/online_room.dart';
import 'package:perudo/online/room_transport.dart';

void main() {
  late MemoryRoomHub hub;

  HostRoom host({int color = 0}) => HostRoom(
    transport: hub.transport('host'),
    code: 'ABCD',
    name: 'Hôte',
    color: color,
    pace: TablePace.instant,
    random: Random(7),
  )..open();

  GuestRoom guest(String id, {int color = 0, String code = 'ABCD'}) =>
      GuestRoom(
        transport: hub.transport(id),
        code: code,
        name: id,
        color: color,
      )..open();

  setUp(() => hub = MemoryRoomHub());

  test('guests join the lobby, each with dice of a colour of their own', () {
    fakeAsync((async) {
      final h = host(color: 2);
      final a = guest('ana', color: 2);
      final b = guest('bob', color: 2);
      async.elapse(const Duration(seconds: 4));

      expect(a.status, RoomStatus.lobby);
      expect(b.lobby!.players.map((player) => player.name), [
        'Hôte',
        'ana',
        'bob',
      ]);
      expect(h.lobby!.takenColors.length, 3);
      expect(h.lobby!.players.first.color, 2);

      // A colour someone has is not given; a free one is.
      final taken = h.lobby!.players[1].color;
      b.pickColor(taken);
      b.pickColor(9);
      async.elapse(const Duration(seconds: 1));
      expect(a.lobby!.players[2].color, 9);
      expect(a.lobby!.players[1].color, taken);
    });
  });

  test('a wrong code is told apart by silence', () {
    fakeAsync((async) {
      host();
      final lost = guest('ana', code: 'WXYZ');
      async.elapse(const Duration(seconds: 20));
      expect(lost.status, RoomStatus.refused);
      expect(lost.refusal, 'unknown');
    });
  });

  test('the host seats people and bots as around their own table', () {
    fakeAsync((async) {
      final h = host();
      final guests = [guest('ana'), guest('bob')];
      async.elapse(const Duration(seconds: 4));
      h.setBots(2);
      List<String?> table(OnlineRoom room) => [
        for (final seat in room.lobby!.seats) seat?.name,
      ];
      expect(table(h), ['Hôte', 'ana', 'bob', null, null]);

      // A bot between the host and ana, bob last.
      h.reorder(3, 1);
      h.reorder(3, 4);
      // The host stays first, and nobody leaves the table.
      h.reorder(0, 2);
      h.reorder(2, 0);
      h.reorder(1, 9);
      async.elapse(const Duration(seconds: 1));
      for (final room in <OnlineRoom>[h, ...guests]) {
        expect(table(room), ['Hôte', null, 'ana', null, 'bob']);
      }

      // One bot less is the last one; whoever comes sits at the end.
      h.setBots(1);
      final cleo = guest('cleo');
      async.elapse(const Duration(seconds: 4));
      expect(table(cleo), ['Hôte', null, 'ana', 'bob', 'cleo']);

      h.start();
      async.elapse(const Duration(seconds: 1));
      for (final room in <OnlineRoom>[h, ...guests, cleo]) {
        final seats = room.snapshot.value!.seats;
        expect(
          [for (final seat in seats) seat.isBot ? null : seat.name],
          ['Hôte', null, 'ana', 'bob', 'cleo'],
        );
      }
      expect(guests[1].snapshot.value!.you, 3);
    });
  });

  test('a quick game deals the dice the host chose', () {
    fakeAsync((async) {
      final h = host();
      final ana = guest('ana');
      async.elapse(const Duration(seconds: 4));
      h.setDice(2);
      async.elapse(const Duration(seconds: 1));
      expect(ana.lobby!.dice, 2);
      h.setDice(0);
      expect(h.lobby!.dice, GameOptions.minDice);
      h.setDice(2);
      h.start();
      async.elapse(const Duration(seconds: 1));

      for (final room in <OnlineRoom>[h, ana]) {
        final view = room.snapshot.value!.view;
        expect(view.options.startDice, 2);
        expect(view.myDice.length, 2);
        expect(view.totalDice, 4);
      }
    });
  });

  test('a whole game is played across phones, bots included', () {
    fakeAsync((async) {
      final h = host();
      final guests = [guest('ana'), guest('bob')];
      async.elapse(const Duration(seconds: 4));
      h.setBots(2);
      h.start();
      async.elapse(const Duration(seconds: 1));

      final rooms = <OnlineRoom>[h, ...guests];
      for (final room in rooms) {
        expect(room.status, RoomStatus.playing);
        expect(room.snapshot.value!.seats.length, 5);
        expect(
          {for (final seat in room.snapshot.value!.seats) seat.color}.length,
          5,
        );
      }
      expect({for (final room in rooms) room.snapshot.value!.you}.length, 3);

      // Each person plays as a bot would, from what their own phone shows.
      final bot = PerudoBot(BotLevel.normal, Random(1));
      for (var step = 0; step < 4000; step++) {
        if (h.snapshot.value!.view.phase == Phase.finished) break;
        for (final room in rooms) {
          final snapshot = room.snapshot.value!;
          if (snapshot.myTurn) {
            room.act(bot.decide(snapshot.view));
          } else if (snapshot.view.phase == Phase.reveal &&
              !snapshot.ready.contains(snapshot.you)) {
            expect(snapshot.view.result!.dice.length, 5);
            room.act(const ReadyAction());
          }
        }
        async.elapse(const Duration(milliseconds: 200));
      }
      final winner = h.snapshot.value!.view.winner;
      expect(winner, isNotNull);
      for (final room in guests) {
        expect(room.snapshot.value!.view.winner, winner);
        expect(room.snapshot.value!.game, 1);
      }

      h.rematch();
      async.elapse(const Duration(seconds: 1));
      expect(guests.first.snapshot.value!.game, 2);
      expect(guests.first.snapshot.value!.view.phase, Phase.bidding);
    });
  });

  test('a guest only ever receives their own dice', () {
    fakeAsync((async) {
      final h = host();
      final a = guest('ana');
      async.elapse(const Duration(seconds: 4));
      h.start();
      async.elapse(const Duration(seconds: 1));
      final mine = a.snapshot.value!;
      expect(mine.view.myDice.length, 5);
      expect(mine.view.result, isNull);
      expect(mine.toJson().toString(), isNot(contains('dice:')));
    });
  });

  test('what a guest does is sent again when it was lost', () {
    fakeAsync((async) {
      final transport = hub.transport('ana');
      final h = host();
      final a = GuestRoom(
        transport: transport,
        code: 'ABCD',
        name: 'ana',
        color: 1,
      )..open();
      async.elapse(const Duration(seconds: 4));
      h.start();
      async.elapse(const Duration(seconds: 1));
      // Make it the guest's turn, whoever opens.
      if (!a.snapshot.value!.myTurn) {
        h.act(const BidAction(Bid(1, 2)));
        async.elapse(const Duration(seconds: 1));
      }
      expect(a.snapshot.value!.myTurn, isTrue);
      final before = a.snapshot.value!.view.history.length;
      transport.dropOutgoing = true;
      a.act(const BidAction(Bid(3, 6)));
      async.elapse(const Duration(seconds: 1));
      expect(h.snapshot.value!.view.history.length, before);
      transport.dropOutgoing = false;
      async.elapse(const Duration(seconds: 4));
      expect(h.snapshot.value!.view.history.length, before + 1);
      expect(a.snapshot.value!.myTurn, isFalse);
    });
  });

  test('a guest who goes silent is played by a bot, and may come back', () {
    fakeAsync((async) {
      final h = host();
      final transport = hub.transport('ana');
      final a = GuestRoom(
        transport: transport,
        code: 'ABCD',
        name: 'ana',
        color: 1,
      )..open();
      async.elapse(const Duration(seconds: 4));
      h.start();
      async.elapse(const Duration(seconds: 1));
      final seat = a.snapshot.value!.you;

      transport.dropOutgoing = true;
      async.elapse(const Duration(seconds: 20));
      expect(h.snapshot.value!.seats[seat].away, isTrue);

      transport.dropOutgoing = false;
      async.elapse(const Duration(seconds: 4));
      expect(h.snapshot.value!.seats[seat].away, isFalse);
      expect(a.snapshot.value!.seats[seat].away, isFalse);
    });
  });

  test('late comers and a closed room are told so', () {
    fakeAsync((async) {
      final h = host();
      final a = guest('ana');
      async.elapse(const Duration(seconds: 4));
      h.start();
      async.elapse(const Duration(seconds: 1));
      final late = guest('zoe');
      async.elapse(const Duration(seconds: 4));
      expect(late.status, RoomStatus.refused);
      expect(late.refusal, 'started');

      h.leave();
      async.elapse(const Duration(seconds: 1));
      expect(a.status, RoomStatus.closed);
    });
  });
}
