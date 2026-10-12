import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/strings.dart';

/// The rules of the game, as the app plays them.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(Strings.rules)),
    body: ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        for (final (title, body) in Strings.rulesSections) ...[
          Text(
            title,
            style: const TextStyle(
              color: Tokens.gold,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Tokens.space1),
          Text(
            body,
            style: const TextStyle(
              color: Tokens.text,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: Tokens.space4),
        ],
      ],
    ),
  );
}
