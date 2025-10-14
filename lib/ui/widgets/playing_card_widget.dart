import 'package:flutter/material.dart';
import '../../models/kadi_card.dart';
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
    final imagePath = faceUp ? CardAssets.assetFor(card) : CardAssets.back;

    return Container(
      width: Layout.cardWidth,
      height: Layout.cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Layout.cardRadius),
        boxShadow: const [
          BoxShadow(blurRadius: 6, spreadRadius: 1, offset: Offset(0, 2), color: Colors.black26),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Layout.cardRadius),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
