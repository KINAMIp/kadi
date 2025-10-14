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
    final borderColor =
        faceUp ? (card.isJoker ? Colors.deepPurple : _suitColor(card.suit)) : Colors.blueGrey.shade700;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 92,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: faceUp ? Colors.white : Colors.blueGrey,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black26)],
          border: Border.all(color: borderColor, width: 2),
        ),
        child: faceUp
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.rank.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _suitSymbol(card.suit),
                      style: TextStyle(fontSize: 22, color: borderColor),
                    ),
                  ),
                ],
              )
            : Center(child: Text('KADI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ),
    );
}
}

Color _suitColor(Suit suit) {
  switch (suit) {
    case Suit.hearts:
    case Suit.diamonds:
      return Colors.red.shade400;
    case Suit.clubs:
    case Suit.spades:
      return Colors.black87;
    case Suit.joker:
      return Colors.deepPurple;
  }
}

String _suitSymbol(Suit suit) {
  switch (suit) {
    case Suit.hearts:
      return '♥';
    case Suit.diamonds:
      return '♦';
    case Suit.clubs:
      return '♣';
    case Suit.spades:
      return '♠';
    case Suit.joker:
      return '🃏';
  }
}