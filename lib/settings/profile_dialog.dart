import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/dice.dart';
import '../ui/strings.dart';
import 'app_settings.dart';

/// Lets the player choose their name and the colour of their dice.
class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  late final _name = TextEditingController(text: widget.settings.playerName);
  late int _color = widget.settings.diceColor;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (!AppSettings.isAllowedName(name)) {
      setState(() => _error = Strings.nameRequired);
      return;
    }
    widget.settings.setProfile(name: name, color: _color);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(Strings.profileTitle),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('profile-name'),
          controller: _name,
          maxLength: AppSettings.maxNameLength,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: Strings.playerNameLabel,
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: Tokens.space2),
        const Text(Strings.diceColorLabel),
        const SizedBox(height: Tokens.space2),
        DiceColorPicker(
          selected: _color,
          onPick: (color) => setState(() => _color = color),
        ),
        const SizedBox(height: Tokens.space3),
        const Text(
          Strings.diceColorNote,
          style: TextStyle(color: Tokens.mutedText, fontSize: 13),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text(Strings.cancel),
      ),
      FilledButton(
        key: const Key('profile-save'),
        onPressed: _save,
        child: const Text(Strings.save),
      ),
    ],
  );
}

/// The dice colours to choose from, each shown as a die. Those in [taken]
/// belong to someone else and cannot be picked.
class DiceColorPicker extends StatelessWidget {
  const DiceColorPicker({
    super.key,
    required this.selected,
    required this.onPick,
    this.taken = const {},
  });

  final int selected;
  final Set<int> taken;
  final void Function(int color) onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Tokens.space1,
    runSpacing: Tokens.space1,
    children: [
      for (final (index, color) in Tokens.diceColors.indexed)
        Tooltip(
          message: Tokens.diceColorNames[index],
          child: InkWell(
            key: Key('dice-color-$index'),
            borderRadius: BorderRadius.circular(12),
            onTap: taken.contains(index) && index != selected
                ? null
                : () => onPick(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: index == selected ? Tokens.gold : Colors.transparent,
                  width: 3,
                ),
              ),
              child: DieView(
                face: 5,
                color: color,
                size: 36,
                dimmed: taken.contains(index) && index != selected,
              ),
            ),
          ),
        ),
    ],
  );
}
