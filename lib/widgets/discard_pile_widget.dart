import 'package:flutter/material.dart';;

import '../models/kadi_card.dart';
import '../ui/widgets/playing_card_widget.dart';

/// Shows the last three cards slightly fanned, top-most is the actual top.
class DiscardPileWidget extends StatelessWidget {
  final List<KadiCard> cards;

  const DiscardPileWidget({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return _emptyPile();

    final visible = cards.length > 3 ? cards.sublist(cards.length - 3) : cards;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(visible.length, (i) {
          // spread them a bit
          final dx = (i - (visible.length - 1) / 2) * 18.0;
          final angle = (i - (visible.length - 1) / 2) * 0.06;
          return Transform.translate(
            offset: Offset(dx, -dx / 3),
            child: Transform.rotate(
              angle: angle,
              child: PlayingCardWidget(card: visible[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _emptyPile() => Container(
        width: 70,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.green[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white54, width: 2),
        ),
        alignment: Alignment.center,
        child: const Text(
          'No Cards',
          style: TextStyle(color: Colors.white70),
        ),
      );
}