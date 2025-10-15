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

  late final Stream<GameState> _roomStream;
  final ScrollController _eventLogController = ScrollController();

  Timer? _turnTimer;
  int _turnSecondsLeft = 0;
  String? _currentTurnPlayerId;
  String? _lastTopCardId;

  Timer? _cancelTimer;
  String? _activeCancelCardId;
  Rank? _activeCancelRank;
  int _cancelSecondsLeft = 0;

  bool _showNikoPrompt = false;

  @override
  void initState() {
    super.initState();
    _roomStream = _svc.watchRoom(widget.roomCode);
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _cancelTimer?.cancel();
    _eventLogController.dispose();
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
        stream: _roomStream,
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

          final isMyTurn = state.gameStatus == 'playing' &&
              state.players.isNotEmpty &&
              state.players[state.turnIndex % state.players.length].uid == me.uid;
          final isHost = me.uid == state.hostUid;

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
                  child: _buildArena(
                    state,
                    me.uid,
                    isHost: isHost,
                    onStartGame: () => _svc.startGame(widget.roomCode),
                  ),
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
    final isPlaying = state.gameStatus == 'playing';
    final current = isPlaying && players.isNotEmpty
        ? players[state.turnIndex % players.length]
        : null;
    final hostPlayer = players.firstWhere(
      (p) => p.uid == state.hostUid,
      orElse: () => players.isNotEmpty
          ? players.first
          : KadiPlayer(uid: state.hostUid, name: state.hostName, hand: const []),
    );
    final headline = current != null
        ? 'Current turn: ${current.name}'
        : players.length < state.maxPlayers
            ? 'Waiting for players (${players.length}/${state.maxPlayers})'
            : 'Waiting for ${hostPlayer.name} to start';
    String subtext;
    final comboActive = state.comboOwnerId != null;
    final currentIsComboOwner =
        comboActive && current != null && current.uid == state.comboOwnerId;
    if (isPlaying) {
      if (currentIsComboOwner) {
        final comboLabel = state.comboRank?.label ?? 'matching cards';
        subtext = isMyTurn
            ? 'Chain your $comboLabel or tap Done to pass'
            : '${current!.name} is chaining ${state.comboRank != null ? '${state.comboRank!.label}s' : 'cards'}';
      } else {
        subtext = isMyTurn
            ? "It's your move!"
            : 'You have ${me.hand.length} card${me.hand.length == 1 ? '' : 's'}';
      }
    } else {
      subtext = players.length < state.maxPlayers
          ? 'Waiting for more players to join'
          : me.uid == state.hostUid
              ? 'Start the game when everyone is ready'
              : 'Waiting for ${hostPlayer.name} to begin';
    }
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
                            headline,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtext,
                            style: TextStyle(
                              color: isPlaying && isMyTurn
                                  ? Colors.amberAccent
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildTurnTimerIndicator(
                      isMyTurn: current?.uid == _svc.uid,
                      isActive: isPlaying,
                    ),
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

  Widget _buildTurnTimerIndicator({
    required bool isMyTurn,
    required bool isActive,
  }) {
    final progress = !isActive || _turnSecondsLeft <= 0
        ? 0.0
        : _turnSecondsLeft / _turnDurationSeconds;
    final displayText = isActive ? _turnSecondsLeft.toString() : '--';
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
              !isActive
                  ? Colors.white24
                  : isMyTurn
                      ? Colors.amberAccent
                      : Colors.lightBlueAccent,
            ),
          ),
        ),
        Text(
          displayText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildArena(
    GameState state,
    String myId, {
    required bool isHost,
    required VoidCallback onStartGame,
  }) {
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
        final canStart =
            state.gameStatus == 'waiting' && players.length == state.maxPlayers;

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
              child: _buildCenterStatus(
                state,
                isHost: isHost,
                canStart: canStart,
                onStartGame: onStartGame,
              ),
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
      left: seatX - 70,
      top: seatY - 75,
      width: 140,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 240),
        scale: isTurn ? 1.04 : 0.94,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: isTurn
                  ? [
                      const Color(0xFFFFE082).withOpacity(0.95),
                      const Color(0xFFFFAB40).withOpacity(0.85),
                    ]
                  : [
                      Colors.white.withOpacity(0.16),
                      Colors.white.withOpacity(0.05),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isMe
                  ? const Color(0xFF64FFDA).withOpacity(isTurn ? 0.9 : 0.6)
                  : (isTurn
                      ? Colors.black.withOpacity(0.4)
                      : Colors.white24),
              width: isTurn ? 2.4 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isTurn ? 0.55 : 0.28),
                blurRadius: isTurn ? 22 : 14,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 6,
                      top: 2,
                      child: Transform.rotate(
                        angle: -0.28,
                        child: _SeatCardShadow(
                          color: Colors.black.withOpacity(0.18),
                          borderColor:
                              Colors.white.withOpacity(isTurn ? 0.4 : 0.18),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: -4,
                      child: Transform.rotate(
                        angle: 0.22,
                        child: _SeatCardShadow(
                          color: Colors.black.withOpacity(0.2),
                          borderColor:
                              Colors.white.withOpacity(isTurn ? 0.38 : 0.16),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isTurn
                                ? [
                                    const Color(0xFFFFF8E1),
                                    const Color(0xFFFFECB3),
                                  ]
                                : [
                                    Colors.black.withOpacity(0.55),
                                    Colors.black.withOpacity(0.32),
                                  ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(isTurn ? 0.8 : 0.35),
                            width: 1.4,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          player.name.isNotEmpty
                              ? player.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: isTurn ? Colors.black87 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isMe ? '${player.name} · You' : player.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isTurn ? Colors.black87 : Colors.white,
                  fontWeight: isTurn ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.style_outlined,
                    size: 16,
                    color: isTurn ? Colors.black54 : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${player.hand.length} cards',
                    style: TextStyle(
                      color: isTurn ? Colors.black54 : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (isTurn)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.black.withOpacity(0.6),
                    ),
                    child: Text(
                      isMe ? 'Your move' : 'Playing',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterStatus(
    GameState state, {
    required bool isHost,
    required bool canStart,
    required VoidCallback onStartGame,
  }) {
    final isPlaying = state.gameStatus == 'playing';
    final hostPlayer = state.players.firstWhere(
      (p) => p.uid == state.hostUid,
      orElse: () => state.players.isNotEmpty
          ? state.players.first
          : KadiPlayer(uid: state.hostUid, name: state.hostName, hand: const []),
    );

    if (!isPlaying) {
      final waitingMessage = state.players.length < state.maxPlayers
          ? 'Waiting for players (${state.players.length}/${state.maxPlayers})'
          : isHost
              ? 'Room is full. Start the game when everyone is ready.'
              : 'Waiting for ${hostPlayer.name} to start the game.';
      final secondaryMessage = state.players.length < state.maxPlayers
          ? 'Share the room code to invite more players.'
          : canStart
              ? (isHost
                  ? 'You can begin the match at any time.'
                  : 'All players are ready. Hang tight!')
              : 'Getting things ready...';
      return Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withOpacity(0.4),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              waitingMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              secondaryMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (canStart && isHost) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'Start game',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onStartGame,
              ),
            ] else if (canStart) ...[
              const SizedBox(height: 18),
              Text(
                'Waiting for ${hostPlayer.name}...',
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ],
        ),
      );
    }

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
    final comboActive = state.comboOwnerId != null;
    final bool iAmComboOwner = state.comboOwnerId == me.uid;
    final Rank? comboRank = state.comboRank;
    final bool waitingOnCombo = comboActive && !iAmComboOwner;
    final bool canDraw = isMyTurn && !iAmComboOwner;
    final comboOwnerName = comboActive
        ? state.players.firstWhere(
              (p) => p.uid == state.comboOwnerId,
              orElse: () => KadiPlayer(
                uid: state.comboOwnerId!,
                name: 'Player',
                hand: const [],
              ),
            ).name
        : null;
    final handFillColor = iAmComboOwner
        ? const Color(0xFFFFE0B2).withOpacity(0.35)
        : Colors.white.withOpacity(0.05);
    final handBorderColor = iAmComboOwner
        ? const Color(0xFFFFB74D).withOpacity(0.9)
        : Colors.white24;
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: state.questionSuit != null
                ? Padding(
                    key: const ValueKey('question-banner'),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildAnswerPrompt(
                      state.questionSuit!,
                      isMyTurn,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-question-banner')),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: iAmComboOwner
                ? Container(
                    key: const ValueKey('combo-owner-banner'),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFFF8A65)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.black87),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            comboRank != null
                                ? 'Play your remaining ${comboRank.label}s or tap Done when you are finished.'
                                : 'Play all identical cards or tap Done to pass the turn.',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : waitingOnCombo && comboOwnerName != null
                    ? Container(
                        key: const ValueKey('combo-wait-banner'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.08),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_bottom,
                                color: Colors.white70),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Waiting for $comboOwnerName to finish their combo...',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
          SizedBox(
            height: 130,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: handFillColor,
                border: Border.all(color: handBorderColor, width: iAmComboOwner ? 2 : 1),
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
              ElevatedButton.icon(
                icon: const Icon(Icons.catching_pokemon),
                label: const Text(
                  'Pick',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                  shadowColor: Colors.black45,
                ),
                onPressed: canDraw ? () => _svc.drawCard(widget.roomCode) : null,
              ),
              if (iAmComboOwner)
                ElevatedButton.icon(
                  icon: const Icon(Icons.done_all),
                  label: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: Colors.black54,
                  ),
                  onPressed: () => _svc.finishCombo(widget.roomCode),
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
            child: Scrollbar(
              controller: _eventLogController,
              thumbVisibility: true,
              radius: const Radius.circular(12),
              child: ListView(
                controller: _eventLogController,
                reverse: true,
                padding: EdgeInsets.zero,
                children: state.eventLog.reversed
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          e,
                          style:
                              const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerPrompt(Suit suit, bool isMyTurn) {
    final accent = _suitAccentColor(suit);
    final suitLabel = suit.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.85),
            accent.withOpacity(0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.92),
            ),
            child: Icon(
              Icons.live_help,
              color: accent.darken(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Answer?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isMyTurn
                      ? 'Play a $suitLabel number right now to stay safe.'
                      : 'Waiting on a $suitLabel number response.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.16),
            ),
            child: Text(
              suitLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _suitAccentColor(Suit suit) {
    switch (suit) {
      case Suit.clubs:
        return const Color(0xFF66BB6A);
      case Suit.diamonds:
        return const Color(0xFFE57373);
      case Suit.hearts:
        return const Color(0xFFFF8A80);
      case Suit.spades:
        return const Color(0xFF90CAF9);
      case Suit.joker:
        return const Color(0xFFB39DDB);
    }
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
            const SizedBox(height: 10),
            Text(
              _activeCancelRank != null
                  ? 'Only another ${_activeCancelRank == Rank.king ? 'King' : 'Jack'} cancels this play.'
                  : 'Only a matching card cancels this play.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Teammates must respond with the same rank.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 11),
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
    final top = state.discardPile.isNotEmpty ? state.discardPile.last : null;
    final topId = top?.id;
    if (state.gameStatus != 'playing') {
      _currentTurnPlayerId = null;
      _lastTopCardId = null;
      _turnTimer?.cancel();
      if (_turnSecondsLeft != 0) {
        setState(() {
          _turnSecondsLeft = 0;
        });
      }
    } else {
      final newCurrentPlayerId = players.isEmpty
          ? null
          : players[state.turnIndex % players.length].uid;
      final hasPlayerChanged = newCurrentPlayerId != _currentTurnPlayerId;
      if (hasPlayerChanged) {
        _currentTurnPlayerId = newCurrentPlayerId;
        _startTurnTimer();
      } else if (topId != null &&
          topId != _lastTopCardId &&
          newCurrentPlayerId != null &&
          newCurrentPlayerId == state.comboOwnerId) {
        _startTurnTimer();
      }
      _lastTopCardId = topId;
    }

    if (top != null && (top.rank == Rank.jack || top.rank == Rank.king)) {
      if (_activeCancelCardId != top.id) {
        _triggerCancelOverlay(top);
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

  void _triggerCancelOverlay(KadiCard card) {
    _cancelTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _activeCancelCardId = card.id;
      _activeCancelRank = card.rank;
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
        _activeCancelRank = null;
      });
    }
  }

  bool _shouldPromptNiko(KadiPlayer me) {
    if (me.hand.isEmpty) {
      return false;
    }
    return me.hand.every((card) => card.isOrdinary);
  }

  Future<void> _handlePlayCard(KadiCard card, GameState state) async {
    if (state.comboOwnerId != null && state.comboOwnerId != _svc.uid) {
      return;
    }
    if (state.comboOwnerId == _svc.uid &&
        state.comboRank != null &&
        card.rank != state.comboRank) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Finish your combo with the same rank or tap Done to pass.',
              ),
            ),
          );
      }
      return;
    }
    Rank? requestedRank;
    Suit? requestedCardSuit;

    if (card.isAce) {
      if (card.isAceOfSpades) {
        if (state.pendingDraw == 0) {
          final request = await _promptAceRequest();
          if (request == null) {
            return;
          }
          requestedRank = request.rank;
          requestedCardSuit = request.suit;
        }
      }
    }

    _svc.playCard(
      code: widget.roomCode,
      card: card,
      chosenSuit: null,
      requestedRank: requestedRank,
      requestedCardSuit: requestedCardSuit,
    );
  }

  Future<_AceRequest?> _promptAceRequest() async {
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
    return _AceRequest(rank: rank, suit: suit);
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

class _SeatCardShadow extends StatelessWidget {
  final Color color;
  final Color borderColor;

  const _SeatCardShadow({
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0x66FFFFFF), Color(0x18FFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(color: color, blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
    );
  }
}

extension _ColorTones on Color {
  Color darken([double amount = 0.18]) {
    final factor = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * factor).clamp(0, 255).toInt(),
      (green * factor).clamp(0, 255).toInt(),
      (blue * factor).clamp(0, 255).toInt(),
    );
  }
}

class _AceRequest {
  final Rank rank;
  final Suit suit;

  const _AceRequest({required this.rank, required this.suit});
}
