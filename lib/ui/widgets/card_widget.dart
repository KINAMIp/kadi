import 'package:flutter/material.dart';
import '../../models/card_model.dart';

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
    final color = faceUp ? (card.isJoker ? Colors.deepPurple : card.suitColor) : Colors.blueGrey.shade700;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 92,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: faceUp ? Colors.white : Colors.blueGrey,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0,2), color: Colors.black26)],
          border: Border.all(color: color, width: 2),
        ),
        child: faceUp
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.rank, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(card.suitSymbol, style: TextStyle(fontSize: 22, color: color)),
                  )
                ],
              )
            : Center(child: Text('KADI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ),
    );
  }
}