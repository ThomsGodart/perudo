import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perudo/app.dart';
import 'package:perudo/engine/engine.dart';
import 'package:perudo/game/table.dart';
import 'package:perudo/game/table_screen.dart';
import 'package:perudo/online/online_room.dart';
import 'package:perudo/online/online_screens.dart';
import 'package:perudo/online/room_transport.dart';
import 'package:perudo/settings/app_settings.dart';
import 'package:perudo/theme/tokens.dart';

/// A feed the test moves by hand.
class StubFeed implements TableFeed {
  StubFeed(TableSnapshot first) : snapshot = ValueNotifier(first);

  @override
  final ValueNotifier<TableSnapshot?> snapshot;
  final List<TableAction> actions = [];

  @override
  void act(TableAction action) => actions.add(action);
}

TableSnapshot snap({
  int players = 4,
  int you = 0,
  int round = 1,
  int current = 0,
  bool palifico = false,
  Phase phase = Phase.bidding,
  List<BidEntry> history = const [],
  List<int>? counts,
  RoundResult? result,
  int? winner,
}) => TableSnapshot(
  game: 1,
  you: you,
  ready: const {},
  seats: [
    for (var seat = 0; seat < players; seat++)
      SeatInfo(
        name: seat == you ? 'Thomas' : 'Bot$seat',
        color: seat,
        isBot: seat != you,
      ),
  ],
  view: GameView(
    options: GameOptions(players: players),
    round: round,
    phase: phase,
    palifico: palifico,
    current: current,
    counts: counts ?? List.filled(players, 5),
    history: history,
    myDice: const [1, 2, 2, 5, 6],
    result: result,
    winner: winner,
    out: const [],
  ),
);

