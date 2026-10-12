import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../engine/engine.dart';
import '../online/online_room.dart';
import '../online/room_chat.dart';
import '../online/room_chat_view.dart';
import '../settings/app_settings.dart';
import '../settings/settings_screen.dart';
import '../theme/tokens.dart';
import '../ui/dice.dart';
import '../ui/strings.dart';
import 'bid_panel.dart';
import 'cup_tray.dart';
import 'reaction_overlay.dart';
import 'table.dart';

/// The table: the players in a circle in turn order, the standing bid in
/// the middle, and the player's own cup and choices underneath.
class TableScreen extends StatefulWidget {
  const TableScreen({
    super.key,
    required this.feed,
    required this.settings,
    this.room,
    this.onPlayAgain,
  });

  final TableFeed feed;
  final AppSettings settings;

  /// The online room the game is played in, if it is.
  final OnlineRoom? room;

  /// Starts another game, when this phone may decide to.
  final VoidCallback? onPlayAgain;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rattle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Object? _rolled;
  bool _wasMyTurn = false;

  AppSettings get _settings => widget.settings;
  OnlineRoom? get _room => widget.room;

  @override
  void initState() {
    super.initState();
    widget.feed.snapshot.addListener(_onSnapshot);
    _settings.addListener(_rebuild);
    _room?.addListener(_onRoom);
    // A screen that sleeps is an annoyance, never a reason to crash.
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
    _onSnapshot(first: true);
  }

