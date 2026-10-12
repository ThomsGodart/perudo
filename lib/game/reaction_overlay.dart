import 'dart:async';

import 'package:flutter/material.dart';

import '../online/room_chat.dart';
import '../theme/tokens.dart';

/// Shows each reaction over the table for a moment, with who pulled it,
/// then lets it go. Taps go through to the table underneath.
class ReactionOverlay extends StatefulWidget {
  const ReactionOverlay({
    super.key,
    required this.reactions,
    this.animate = true,
    this.lasts = const Duration(milliseconds: 2500),
  });

  final Stream<Reaction> reactions;

  /// Whether a reaction pops in; it just appears otherwise.
  final bool animate;

  /// How long a reaction stays on screen.
  final Duration lasts;

  @override
  State<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<ReactionOverlay> {
  /// The reactions on screen, the oldest first, each with a number of its
  /// own so the same face pulled twice shows twice.
  final List<(int, Reaction)> _shown = [];
  final List<Timer> _timers = [];
  StreamSubscription<Reaction>? _subscription;
  int _count = 0;

  /// More than this at once would hide the table.
  static const _atMost = 4;

  @override
  void initState() {
    super.initState();
    _subscription = widget.reactions.listen(_show);
  }

  void _show(Reaction reaction) {
    final entry = (_count++, reaction);
    setState(() {
      _shown.add(entry);
      if (_shown.length > _atMost) _shown.removeAt(0);
    });
    _timers.add(
      Timer(widget.lasts, () {
        if (mounted) setState(() => _shown.remove(entry));
      }),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: Tokens.space3,
          children: [
            for (final (number, reaction) in _shown) _bubble(number, reaction),
          ],
        ),
      ),
    ),
  );

  Widget _bubble(int number, Reaction reaction) {
    final bubble = Container(
      key: Key('reaction-shown-$number'),
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space3,
        vertical: Tokens.space2,
      ),
      decoration: BoxDecoration(
        color: Tokens.panelRaised,
        borderRadius: BorderRadius.circular(Tokens.radiusButton),
        border: Border.all(color: Tokens.gold),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(reaction.emoji, style: const TextStyle(fontSize: 44)),
          Text(
            reaction.fromName,
            style: const TextStyle(
              color: Tokens.gold,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (!widget.animate) return bubble;
    // Pops in a little too large, then settles.
    return TweenAnimationBuilder<double>(
      key: ValueKey(number),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      builder: (context, progress, child) => Opacity(
        opacity: progress.clamp(0, 1),
        child: Transform.scale(scale: progress, child: child),
      ),
      child: bubble,
    );
  }
}
