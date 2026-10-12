import 'dart:math';

import 'package:flutter/material.dart';

import '../bots/bot.dart';
import '../engine/engine.dart';
import '../game/table.dart';
import '../game/table_screen.dart';
import '../online/online_room.dart';
import '../online/online_screens.dart';
import '../online/room_transport.dart';
import '../rules/rules_screen.dart';
import '../settings/app_settings.dart';
import '../settings/profile_dialog.dart';
import '../settings/settings_screen.dart';
import '../theme/tokens.dart';
import '../ui/dice.dart';
import '../ui/strings.dart';

/// The first screen: play against bots, play online, and the profile.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.transports,
  });

  final AppSettings settings;

  /// How this phone reaches online rooms, or null in a build without them.
  final TransportFactory? transports;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppSettings get _settings => widget.settings;

  void _open(Widget screen) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (context) => screen),
  );

  Future<void> _setUpSolo() async {
    final start = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Tokens.panel,
      isScrollControlled: true,
      builder: (context) => _SoloSetup(settings: _settings),
    );
    if (start == true && mounted) _playSolo();
  }

  /// Deals a game against bots, each with dice of a colour of its own.
  void _playSolo({bool replace = false}) {
    final random = Random();
    final colors = [
      for (var index = 0; index < Tokens.diceColors.length; index++)
        if (index != _settings.diceColor) index,
    ]..shuffle(random);
    final names = List.of(botNames)..shuffle(random);
    final seats = [
      SeatInfo(name: _settings.playerName, color: _settings.diceColor),
      for (var bot = 0; bot < _settings.soloBots; bot++)
        SeatInfo(name: names[bot], color: colors[bot], isBot: true),
    ];
    final route = MaterialPageRoute<void>(
      builder: (context) => _SoloTable(
        settings: _settings,
        table: GameTable(
          seats: seats,
          options: GameOptions(
            players: seats.length,
            startDice: _settings.startDice,
            calza: _settings.calza,
          ),
          botLevel: _settings.botLevel,
          pace: _settings.pace,
          random: random,
        ),
        onPlayAgain: () => _playSolo(replace: true),
      ),
    );
    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          final color = Tokens.dice(_settings.diceColor);
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Tokens.space6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final face in const [1, 5, 3])
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: DieView(face: face, color: color, size: 46),
                          ),
                      ],
                    ),
                    const SizedBox(height: Tokens.space3),
                    const Text(
                      Strings.appTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Tokens.gold,
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const Text(
                      Strings.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Tokens.mutedText, fontSize: 16),
                    ),
                    const SizedBox(height: Tokens.space6),
                    Center(
                      child: ActionChip(
                        key: const Key('home-profile'),
                        avatar: DieView(face: 5, color: color, size: 22),
                        label: Text(_settings.playerName),
                        onPressed: () => showDialog<bool>(
                          context: context,
                          builder: (context) =>
                              ProfileDialog(settings: _settings),
                        ),
                      ),
                    ),
                    const SizedBox(height: Tokens.space6),
                    FilledButton.icon(
                      key: const Key('home-solo'),
                      onPressed: _setUpSolo,
                      icon: const Icon(Icons.smart_toy_outlined),
                      label: const Text(Strings.playSolo),
                    ),
                    const SizedBox(height: Tokens.space3),
                    FilledButton.tonalIcon(
                      key: const Key('home-online'),
                      onPressed: () => _open(
                        OnlineHomeScreen(
                          settings: _settings,
                          transports: widget.transports,
                        ),
                      ),
                      icon: const Icon(Icons.public),
                      label: const Text(Strings.playOnline),
                    ),
                    const SizedBox(height: Tokens.space4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('home-rules'),
                            onPressed: () => _open(const RulesScreen()),
                            child: const Text(Strings.rules),
                          ),
                        ),
                        const SizedBox(width: Tokens.space3),
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('home-settings'),
                            onPressed: () =>
                                _open(SettingsScreen(settings: _settings)),
                            child: const Text(Strings.settings),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// How many bots, how good, how many dice, and with or without Calza.
class _SoloSetup extends StatelessWidget {
  const _SoloSetup({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              Strings.soloTitle,
              style: TextStyle(
                color: Tokens.gold,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Tokens.space4),
            const Text(Strings.botCount),
            const SizedBox(height: Tokens.space2),
            SegmentedButton<int>(
              key: const Key('solo-bots'),
              showSelectedIcon: false,
              segments: [
                for (var bots = 1; bots < GameOptions.maxPlayers; bots++)
                  ButtonSegment(value: bots, label: Text('$bots')),
              ],
              selected: {settings.soloBots},
              onSelectionChanged: (picked) =>
                  settings.update(soloBots: picked.first),
            ),
            const SizedBox(height: Tokens.space4),
            const Text(Strings.botLevelLabel),
            const SizedBox(height: Tokens.space2),
            SegmentedButton<BotLevel>(
              key: const Key('solo-level'),
              showSelectedIcon: false,
              segments: [
                for (final level in BotLevel.values)
                  ButtonSegment(
                    value: level,
                    label: Text(Strings.botLevel(level)),
                  ),
              ],
              selected: {settings.botLevel},
              onSelectionChanged: (picked) =>
                  settings.update(botLevel: picked.first),
            ),
            const SizedBox(height: Tokens.space4),
            const Text(Strings.diceCount),
            const SizedBox(height: Tokens.space2),
            SegmentedButton<int>(
              key: const Key('solo-dice'),
              showSelectedIcon: false,
              segments: [
                for (
                  var dice = GameOptions.minDice;
                  dice <= GameOptions.maxDice;
                  dice++
                )
                  ButtonSegment(value: dice, label: Text('$dice')),
              ],
              selected: {settings.startDice},
              onSelectionChanged: (picked) =>
                  settings.update(startDice: picked.first),
            ),
            const SizedBox(height: Tokens.space2),
            const Text(
              Strings.diceCountNote,
              style: TextStyle(color: Tokens.mutedText, fontSize: 13),
            ),
            const SizedBox(height: Tokens.space2),
            SwitchListTile(
              key: const Key('solo-calza'),
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.calzaOption),
              subtitle: const Text(Strings.calzaOptionNote),
              value: settings.calza,
              onChanged: (value) => settings.update(calza: value),
            ),
            const SizedBox(height: Tokens.space3),
            FilledButton(
              key: const Key('solo-start'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(Strings.start),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A table played on this phone; the game ends with the screen.
class _SoloTable extends StatefulWidget {
  const _SoloTable({
    required this.settings,
    required this.table,
    required this.onPlayAgain,
  });

  final AppSettings settings;
  final GameTable table;
  final VoidCallback onPlayAgain;

  @override
  State<_SoloTable> createState() => _SoloTableState();
}

class _SoloTableState extends State<_SoloTable> {
  late final _feed = LocalTableFeed(widget.table);

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TableScreen(
    feed: _feed,
    settings: widget.settings,
    onPlayAgain: widget.onPlayAgain,
  );
}