void main() {
  profileTests();

  late AppSettings settings;

  setUp(
    () =>
        settings = AppSettings(MemorySettingsStore())
          ..update(reduceMotion: true),
  );

  Future<StubFeed> pumpTable(WidgetTester tester, TableSnapshot first) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final feed = StubFeed(first);
    await tester.pumpWidget(
      MaterialApp(
        theme: Tokens.theme(),
        home: TableScreen(feed: feed, settings: settings),
      ),
    );
    await tester.pump();
    return feed;
  }

  testWidgets('a solo game starts from the home screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(PerudoApp(settings: settings, transports: null));
    await tester.tap(find.byKey(const Key('home-solo')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('solo-bots')),
        matching: find.text('5'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('solo-dice')),
        matching: find.text('3'),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.startDice, 3);
    await tester.tap(find.byKey(const Key('solo-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Manche 1'), findsOneWidget);
    for (var seat = 0; seat < 6; seat++) {
      expect(find.byKey(Key('seat-$seat')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    // Leave, so that no bot is left thinking.
    await tester.tap(find.byKey(const Key('table-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-solo')), findsOneWidget);
  });

  testWidgets('the player raises, doubts, or calls calza on their turn', (
    tester,
  ) async {
    final feed = await pumpTable(
      tester,
      snap(current: 0, history: const [BidEntry(3, Bid(4, 5))]),
    );
    expect(find.byKey(const Key('standing-bid')), findsOneWidget);
    expect(find.byKey(const Key('seat-bid-3')), findsOneWidget);
    // Starts on the cheapest raise of the face being bid.
    expect(find.text('5'), findsWidgets);
    await tester.tap(find.byKey(const Key('bid-face-1')));
    await tester.pump();
    // Changing the face keeps the count already chosen.
    expect(tester.widget<Text>(find.byKey(const Key('bid-count'))).data, '5');
    await tester.tap(find.byKey(const Key('bid-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bid-confirm')));
    await tester.tap(find.byKey(const Key('dudo')));
    await tester.tap(find.byKey(const Key('calza')));
    expect(feed.actions.map((action) => action.toJson()), [
      const BidAction(Bid(6, 1)).toJson(),
      const DudoAction().toJson(),
      const CalzaAction().toJson(),
    ]);
  });

  testWidgets('the cup hides the dice until it is touched', (tester) async {
    await pumpTable(tester, snap(current: 1));
    // Shown for a moment after the roll, then covered.
    expect(find.byKey(const Key('my-dice')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('my-dice')), findsNothing);
    expect(find.byKey(const Key('cup-hint')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-dice')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-dice')), findsNothing);

    settings.update(cupAlwaysUp: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-dice')), findsOneWidget);
  });

  testWidgets('preferences decide which counts are shown', (tester) async {
    await pumpTable(tester, snap(current: 1, counts: [5, 3, 0, 4]));
    expect(find.text('12 dés en jeu · 8 éliminés'), findsOneWidget);
    expect(find.byKey(const Key('seat-count-1')), findsOneWidget);
    expect(find.byKey(const Key('seat-count-2')), findsNothing);
    expect(find.byKey(const Key('palifico-banner')), findsNothing);

    settings.update(showDiceTally: false, showOpponentDice: false);
    await tester.pump();
    expect(find.byKey(const Key('dice-tally')), findsNothing);
    expect(find.byKey(const Key('seat-count-1')), findsNothing);
    expect(find.byKey(const Key('seat-count-0')), findsOneWidget);
  });

  testWidgets('a palifico round says so', (tester) async {
    await pumpTable(tester, snap(current: 1, palifico: true));
    expect(find.byKey(const Key('palifico-banner')), findsOneWidget);
    expect(find.textContaining('pacos ne sont pas des jokers'), findsOneWidget);
  });

  testWidgets('the result lifts every cup, then the game ends', (tester) async {
    const result = RoundResult(
      kind: Challenge.dudo,
      caller: 0,
      bidder: 3,
      bid: Bid(9, 5),
      actual: 7,
      wild: true,
      seat: 3,
      delta: -1,
      dice: [
        [1, 2, 2, 5, 6],
        [1, 5, 5, 6, 6],
        [3, 4, 5, 5, 6],
        [1, 2, 3, 4, 4],
        [2, 3, 3, 6, 6],
        [1, 1, 4, 5, 6],
      ],
    );
    final feed = await pumpTable(
      tester,
      snap(
        players: 6,
        phase: Phase.reveal,
        history: const [BidEntry(3, Bid(9, 5))],
        counts: [5, 5, 5, 4, 5, 5],
        result: result,
      ),
    );
    expect(find.text('Thomas doute de Bot3'), findsOneWidget);
    expect(find.text('Bot3 perd un dé'), findsOneWidget);
    for (var seat = 0; seat < 6; seat++) {
      expect(find.byKey(Key('seat-dice-$seat')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('result-next')));
    expect(feed.actions.single, isA<ReadyAction>());

    feed.snapshot.value = snap(
      players: 6,
      current: 2,
      round: 2,
      palifico: true,
      history: const [BidEntry(0, Bid(2, 3)), BidEntry(1, Bid(3, 3))],
      counts: [5, 1, 5, 4, 0, 2],
    );
    await tester.pump();

    feed.snapshot.value = snap(
      players: 6,
      round: 3,
      history: const [BidEntry(5, Bid(3, 4))],
    );
    await tester.pump();

    feed.snapshot.value = snap(
      phase: Phase.finished,
      winner: 0,
      counts: [2, 0, 0, 0],
    );
    await tester.pump();
    expect(find.text('Tu gagnes la partie !'), findsOneWidget);
    expect(find.byKey(const Key('play-again')), findsNothing);
  });

  testWidgets('two phones meet in a room and reach the table', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hub = MemoryRoomHub();
    settings.setProfile(name: 'Thomas', color: 3);
    final guest = GuestRoom(
      transport: hub.transport('ana'),
      code: 'ABCD',
      name: 'Ana',
      color: 3,
    );
    final host = HostRoom(
      transport: hub.transport('host'),
      code: 'ABCD',
      name: 'Thomas',
      color: 3,
      pace: TablePace.instant,
      random: Random(5),
    );
    await host.open();
    await tester.pumpWidget(
      MaterialApp(
        theme: Tokens.theme(),
        home: RoomScreen(room: host, settings: settings),
      ),
    );
    await guest.open();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('ABCD'), findsOneWidget);
    expect(find.byKey(const Key('online-player-ana')), findsOneWidget);
    expect(host.lobby!.takenColors.length, 2);
    await tester.tap(find.byKey(const Key('online-bots-plus')));
    await tester.pump();

    guest.chat.send('Salut 🎲', fromName: 'Ana');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Salut 🎲'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('online-start')));
    await tester.tap(find.byKey(const Key('online-start')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.byType(TableScreen), findsOneWidget);
    expect(find.byKey(const Key('table-chat')), findsOneWidget);
    expect(guest.status, RoomStatus.playing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    unawaited(guest.leave());
    await tester.pump(const Duration(seconds: 1));
  });
}

// Kept apart from the widget tests above: the profile's own rules.
void profileTests() {
  test('a name is drawn at first launch and « Toi » is never kept', () {
    final store = MemorySettingsStore();
    final first = AppSettings(store);
    expect(AppSettings.isAllowedName(first.playerName), isTrue);
    expect(AppSettings(store).playerName, first.playerName);

    first.setProfile(name: ' toi ', color: 2);
    expect(first.playerName, isNot(equalsIgnoringCase('toi')));
    expect(first.diceColor, 2);
    first.setProfile(name: 'Thomas', color: 2);
    expect(first.playerName, 'Thomas');

    // A profile saved by an earlier version is given a name too.
    final old = MemorySettingsStore()..write('name', 'Toi');
    expect(AppSettings.isAllowedName(AppSettings(old).playerName), isTrue);
  });
}