  @override
  void dispose() {
    widget.feed.snapshot.removeListener(_onSnapshot);
    _settings.removeListener(_rebuild);
    _room?.removeListener(_onRoom);
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    _rattle.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onRoom() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _animate =>
      !_settings.reduceMotion && !MediaQuery.disableAnimationsOf(context);

  void _onSnapshot({bool first = false}) {
    final snapshot = widget.feed.snapshot.value;
    if (snapshot == null || !mounted) return;
    final roll = (snapshot.game, snapshot.view.round);
    if (roll != _rolled) {
      _rolled = roll;
      // Before the first frame there is no context to ask about motion.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _animate) _rattle.forward(from: 0);
      });
    }
    if (snapshot.myTurn && !_wasMyTurn) HapticFeedback.mediumImpact();
    _wasMyTurn = snapshot.myTurn;
    if (!first) setState(() {});
  }

  Future<void> _confirmLeave() async {
    final snapshot = widget.feed.snapshot.value;
    final over = snapshot == null || snapshot.view.phase == Phase.finished;
    final leave =
        over ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text(Strings.leaveTitle),
                content: Text(switch (_room) {
                  null => Strings.leaveSolo,
                  OnlineRoom(isHost: true) => Strings.leaveHost,
                  _ => Strings.leaveGuest,
                }),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(Strings.stay),
                  ),
                  FilledButton(
                    key: const Key('leave-confirm'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(Strings.quit),
                  ),
                ],
              ),
            ) ==
            true;
    if (leave && mounted) Navigator.pop(context);
  }

  void _showHistory(TableSnapshot snapshot) {
    final history = snapshot.view.history;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Tokens.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                Strings.history,
                style: TextStyle(
                  color: Tokens.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Tokens.space3),
              if (history.isEmpty)
                const Text(
                  Strings.historyEmpty,
                  style: TextStyle(color: Tokens.mutedText, fontSize: 16),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (index, entry) in history.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${index + 1}.',
                                style: const TextStyle(color: Tokens.mutedText),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                snapshot.seats[entry.seat].name,
                                style: const TextStyle(
                                  color: Tokens.text,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            BidLabel(
                              count: entry.bid.count,
                              face: entry.bid.face,
                              color: Tokens.dice(
                                snapshot.seats[entry.seat].color,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChat(RoomChat chat) {
    chat.markOpen(true);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tokens.panel,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SizedBox(
            height: 380,
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
                Expanded(child: ChatLines(chat: chat)),
                ChatInput(chat: chat, fromName: chat.selfName),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => chat.markOpen(false));
  }

  void _showReactions(RoomChat chat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Tokens.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space3),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final emoji in RoomChat.emojis)
                InkWell(
                  key: Key('reaction-$emoji'),
                  borderRadius: BorderRadius.circular(Tokens.radiusButton),
                  onTap: () {
                    chat.react(emoji, fromName: chat.selfName);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(Tokens.space2),
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.feed.snapshot.value;
    final chat = _room?.chat;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('table-leave'),
            icon: const Icon(Icons.close),
            tooltip: Strings.quit,
            onPressed: _confirmLeave,
          ),
          title: Text(
            snapshot == null
                ? Strings.appTitle
                : Strings.round(snapshot.view.round),
          ),
          actions: [
            if (snapshot != null)
              IconButton(
                key: const Key('table-history'),
                icon: const Icon(Icons.format_list_numbered),
                tooltip: Strings.history,
                onPressed: () => _showHistory(snapshot),
              ),
            if (chat != null) ...[
              IconButton(
                key: const Key('table-react'),
                icon: const Icon(Icons.emoji_emotions_outlined),
                tooltip: Strings.reactions,
                onPressed: () => _showReactions(chat),
              ),
              ListenableBuilder(
                listenable: chat,
                builder: (context, _) => IconButton(
                  key: const Key('table-chat'),
                  tooltip: Strings.chatTitle,
                  onPressed: () => _showChat(chat),
                  icon: Badge(
                    isLabelVisible: chat.unread > 0,
                    label: Text('${chat.unread}'),
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                ),
              ),
            ],
            IconButton(
              key: const Key('table-settings'),
              icon: const Icon(Icons.tune),
              tooltip: Strings.settings,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => SettingsScreen(settings: _settings),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: snapshot == null
              ? const Center(child: CircularProgressIndicator())
              : _table(snapshot, chat),
        ),
      ),
    );
  }

  Widget _table(TableSnapshot snapshot, RoomChat? chat) {
    final view = snapshot.view;
    final me = snapshot.you;
    final myColor = Tokens.dice(snapshot.seats[me].color);
    final closed = _room?.status == RoomStatus.closed;
    return Column(
      children: [
        if (view.palifico && view.phase != Phase.finished)
          const _PalificoBanner(),
        if (closed)
          const _Notice(Strings.onlineClosed)
        else if (_room?.hostPresent == false)
          const _Notice(Strings.onlineHostAway),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(52, 62, 52, 66),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          colors: [Tokens.felt, Tokens.feltDark],
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(box.maxWidth, box.maxHeight),
                        ),
                        border: Border.all(color: Tokens.wood, width: 7),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 14),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: max(box.maxWidth - 2 * _seatWidth + 16, 150),
                    height: max(box.maxHeight - 2 * _seatHeight + 8, 110),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _Centre(
                        snapshot: snapshot,
                        showTally: _settings.showDiceTally,
                        animate: _animate,
                      ),
                    ),
                  ),
                ),
                for (var seat = 0; seat < snapshot.seats.length; seat++)
                  _placed(snapshot, seat, box.biggest),
                if (chat != null)
                  ReactionOverlay(reactions: chat.reactions, animate: _animate),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            Tokens.space3,
            Tokens.space2,
            Tokens.space3,
            Tokens.space3,
          ),
          decoration: const BoxDecoration(
            color: Tokens.panel,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Tokens.radiusPanel),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (view.myDice.isEmpty && view.phase != Phase.finished)
                const SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      Strings.youAreOut,
                      style: TextStyle(color: Tokens.mutedText, fontSize: 16),
                    ),
                  ),
                )
              else if (view.myDice.isNotEmpty)
                CupTray(
                  dice: view.myDice,
                  color: myColor,
                  rollKey: (snapshot.game, view.round),
                  alwaysUp: _settings.cupAlwaysUp,
                  revealed: view.phase != Phase.bidding,
                  animate: _animate,
                ),
              SizedBox(
                height: 168,
                child: snapshot.myTurn && !closed
                    ? BidPanel(
                        key: ValueKey((
                          snapshot.game,
                          view.round,
                          view.history.length,
                        )),
                        view: view,
                        color: myColor,
                        onAction: widget.feed.act,
                      )
                    : Center(child: _status(snapshot, closed: closed)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _playAgain() {
    final room = _room;
    if (room is HostRoom) {
      room.rematch();
    } else {
      widget.onPlayAgain?.call();
    }
  }

  Widget _status(TableSnapshot snapshot, {required bool closed}) {
    final view = snapshot.view;
    if (view.phase != Phase.bidding) {
      return _Aftermath(
        snapshot: snapshot,
        onReady: closed ? null : () => widget.feed.act(const ReadyAction()),
        onPlayAgain: closed ? null : _playAgain,
        canPlayAgain: _room == null
            ? widget.onPlayAgain != null
            : _room!.isHost,
        onQuit: () => Navigator.pop(context),
      );
    }
    return Text(
      Strings.turnOf(snapshot.seats[view.current].name),
      key: const Key('table-status'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Tokens.mutedText, fontSize: 18),
    );
  }

  static const _seatWidth = 128.0;
  static const _seatHeight = 148.0;

  /// Seats go clockwise from the player's own, which sits at the bottom.
  Widget _placed(TableSnapshot snapshot, int seat, Size size) {
    final count = snapshot.seats.length;
    final steps = (seat - snapshot.you) % count;
    final angle = pi / 2 + steps * 2 * pi / count;
    // Full size wherever the table has room; smaller on a cramped screen.
    final scale = min(
      1.0,
      min(size.width / 390, size.height / 460),
    ).clamp(0.6, 1.0);
    final width = _seatWidth * scale;
    final height = _seatHeight * scale;
    final radiusX = size.width / 2 - width / 2 - 2;
    final radiusY = size.height / 2 - height / 2 - 2;
    final x = size.width / 2 + radiusX * cos(angle);
    final y = size.height / 2 + radiusY * sin(angle);
    return Positioned(
      left: x - width / 2,
      top: y - height / 2,
      width: width,
      height: height,
      child: FittedBox(
        child: SizedBox(
          width: _seatWidth,
          height: _seatHeight,
          child: _Seat(
            key: Key('seat-$seat'),
            snapshot: snapshot,
            seat: seat,
            showCount: seat == snapshot.you || _settings.showOpponentDice,
            rattle: _rattle,
            animate: _animate,
          ),
        ),
      ),
    );
  }
}

class _PalificoBanner extends StatelessWidget {
  const _PalificoBanner();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('palifico-banner'),
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: Tokens.space3),
    padding: const EdgeInsets.symmetric(
      horizontal: Tokens.space3,
      vertical: Tokens.space2,
    ),
    decoration: BoxDecoration(
      color: Tokens.danger.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(Tokens.radiusButton),
      border: Border.all(color: Tokens.danger),
    ),
    child: const Column(
      children: [
        Text(
          Strings.palificoTitle,
          style: TextStyle(
            color: Tokens.danger,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        Text(
          Strings.palificoBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: Tokens.text, fontSize: 13),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(
      Tokens.space3,
      Tokens.space1,
      Tokens.space3,
      0,
    ),
    padding: const EdgeInsets.all(Tokens.space2),
    decoration: BoxDecoration(
      color: Tokens.panelRaised,
      borderRadius: BorderRadius.circular(Tokens.radiusButton),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Tokens.gold, fontSize: 14),
    ),
  );
}

/// One player at the edge of the table: who they are, how many dice they
/// have, what they last announced, and their dice once the cups are lifted.
class _Seat extends StatelessWidget {
  const _Seat({
    super.key,
    required this.snapshot,
    required this.seat,
    required this.showCount,
    required this.rattle,
    required this.animate,
  });

  final TableSnapshot snapshot;
  final int seat;
  final bool showCount;
  final Animation<double> rattle;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final view = snapshot.view;
    final info = snapshot.seats[seat];
    final color = Tokens.dice(info.color);
    final dice = view.counts[seat];
    final result = view.result;
    // Out for good; whoever just lost their last die is still shown losing.
    final out = dice == 0 && result?.seat != seat;
    final speaking = view.phase == Phase.bidding && view.current == seat;
    final bid = view.bidOf(seat);
    final standing = view.lastBid?.seat == seat;

    final avatar = AnimatedBuilder(
      animation: rattle,
      builder: (context, child) => Transform.rotate(
        angle: rattle.isAnimating && dice > 0
            ? sin(rattle.value * pi * 10) * 0.22 * (1 - rattle.value)
            : 0,
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: out ? Tokens.panelRaised : color,
          shape: BoxShape.circle,
          border: Border.all(
            color: speaking ? Tokens.gold : Colors.black45,
            width: speaking ? 3.5 : 1.5,
          ),
          boxShadow: [
            if (speaking)
              const BoxShadow(
                color: Tokens.gold,
                blurRadius: 14,
                spreadRadius: 1,
              ),
          ],
        ),
        child: info.isBot
            ? Icon(
                Icons.smart_toy,
                size: 48,
                color: out ? Tokens.mutedText : Tokens.on(color),
              )
            : Text(
                info.name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: out ? Tokens.mutedText : Tokens.on(color),
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );

    final Widget below;
    if (result != null && result.dice[seat].isNotEmpty) {
      below = FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          key: Key('seat-dice-$seat'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final die in result.dice[seat])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _counts(die, result)
                    ? DieView(
                        face: die,
                        color: color,
                        size: 21,
                        highlighted: true,
                      )
                    : DieView(face: die, color: color, size: 21, dimmed: true),
              ),
          ],
        ),
      );
    } else if (bid != null && view.phase == Phase.bidding) {
      below = _pop(
        ValueKey(('bid', seat, bid.count, bid.face)),
        Container(
          key: Key('seat-bid-$seat'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: standing ? Tokens.gold : Tokens.panelRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: standing ? Tokens.gold : Tokens.outline),
          ),
          child: BidLabel(
            count: bid.count,
            face: bid.face,
            color: color,
            size: 22,
            textColor: standing ? Tokens.night : Tokens.mutedText,
          ),
        ),
      );
    } else {
      below = const SizedBox(height: 32);
    }

    return Opacity(
      opacity: out ? 0.55 : 1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              if (showCount && dice > 0)
                Positioned(
                  right: -14,
                  bottom: -2,
                  child: Container(
                    key: Key('seat-count-$seat'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Tokens.night,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.casino, size: 18, color: Tokens.text),
                        const SizedBox(width: 2),
                        Text(
                          '$dice',
                          style: const TextStyle(
                            color: Tokens.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            out
                ? '${info.name} · ${Strings.out}'
                : info.away
                ? '${info.name} · ${Strings.onlineAwayTag}'
                : info.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: seat == snapshot.you ? Tokens.gold : Tokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(height: 32, child: Center(child: below)),
        ],
      ),
    );
  }

  static bool _counts(int die, RoundResult result) =>
      die == result.bid.face || (result.wild && die == 1);

  Widget _pop(Key key, Widget child) => !animate
      ? child
      : TweenAnimationBuilder<double>(
          key: key,
          tween: Tween(begin: 0.4, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: child,
        );
}

/// The middle of the table: the standing bid, then how the round ended,
/// then who won.
class _Centre extends StatelessWidget {
  const _Centre({
    required this.snapshot,
    required this.showTally,
    required this.animate,
  });

  final TableSnapshot snapshot;
  final bool showTally;
  final bool animate;

  String _name(int seat) => snapshot.seats[seat].name;

  @override
  Widget build(BuildContext context) {
    final view = snapshot.view;
    return switch (view.phase) {
      Phase.bidding => _bidding(view),
      Phase.reveal => _reveal(view, view.result!),
      Phase.finished => _finished(view),
    };
  }

  Widget _tally(GameView view) => Text(
    '${Strings.diceInPlay(view.totalDice)} · ${Strings.diceLost(view.lostDice)}',
    key: const Key('dice-tally'),
    style: const TextStyle(color: Tokens.text, fontSize: 14),
  );

  Widget _bidding(GameView view) {
    final last = view.lastBid;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (last == null)
          const Text(
            Strings.noBidYet,
            style: TextStyle(color: Tokens.text, fontSize: 20),
          )
        else ...[
          BidLabel(
            key: const Key('standing-bid'),
            count: last.bid.count,
            face: last.bid.face,
            color: Tokens.dice(snapshot.seats[last.seat].color),
            size: 46,
          ),
          const SizedBox(height: 4),
          Text(
            Strings.bidBy(_name(last.seat)),
            style: const TextStyle(color: Tokens.text, fontSize: 14),
          ),
        ],
        if (showTally) ...[const SizedBox(height: 8), _tally(view)],
      ],
    );
  }

  Widget _reveal(GameView view, RoundResult result) {
    final exact = result.kind == Challenge.calza;
    final verdict = Column(
      key: const Key('round-result'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exact ? Strings.calza.toUpperCase() : Strings.dudo.toUpperCase(),
          style: TextStyle(
            color: exact ? Tokens.calza : Tokens.danger,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 6),
        BidLabel(
          count: result.bid.count,
          face: result.bid.face,
          color: Tokens.dice(snapshot.seats[result.bidder].color),
          size: 34,
        ),
        const SizedBox(height: 6),
        Text(
          Strings.actualCount(result.actual),
          key: const Key('result-actual'),
          style: const TextStyle(
            color: Tokens.gold,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (result.wild && !result.bid.isPaco)
          const Text(
            Strings.pacosIncluded,
            style: TextStyle(color: Tokens.text, fontSize: 12),
          ),
      ],
    );
    if (!animate) return verdict;
    return TweenAnimationBuilder<double>(
      key: ValueKey(('result', snapshot.game, view.round)),
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: verdict,
    );
  }

  Widget _finished(GameView view) {
    final winner = view.winner!;
    return SizedBox(
      key: const Key('game-over'),
      width: 150,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 56, color: Tokens.gold),
          Text(
            winner == snapshot.you
                ? Strings.youWin
                : Strings.wins(snapshot.seats[winner].name),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Tokens.gold,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Under the cup once the round is over: who doubted whom, what it cost,
/// and the way on to the next round or the next game.
class _Aftermath extends StatelessWidget {
  const _Aftermath({
    required this.snapshot,
    required this.onReady,
    required this.onPlayAgain,
    required this.canPlayAgain,
    required this.onQuit,
  });

  final TableSnapshot snapshot;
  final VoidCallback? onReady;
  final VoidCallback? onPlayAgain;
  final bool canPlayAgain;
  final VoidCallback onQuit;

  String _name(int seat) => snapshot.seats[seat].name;

  @override
  Widget build(BuildContext context) {
    final view = snapshot.view;
    if (view.phase == Phase.finished) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                key: const Key('game-over-quit'),
                onPressed: onQuit,
                child: const Text(Strings.quit),
              ),
              if (canPlayAgain) ...[
                const SizedBox(width: Tokens.space3),
                FilledButton(
                  key: const Key('play-again'),
                  onPressed: onPlayAgain,
                  child: const Text(Strings.playAgain),
                ),
              ],
            ],
          ),
          if (!canPlayAgain)
            const Padding(
              padding: EdgeInsets.only(top: Tokens.space2),
              child: Text(
                Strings.waitingRematch,
                style: TextStyle(color: Tokens.mutedText, fontSize: 14),
              ),
            ),
        ],
      );
    }
    final result = view.result!;
    final gone = view.counts[result.seat] == 0;
    final outcome = switch (result.delta) {
      < 0 =>
        gone
            ? Strings.eliminated(_name(result.seat))
            : Strings.losesDie(_name(result.seat)),
      > 0 => Strings.gainsDie(_name(result.seat)),
      _ => Strings.keepsDice(_name(result.seat)),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          result.kind == Challenge.calza
              ? Strings.calzaCalled(_name(result.caller))
              : Strings.dudoCalled(_name(result.caller), _name(result.bidder)),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Tokens.mutedText, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          outcome,
          key: const Key('result-outcome'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: result.delta > 0 ? Tokens.good : Tokens.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Tokens.space3),
        if (snapshot.ready.contains(snapshot.you))
          const Text(
            Strings.waitingOthers,
            style: TextStyle(color: Tokens.mutedText, fontSize: 15),
          )
        else
          FilledButton(
            key: const Key('result-next'),
            onPressed: onReady,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space6),
              child: Text(Strings.next),
            ),
          ),
      ],
    );
  }
}
