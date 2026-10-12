import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/dice.dart';
import '../ui/strings.dart';

/// The player's own cup and dice. Each new roll shakes the cup, shows the
/// dice for a moment, then covers them again: a tap on the cup lifts it.
class CupTray extends StatefulWidget {
  const CupTray({
    super.key,
    required this.dice,
    required this.color,
    required this.rollKey,
    this.alwaysUp = false,
    this.revealed = false,
    this.animate = true,
  });

  final List<int> dice;
  final Color color;

  /// Changes with every roll.
  final Object rollKey;

  /// The player would rather keep their dice in sight.
  final bool alwaysUp;

  /// Every cup is lifted: the round is over.
  final bool revealed;
  final bool animate;

  /// How long the dice stay in sight after a roll.
  static const glimpse = Duration(milliseconds: 3200);

  @override
  State<CupTray> createState() => _CupTrayState();
}

class _CupTrayState extends State<CupTray> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _lifted = false;

  /// True until the cup is touched: only freshly rolled dice tumble.
  bool _fresh = true;
  Timer? _cover;

  bool get _up => _lifted || widget.alwaysUp || widget.revealed;

  @override
  void initState() {
    super.initState();
    _shake.addStatusListener((status) {
      if (status == AnimationStatus.completed) _showThenCover();
    });
    _roll();
  }

  @override
  void didUpdateWidget(CupTray old) {
    super.didUpdateWidget(old);
    if (old.rollKey != widget.rollKey) _roll();
  }

  void _roll() {
    _cover?.cancel();
    _fresh = true;
    if (!widget.animate) {
      _showThenCover();
      return;
    }
    _lifted = false;
    _shake.forward(from: 0);
  }

  void _showThenCover() {
    if (!mounted) return;
    setState(() => _lifted = true);
    _cover?.cancel();
    _cover = Timer(CupTray.glimpse, () {
      if (mounted) setState(() => _lifted = false);
    });
  }

  void _toggle() {
    if (_shake.isAnimating) return;
    _cover?.cancel();
    setState(() {
      _fresh = false;
      _lifted = !_lifted;
    });
  }

  @override
  void dispose() {
    _cover?.cancel();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final up = _up && !_shake.isAnimating;
    final cup = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final progress = _shake.value;
        final swing = _shake.isAnimating
            ? sin(progress * pi * 10) * (1 - progress * 0.5)
            : 0.0;
        return Transform.translate(
          offset: Offset(swing * 7, 0),
          child: Transform.rotate(angle: swing * 0.2, child: child),
        );
      },
      child: AnimatedSlide(
        offset: up ? const Offset(-0.08, -0.14) : Offset.zero,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: AnimatedRotation(
          turns: up ? -0.09 : 0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          child: CupView(color: widget.color, size: 78),
        ),
      ),
    );
    return SizedBox(
      height: 92,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: up ? Strings.tapCupHide : Strings.tapCup,
            child: GestureDetector(
              key: const Key('cup'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.alwaysUp || widget.revealed ? null : _toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space2),
                child: cup,
              ),
            ),
          ),
          const SizedBox(width: Tokens.space2),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: up
                  ? FittedBox(
                      key: const Key('my-dice'),
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (index, face) in widget.dice.indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: RollingDie(
                                face: face,
                                color: widget.color,
                                rollKey: widget.rollKey,
                                delay: Duration(milliseconds: 110 * index),
                                animate: widget.animate && _fresh,
                              ),
                            ),
                        ],
                      ),
                    )
                  : Text(
                      _shake.isAnimating ? '' : Strings.tapCup,
                      key: const Key('cup-hint'),
                      style: const TextStyle(
                        color: Tokens.mutedText,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
