import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kadi/services/online_service.dart';

class GameBoardScreen extends StatefulWidget {
  final String roomCode;

  const GameBoardScreen({super.key, required this.roomCode});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final OnlineService _svc = OnlineService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade800,
      appBar: AppBar(
        title: Text('Kadi - Room ${widget.roomCode}'),
        centerTitle: true,
        backgroundColor: Colors.green.shade900,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _svc.watchRoom(widget.roomCode),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          if (data == null) return const Center(child: Text('Room not found'));

          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
          final pile = List<Map<String, dynamic>>.from(data['pile'] ?? []);
          final topCard = pile.isNotEmpty ? pile.last : null;
          final winner = data['winner'];
          final status = data['status'];

          if (status == 'over' && winner != null) {
            return _buildWinnerView(winner);
          }

          return Column(
            children: [
              _buildPlayersRow(players, data['turnIndex']),
              const Divider(color: Colors.white),
              Expanded(
                child: Center(
                  child: topCard == null
                      ? const Text("No card yet")
                      : _buildCard(topCard),
                ),
              ),
              const Divider(color: Colors.white),
              _buildPlayerHand(players),
              const SizedBox(height: 10),
              _buildActionButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayersRow(List<Map<String, dynamic>> players, int? turnIndex) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final player = players[i];
          final isTurn = turnIndex == i;
          return Column(
            children: [
              CircleAvatar(
                backgroundColor: isTurn ? Colors.yellow : Colors.grey.shade300,
                child: Text(
                  player['name'][0].toUpperCase(),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                player['name'],
                style: TextStyle(
                  color: isTurn ? Colors.yellow : Colors.white,
                  fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> card) {
    final rank = card['rank'];
    final suit = card['suit'];
    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(2, 2)),
        ],
      ),
      child: Center(
        child: Text(
          "$rank\n$suit",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerHand(List<Map<String, dynamic>> players) {
    final me = players.firstWhere(
      (p) => p['uid'] == _svc.uid,
      orElse: () => {},
    );
    final hand = List<Map<String, dynamic>>.from(me['hand'] ?? []);
    return Container(
      height: 130,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hand.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final card = hand[i];
          return GestureDetector(
            onTap: () async {
              await _svc.playCard(code: widget.roomCode, card: card);
            },
            child: _buildCard(card),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text("Draw"),
          onPressed: () async {
            await _svc.drawCard(code: widget.roomCode);
          },
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.exit_to_app),
          label: const Text("Leave"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            await _svc.leaveRoom(widget.roomCode);
            if (mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildWinnerView(String winner) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
          const SizedBox(height: 20),
          Text(
            "$winner Wins!",
            style: const TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Back to Lobby"),
          ),
        ],
      ),
    );
  }
}