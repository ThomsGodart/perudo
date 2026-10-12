import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/strings.dart';
import 'app_settings.dart';

/// The player's preferences: what the table shows, and how the bots play.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(Strings.settings)),
    body: ListenableBuilder(
      listenable: settings,
      builder: (context, _) => ListView(
        children: [
          const _Heading(Strings.settingsTable),
          SwitchListTile(
            key: const Key('setting-tally'),
            title: const Text(Strings.showDiceTally),
            subtitle: const Text(Strings.showDiceTallyNote),
            value: settings.showDiceTally,
            onChanged: (value) => settings.update(showDiceTally: value),
          ),
          SwitchListTile(
            key: const Key('setting-opponent-dice'),
            title: const Text(Strings.showOpponentDice),
            subtitle: const Text(Strings.showOpponentDiceNote),
            value: settings.showOpponentDice,
            onChanged: (value) => settings.update(showOpponentDice: value),
          ),
          SwitchListTile(
            key: const Key('setting-cup-up'),
            title: const Text(Strings.cupAlwaysUp),
            subtitle: const Text(Strings.cupAlwaysUpNote),
            value: settings.cupAlwaysUp,
            onChanged: (value) => settings.update(cupAlwaysUp: value),
          ),
          SwitchListTile(
            key: const Key('setting-reduce-motion'),
            title: const Text(Strings.reduceMotion),
            value: settings.reduceMotion,
            onChanged: (value) => settings.update(reduceMotion: value),
          ),
          const _Heading(Strings.settingsGame),
          ListTile(
            title: const Text(Strings.botSpeedLabel),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: Tokens.space2),
              child: SegmentedButton<BotSpeed>(
                key: const Key('setting-bot-speed'),
                showSelectedIcon: false,
                segments: [
                  for (final speed in BotSpeed.values)
                    ButtonSegment(
                      value: speed,
                      label: Text(Strings.botSpeed(speed)),
                    ),
                ],
                selected: {settings.botSpeed},
                onSelectionChanged: (picked) =>
                    settings.update(botSpeed: picked.first),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Tokens.space4,
      Tokens.space4,
      Tokens.space4,
      Tokens.space1,
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Tokens.gold,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
