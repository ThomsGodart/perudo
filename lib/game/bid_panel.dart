import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../theme/tokens.dart';
import '../ui/dice.dart';
import '../ui/strings.dart';
import 'table.dart';

/// Where the player picks what to say on their turn: a raise, built from a
/// count and a face, or Dudo, or Calza.
class BidPanel extends StatefulWidget {
  const BidPanel({
    super.key,
    required this.view,
    required this.color,
    required this.onAction,
  });

  final GameView view;
  final Color color;
  final void Function(TableAction action) onAction;

  @override
  State<BidPanel> createState() => _BidPanelState();
}

class _BidPanelState extends State<BidPanel> {
  late int _face;
  late int _count;

  GameView get _view => widget.view;

  @override
  void initState() {
    super.initState();
    // Starts on the cheapest raise of the face being bid, or of the face
    // the player holds most of when they open.
    final faces = [
      for (var face = 1; face <= 6; face++)
        if (_view.minCount(face) != null) face,
    ];
    final last = _view.lastBid?.bid.face;
    if (faces.isEmpty) {
      _face = last ?? 2;
      _count = _view.totalDice;
      return;
    }
    int held(int face) => Rules.count(_view.myDice, face, wild: _view.wild);
    _face = last != null && faces.contains(last)
        ? last
        : faces.reduce((a, b) => held(b) > held(a) ? b : a);
    _count = _view.minCount(_face)!;
  }

  void _pick(int face) {
    final min = _view.minCount(face);
    if (min == null) return;
    // The count already chosen is kept: only a face that needs more raises it.
    setState(() {
      _face = face;
      if (_count < min) _count = min;
    });
  }

  @override
  Widget build(BuildContext context) {
    final min = _view.minCount(_face);
    final bid = Bid(_count, _face);
    final legal = _view.isLegal(bid);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var face = 1; face <= 6; face++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  key: Key('bid-face-$face'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: _view.minCount(face) == null
                      ? null
                      : () => _pick(face),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: face == _face ? Tokens.gold : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: DieView(
                      face: face,
                      color: widget.color,
                      size: 38,
                      dimmed: _view.minCount(face) == null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Tokens.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              key: const Key('bid-minus'),
              onPressed: min != null && _count > min
                  ? () => setState(() => _count--)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$_count',
                key: const Key('bid-count'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Tokens.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton.filledTonal(
              key: const Key('bid-plus'),
              onPressed: _count < _view.totalDice
                  ? () => setState(() => _count++)
                  : null,
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: Tokens.space3),
            Flexible(
              child: FilledButton(
                key: const Key('bid-confirm'),
                onPressed: legal ? () => widget.onAction(BidAction(bid)) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(Strings.bid, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: Tokens.space2),
                    BidLabel(
                      count: _count,
                      face: _face,
                      color: widget.color,
                      size: 20,
                      textColor: Tokens.night,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space2),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('dudo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Tokens.danger,
                  side: const BorderSide(color: Tokens.danger),
                ),
                onPressed: _view.canDudo
                    ? () => widget.onAction(const DudoAction())
                    : null,
                child: const Text(Strings.dudo),
              ),
            ),
            if (_view.options.calza) ...[
              const SizedBox(width: Tokens.space2),
              Expanded(
                child: OutlinedButton(
                  key: const Key('calza'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Tokens.calza,
                    side: const BorderSide(color: Tokens.calza),
                  ),
                  onPressed: _view.canCalza
                      ? () => widget.onAction(const CalzaAction())
                      : null,
                  child: const Text(Strings.calza),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
