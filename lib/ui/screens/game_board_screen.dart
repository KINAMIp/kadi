import 'dart:async';
import 'dart:math' as math;

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
  static const int _turnDurationSeconds = 30;

  Timer? _turnTimer;
  int _turnSecondsLeft = 0;
  String? _currentTurnPlayerId;

  Timer? _cancelTimer;
  String? _activeCancelCardId;
  int _cancelSecondsLeft = 0;

  bool _showNikoPrompt = false;

  @override
  void dispose() {
    _turnTimer?.cancel();
    _cancelTimer?.cancel();
    super.dispose();
  }

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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleStateSideEffects(state, me);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopHud(state, me, isMyTurn),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildArena(state, me.uid),
                ),
              ),
              _buildBottomSection(state, me, isMyTurn),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopHud(GameState state, KadiPlayer me, bool isMyTurn) {
    final players = state.players;
    final current = players.isNotEmpty
        ? players[state.turnIndex % players.length]
        : null;
    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
              color: Colors.black.withOpacity(0.25),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current == null
                                ? 'Waiting for players'
                                : 'Current turn: ${current.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isMyTurn
                                ? 'It\'s your move!'
                                : 'You have ${me.hand.length} card${me.hand.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: isMyTurn ? Colors.amberAccent : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildTurnTimerIndicator(current?.uid == _svc.uid),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildHudStat(
                      icon: Icons.layers,
                      label: 'Draw pile',
                      value: state.drawPile.length.toString(),
                    ),
                    const SizedBox(width: 16),
                    _buildHudStat(
                      icon: Icons.history,
                      label: 'Discarded',
                      value: state.discardPile.length.toString(),
                    ),
                    const SizedBox(width: 16),
                    _buildHudStat(
                      icon: state.clockwise
                          ? Icons.rotate_right
                          : Icons.rotate_left,
                      label: 'Direction',
                      value: state.clockwise ? 'Clockwise' : 'Counter',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_cancelSecondsLeft > 0)
            Positioned(
              right: 24,
              bottom: 24,
              child: _buildCancelPopup(),
            ),
          if (_showNikoPrompt &&
              !state.nikoDeclared.contains(me.uid))
            Positioned(
              left: 24,
              bottom: 24,
              child: _buildNikoPrompt(),
            ),
        ],
      ),
    );
  }

  Widget _buildHudStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.08),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTurnTimerIndicator(bool isMyTurn) {
    final progress = _turnSecondsLeft <= 0
        ? 0.0
        : _turnSecondsLeft / _turnDurationSeconds;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 5,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              isMyTurn ? Colors.amberAccent : Colors.lightBlueAccent,
            ),
          ),
        ),
        Text(
          _turnSecondsLeft.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildArena(GameState state, String myId) {
    final players = state.players;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (players.isEmpty) {
          return const Center(
            child: Text(
              'Waiting for opponents...',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final centerX = width / 2;
        final centerY = height / 2;
        final circleDiameter = math.min(width, height) * 0.75;
        final radius = circleDiameter / 2;
        final angleStep = (2 * math.pi) / players.length;
        const startAngle = -math.pi / 2;

        return Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: circleDiameter,
                height: circleDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: _buildCenterStatus(state),
            ),
            for (var i = 0; i < players.length; i++)
              _buildSeat(
                player: players[i],
                myId: myId,
                isTurn: i == state.turnIndex % players.length,
                centerX: centerX,
                centerY: centerY,
                radius: radius,
                angle: startAngle + angleStep * i,
              ),
          ],
        );
      },
    );
  }

  Widget _buildSeat({
    required KadiPlayer player,
    required String myId,
    required bool isTurn,
    required double centerX,
    required double centerY,
    required double radius,
    required double angle,
  }) {
    final seatX = centerX + radius * math.cos(angle);
    final seatY = centerY + radius * math.sin(angle);
    final isMe = player.uid == myId;
    return Positioned(
      left: seatX - 60,
      top: seatY - 60,
      width: 120,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: isTurn ? 1.05 : 0.95,
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: isTurn ? Colors.amberAccent : Colors.black45,
              child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isTurn ? Colors.black : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isMe ? '${player.name} (You)' : player.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isTurn ? Colors.amberAccent : Colors.white,
                fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            Text(
              '${player.hand.length} cards',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterStatus(GameState state) {
    final top = state.discardPile.isNotEmpty ? state.discardPile.last : null;
    String status;
    if (state.pendingDraw > 0) {
      status = 'Penalty stack: +${state.pendingDraw}';
    } else if (state.requiredSuit != null) {
      status = 'Suit required: ${state.requiredSuit!.label}';
    } else if (state.requiredJokerColor != null) {
      status = 'Play a ${state.requiredJokerColor!.label} Joker';
    } else if (state.requestedRank != null) {
      final label = state.requestedCardSuit != null
          ? '${state.requestedRank!.label} of ${state.requestedCardSuit!.label}'
          : state.requestedRank!.label;
      status = 'Requested: $label';
    } else if (state.questionSuit != null) {
      status = 'Answer with ${state.questionSuit!.label}';
    } else {
      status = 'Draw pile: ${state.drawPile.length}';
    }
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withOpacity(0.35),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          if (top != null)
            PlayingCardWidget(card: top)
          else
            const Text('No card yet', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Text(
            state.clockwise ? 'Clockwise' : 'Counter clockwise',
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(GameState state, KadiPlayer me, bool isMyTurn) {
    final nikoEligible = state.nikoPending.contains(me.uid) &&
        !state.nikoDeclared.contains(me.uid);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.32),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 130,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: HandWidget(
                  cards: me.hand,
                  onPlayTap: isMyTurn ? (card) => _handlePlayCard(card, state) : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC857), Color(0xFFFF6F91)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.catching_pokemon),
                  label: const Text(
                    'Pick',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  onPressed: isMyTurn ? () => _svc.drawCard(widget.roomCode) : null,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.block),
                label: const Text('Pass'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                ),
                onPressed: isMyTurn ? () => _svc.passTurn(widget.roomCode) : null,
              ),
              if (nikoEligible)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  ),
                  onPressed: () => _svc.declareNikoKadi(widget.roomCode),
                  child: const Text('Declare Niko Kadi'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 110,
            child: ListView(
              reverse: true,
              padding: EdgeInsets.zero,
              children: state.eventLog.reversed
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
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

  Widget _buildCancelPopup() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _cancelSecondsLeft > 0 ? 1 : 0,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.redAccent.withOpacity(0.85),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cancel window',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_cancelSecondsLeft s',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black38,
              ),
              onPressed: _dismissCancelOverlay,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNikoPrompt() {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.greenAccent.withOpacity(0.85),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Niko Kadi?',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You can declare now!',
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _svc.declareNikoKadi(widget.roomCode),
            child: const Text('Declare Niko Kadi'),
          ),
        ],
      ),
    );
  }

  void _handleStateSideEffects(GameState state, KadiPlayer me) {
    if (!mounted) return;
    final players = state.players;
    final newCurrentPlayerId = players.isEmpty
        ? null
        : players[state.turnIndex % players.length].uid;
    if (newCurrentPlayerId != _currentTurnPlayerId) {
      _currentTurnPlayerId = newCurrentPlayerId;
      _startTurnTimer();
    }

    final top = state.discardPile.isNotEmpty ? state.discardPile.last : null;
    if (top != null && (top.rank == Rank.jack || top.rank == Rank.king)) {
      if (_activeCancelCardId != top.id) {
        _triggerCancelOverlay(top.id);
      }
    } else if (_activeCancelCardId != null) {
      _dismissCancelOverlay();
    }

    final shouldPrompt =
        _shouldPromptNiko(me) || state.nikoPending.contains(me.uid);
    if (shouldPrompt != _showNikoPrompt) {
      setState(() {
        _showNikoPrompt = shouldPrompt;
      });
    }
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    if (!mounted) return;
    if (_currentTurnPlayerId == null) {
      setState(() {
        _turnSecondsLeft = 0;
      });
      return;
    }
    setState(() {
      _turnSecondsLeft = _turnDurationSeconds;
    });
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_turnSecondsLeft <= 0) {
        timer.cancel();
      } else {
        setState(() {
          _turnSecondsLeft = math.max(0, _turnSecondsLeft - 1);
        });
      }
    });
  }

  void _triggerCancelOverlay(String cardId) {
    _cancelTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _activeCancelCardId = cardId;
      _cancelSecondsLeft = 5;
    });
    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cancelSecondsLeft <= 1) {
        timer.cancel();
        _dismissCancelOverlay();
      } else {
        setState(() {
          _cancelSecondsLeft = _cancelSecondsLeft - 1;
        });
      }
    });
  }

  void _dismissCancelOverlay() {
    _cancelTimer?.cancel();
    if (!mounted) return;
    if (_cancelSecondsLeft != 0 || _activeCancelCardId != null) {
      setState(() {
        _cancelSecondsLeft = 0;
        _activeCancelCardId = null;
      });
    }
  }

  bool _shouldPromptNiko(KadiPlayer me) {
    final allowedRanks = {
      Rank.four,
      Rank.five,
      Rank.six,
      Rank.seven,
      Rank.nine,
      Rank.ten,
    };
    if (me.hand.isEmpty) {
      return false;
    }
    if (me.hand.length == 1) {
      return true;
    }
    final firstRank = me.hand.first.rank;
    if (!allowedRanks.contains(firstRank)) {
      return false;
    }
    return me.hand.every((card) => card.rank == firstRank);
  }

  Future<void> _handlePlayCard(KadiCard card, GameState state) async {
    Suit? chosenSuit;
    Rank? requestedRank;
    Suit? requestedCardSuit;

    if (card.isAce) {
      if (card.isAceOfSpades) {
        final selection = await _chooseAceOfSpadesOption();
        if (selection == null) {
          return;
        }
        chosenSuit = selection.suit;
        requestedRank = selection.rank;
        requestedCardSuit = selection.rankSuit;
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
      requestedCardSuit: requestedCardSuit,
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
    const requestSpecificToken = Object();
    final result = await showDialog<Object?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Ace of Spades'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Choose how to use the Ace of Spades.'),
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
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, requestSpecificToken),
            child: const Text('Request a specific card'),
          ),
        ],
      ),
    );

    if (result is _AceSelection) {
      return result;
    }
    if (result == requestSpecificToken) {
      return _chooseSpecificCard();
    }
    return null;
  }

  Future<_AceSelection?> _chooseSpecificCard() async {
    final rank = await showDialog<Rank>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select rank'),
        children: Rank.values
            .where((r) => r != Rank.joker)
            .map(
              (r) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, r),
                child: Text(r.label),
              ),
            )
            .toList(),
      ),
    );
    if (rank == null) return null;

    final suit = await showDialog<Suit>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select suit for ${rank.label}'),
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
    if (suit == null) return null;
    return _AceSelection(rank: rank, rankSuit: suit);
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
  final Suit? rankSuit;

  const _AceSelection({this.suit, this.rank, this.rankSuit})
      : assert(suit != null || rank != null);
}
