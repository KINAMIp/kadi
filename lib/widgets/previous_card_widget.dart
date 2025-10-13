import 'package:flutter/material.dart';
import '../models/kadi_card.dart';
import '../utils/layout.dart';

class PreviousCardsWidget extends StatelessWidget {
  final List<KadiCard> discardPile;

  const PreviousCardsWidget({super.key, required this.discardPile});

  @override
  Widget build(BuildContext context) {
    final lastThree = discardPile.length <= 3
        ? List<KadiCard>.from(discardPile)
        : discardPile.sublist(discardPile.length - 3);

    return SizedBox(
      width: Layout.cardWidth * 1.8,
      height: Layout.cardHeight + 12,
      child: Stack(
        children: [
          for (int i = 0; i < lastThree.length; i++)
            Positioned(
              left: i * 16,
              top: i * 6,
              child: Opacity(
                opacity: i == lastThree.length - 1 ? 1 : 0.65,
                child: Container(
                  width: Layout.cardWidth,
                  height: Layout.cardHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Layout.cardRadius),
                    border: Border.all(color: Colors.black26),
                    boxShadow: const [BoxShadow(blurRadius: 6, spreadRadius: 1, color: Colors.black26)],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${lastThree[i].rank.label}\n${lastThree[i].suit.label}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}