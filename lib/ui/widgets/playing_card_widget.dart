import 'package:flutter/material.dart';
import '../../models/kadi_card.dart';
import '../../utils/constants.dart';
import '../../utils/layout.dart';

class PlayingCardWidget extends StatelessWidget {
  final KadiCard card;
  final bool faceUp;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.faceUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Layout.cardWidth,
      height: Layout.cardHeight,
      decoration: BoxDecoration(
        color: faceUp ? Colors.white : AppColors.cardBack,
        borderRadius: BorderRadius.circular(Layout.cardRadius),
        border: Border.all(color: Colors.black26),
        boxShadow: const [BoxShadow(blurRadius: 6, spreadRadius: 1, color: Colors.black26)],
      ),
      alignment: Alignment.center,
      child: faceUp
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card.rank.label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 6),
                Text(card.suit.label, style: const TextStyle(fontSize: 12)),
              ],
            )
          : const Icon(Icons.style, color: Colors.white),
    );
  }
}