import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import 'card_widget.dart';

class HandWidget extends StatelessWidget {
  final List<KadiCard> cards;
  final bool faceUp;
  final void Function(KadiCard)? onPlayTap;

  const HandWidget({
    super.key,
    required this.cards,
    this.faceUp = true,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cards.map((c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: KadiCardWidget(
              card: c,
              faceUp: faceUp,
              onTap: onPlayTap != null ? () => onPlayTap!(c) : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}