import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../models/kadi_card.dart';
import '../../models/kadi_player.dart';
import '../../services/online_service.dart';
import '../widgets/hand_widget.dart';
import '../widgets/playing_card_widget.dart';

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
      backgroundColor: const Color(0xFF0D4D2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08361D),
        title: Text('Room ${widget.roomCode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Leave room',
            onPressed: () {
              _svc.leaveGame(widget.roomCode);
              Navigator.of(context).maybePop();
            },
          )
        ],
      ),
      body: StreamBuilder<GameState>(
        stream: _svc.watchRoom(widget.roomCode),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Connection error: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final state = snapshot.data;
          if (state == null) {
            return const Center(child: Text('Waiting for game to start'));
          }

          if (state.gameStatus == 'finished' && state.winnerUid != null) {
            final winner = state.players.firstWhere(
              (p) => p.uid == state.winnerUid,
              orElse: () => KadiPlayer(uid: state.winnerUid!, name: 'Winner', hand: const []),
            );
            return _buildWinnerView(winner.name);
          }

          final me = state.players.firstWhere(
            (p) => p.uid == _svc.uid,
            orElse: () => state.players.isEmpty
                ? KadiPlayer(uid: _svc.uid, name: 'You', hand: const [])
                : state.players.first,
          );

          final isMyTurn = state.players.isNotEmpty &&
              state.players[state.turnIndex % state.players.length].uid == me.uid;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPlayersRow(state, me.uid),
              const Divider(color: Colors.white24),
              Expanded(
                child: Center(
                  child: _buildCenterPanel(state),
                ),
              ),
              const Divider(color: Colors.white24),
              _buildActionBar(state, me, isMyTurn),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayersRow(GameState state, String myId) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: state.players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final player = state.players[index];
          final isTurn = index == state.turnIndex % state.players.length;
          final isMe = player.uid == myId;
          return Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isTurn ? Colors.amber : Colors.black45,
                child: Text(
                  player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isTurn ? Colors.black : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isMe ? '${player.name} (You)' : player.name,
                style: TextStyle(
                  color: isTurn ? Colors.amber : Colors.white,
                  fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              Text(
                '${player.hand.length} cards',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCenterPanel(GameState state) {
    final top = state.discardPile.isNotEmpty ? state.discardPile.last : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          state.pendingDraw > 0
              ? 'Penalty stack: +${state.pendingDraw}'
              : state.requiredSuit != null
                  ? 'Suit required: ${state.requiredSuit!.label}'
                  : state.requestedRank != null
                      ? 'Requested: ${state.requestedRank!.label}'
                      : state.questionSuit != null
                          ? 'Answer with ${state.questionSuit!.label}'
                          : 'Draw pile: ${state.drawPile.length}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        if (top != null)
          PlayingCardWidget(card: top)
        else
          const Text('No card yet', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 18),
        Text(
          state.clockwise ? 'Clockwise' : 'Counter clockwise',
          style: const TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildActionBar(GameState state, KadiPlayer me, bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: Colors.black.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HandWidget(
            cards: me.hand,
            onPlayTap: isMyTurn ? (card) => _handlePlayCard(card, state) : null,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Draw'),
                onPressed: isMyTurn ? () => _svc.drawCard(widget.roomCode) : null,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.block),
                label: const Text('Pass'),
                onPressed: isMyTurn ? () => _svc.passTurn(widget.roomCode) : null,
              ),
              if (state.nikoPending.contains(me.uid) &&
                  !state.nikoDeclared.contains(me.uid))
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () => _svc.declareNikoKadi(widget.roomCode),
                  child: const Text('Declare Niko Kadi'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView(
              reverse: true,
              children: state.eventLog.reversed
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        e,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlayCard(KadiCard card, GameState state) async {
    Suit? chosenSuit;
    Rank? requestedRank;

    if (card.isAce) {
      if (card.isAceOfSpades) {
        final selection = await _chooseAceOfSpadesOption();
        if (selection == null) {
          return;
        }
        chosenSuit = selection.suit;
        requestedRank = selection.rank;
      } else {
        chosenSuit = await _chooseSuit();
        if (chosenSuit == null) {
          return;
        }
      }
    }

    _svc.playCard(
      code: widget.roomCode,
      card: card,
      chosenSuit: chosenSuit,
      requestedRank: requestedRank,
    );
  }

  Future<Suit?> _chooseSuit() async {
    return showDialog<Suit>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose a suit'),
        children: Suit.values
            .where((s) => s != Suit.joker)
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, s),
                child: Text(s.label),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<_AceSelection?> _chooseAceOfSpadesOption() async {
    return showDialog<_AceSelection>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Ace of Spades'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Choose a suit to switch or request a rank.'),
          ),
          ...Suit.values
              .where((s) => s != Suit.joker)
              .map(
                (s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, _AceSelection(suit: s)),
                  child: Text('Change suit to ${s.label}'),
                ),
              ),
          const Divider(),
          ...Rank.values
              .where((r) => r != Rank.joker)
              .map(
                (r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, _AceSelection(rank: r)),
                  child: Text('Request ${r.label}'),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildWinnerView(String winnerName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 96, color: Colors.amber),
          const SizedBox(height: 20),
          Text(
            '$winnerName wins!',
            style: const TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Back to lobby'),
          ),
        ],
      ),
    );
  }
}

class _AceSelection {
  final Suit? suit;
  final Rank? rank;

  const _AceSelection({this.suit, this.rank}) : assert(suit != null || rank != null);
}
