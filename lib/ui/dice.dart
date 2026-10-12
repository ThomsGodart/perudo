import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One die, seen from above, in a player's colour. The 1 is the paco: it
/// is drawn as a star rather than a pip.
class DieView extends StatelessWidget {
  const DieView({
    super.key,
    required this.face,
    required this.color,
    this.size = 40,
    this.dimmed = false,
    this.highlighted = false,
  });

  final int face;
  final Color color;
  final double size;

  /// Faded: a die that does not count, or a face that cannot be picked.
  final bool dimmed;

  /// Ringed in gold: a die that counts for the bid.
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dimmed ? 0.42 : 1,
    child: CustomPaint(
      size: Size.square(size),
      painter: _DiePainter(face, color, highlighted),
    ),
  );
}

class _DiePainter extends CustomPainter {
  const _DiePainter(this.face, this.color, this.highlighted);

  final int face;
  final Color color;
  final bool highlighted;

  static const _spots = {
    1: <Offset>[],
    2: [Offset(-1, -1), Offset(1, 1)],
    3: [Offset(-1, -1), Offset(0, 0), Offset(1, 1)],
    4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
    5: [
      Offset(-1, -1),
      Offset(1, -1),
      Offset(0, 0),
      Offset(-1, 1),
      Offset(1, 1),
    ],
    6: [
      Offset(-1, -1),
      Offset(1, -1),
      Offset(-1, 0),
      Offset(1, 0),
      Offset(-1, 1),
      Offset(1, 1),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(side * 0.2),
    );
    canvas.drawRRect(
      body.shift(Offset(0, side * 0.05)),
      Paint()..color = Colors.black38,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.22)!,
            color,
            Color.lerp(color, Colors.black, 0.22)!,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      body.deflate(side * 0.02),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? side * 0.09 : side * 0.04
        ..color = highlighted ? Tokens.gold : Colors.black26,
    );
    final ink = Paint()..color = Tokens.on(color);
    final center = size.center(Offset.zero);
    if (face == 1) {
      canvas.drawPath(_star(center, side * 0.3), ink);
      return;
    }
    for (final spot in _spots[face] ?? const <Offset>[]) {
      canvas.drawCircle(center + spot * (side * 0.26), side * 0.09, ink);
    }
  }

  static Path _star(Offset center, double radius) {
    final path = Path();
    for (var point = 0; point < 10; point++) {
      final reach = point.isEven ? radius : radius * 0.45;
      final angle = -pi / 2 + point * pi / 5;
      final at = center + Offset(cos(angle), sin(angle)) * reach;
      point == 0 ? path.moveTo(at.dx, at.dy) : path.lineTo(at.dx, at.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_DiePainter old) =>
      old.face != face || old.color != color || old.highlighted != highlighted;
}

/// A die that tumbles before it settles on its face, each time [rollKey]
/// changes.
class RollingDie extends StatefulWidget {
  const RollingDie({
    super.key,
    required this.face,
    required this.color,
    required this.rollKey,
    this.size = 44,
    this.delay = Duration.zero,
    this.animate = true,
  });

  final int face;
  final Color color;
  final Object rollKey;
  final double size;

  /// How long this die keeps tumbling after the first one stopped.
  final Duration delay;
  final bool animate;

  @override
  State<RollingDie> createState() => _RollingDieState();
}

class _RollingDieState extends State<RollingDie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(vsync: this);
  final _random = Random();
  late double _spin = _random.nextDouble() * 4 - 2;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(RollingDie old) {
    super.didUpdateWidget(old);
    if (old.rollKey != widget.rollKey) _start();
  }

  void _start() {
    if (!widget.animate) {
      _roll.value = 1;
      return;
    }
    _spin = _random.nextDouble() * 4 - 2;
    _roll.duration = const Duration(milliseconds: 650) + widget.delay;
    _roll.forward(from: 0);
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _roll,
    builder: (context, _) {
      final progress = _roll.value;
      final left = 1 - Curves.easeOutCubic.transform(progress);
      // A new face every few frames while it tumbles.
      final face = progress >= 1
          ? widget.face
          : (widget.face + (progress * 14).floor()) % 6 + 1;
      return Transform.translate(
        offset: Offset(0, -sin(progress * pi * 3).abs() * 14 * left),
        child: Transform.rotate(
          angle: _spin * pi * left,
          child: DieView(face: face, color: widget.color, size: widget.size),
        ),
      );
    },
  );
}

/// A dice cup in a player's colour, mouth down.
class CupView extends StatelessWidget {
  const CupView({super.key, required this.color, this.size = 84});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CupPainter(color));
}

class _CupPainter extends CustomPainter {
  const _CupPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.27, h * 0.14)
      ..quadraticBezierTo(w * 0.5, h * 0.04, w * 0.73, h * 0.14)
      ..lineTo(w * 0.9, h * 0.84)
      ..lineTo(w * 0.1, h * 0.84)
      ..close();
    canvas.drawOval(
      Rect.fromLTRB(w * 0.06, h * 0.82, w * 0.94, h * 0.98),
      Paint()..color = Colors.black38,
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, Colors.black, 0.35)!,
            Color.lerp(color, Colors.white, 0.12)!,
            Color.lerp(color, Colors.black, 0.45)!,
          ],
          stops: const [0, 0.4, 1],
        ).createShader(Offset.zero & size),
    );
    // The stitched band and the rim, as on a leather cup.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..color = Tokens.on(color).withValues(alpha: 0.45);
    canvas.drawLine(
      Offset(w * 0.22, h * 0.34),
      Offset(w * 0.78, h * 0.34),
      seam,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.06, h * 0.8, w * 0.94, h * 0.92),
        Radius.circular(h * 0.06),
      ),
      Paint()..color = Color.lerp(color, Colors.black, 0.5)!,
    );
  }

  @override
  bool shouldRepaint(_CupPainter old) => old.color != color;
}

/// A bid written as « 4 × die ».
class BidLabel extends StatelessWidget {
  const BidLabel({
    super.key,
    required this.count,
    required this.face,
    required this.color,
    this.size = 22,
    this.textColor = Tokens.text,
  });

  final int count;
  final int face;
  final Color color;
  final double size;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$count ×',
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      SizedBox(width: size * 0.25),
      DieView(face: face, color: color, size: size),
    ],
  );
}
