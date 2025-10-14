import 'package:flutter/material.dart';

import '../../models/kadi_card.dart';

class KadiCardWidget extends StatelessWidget {
  final KadiCard card;
  final bool faceUp;
  final VoidCallback? onTap;

  const KadiCardWidget({
    super.key,
    required this.card,
    this.faceUp = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = faceUp ? CardAssets.assetFor(card) : CardAssets.back;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black26),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
