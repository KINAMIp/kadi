import 'package:flutter/material.dart';
import '../models/kadi_player.dart';

class PlayerAvatarWidget extends StatelessWidget {
  final KadiPlayer player;
  final bool isCurrentTurn;
  final bool isLocalPlayer;

  const PlayerAvatarWidget({
    super.key,
    required this.player,
    this.isCurrentTurn = false,
    this.isLocalPlayer = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isCurrentTurn ? Colors.yellowAccent : Colors.white.withOpacity(0.8);
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 3),
          ),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: isLocalPlayer ? Colors.blueAccent : Colors.grey[700],
            child: Text(
              player.name.isNotEmpty ? player.name.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          player.name,
          style: const TextStyle(fontSize: 14),
        ),
        if (!isLocalPlayer)
          Text("${player.hand.length} cards",
          Text(
            "${player.hand.length} cards",
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
      ],
    );
  }
}