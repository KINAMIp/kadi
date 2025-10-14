import 'dart:async';
import 'dart:math';

import '../engine/rule_engine.dart';
import '../models/game_state.dart';
import '../models/kadi_card.dart';
import '../models/kadi_player.dart';

class GameService {
  static final GameService _instance = GameService._internal();
  factory GameService() => _instance;
  GameService._internal();

  final _rooms = <String, _Room>{};
  final _controllers = <String, StreamController<GameState>>{};

  Stream<GameState> watch(String gameId) {
    _controllers.putIfAbsent(gameId, () => StreamController<GameState>.broadcast());
    final controller = _controllers[gameId]!;
    final room = _rooms[gameId];
    if (room != null) {
      Future.microtask(() => controller.add(room.state));
    }
    return controller.stream;
  }

  GameState? getState(String gameId) => _rooms[gameId]?.state;

  GameState createGame({
    required String id,
    required String hostUid,
    required String hostName,
    required int maxPlayers,
    bool isPublic = false,
  }) {
    final host = KadiPlayer(uid: hostUid, name: hostName, hand: []);
    final state = GameState(
      id: id,
      players: [host],
      drawPile: const [],
      discardPile: const [],
      turnIndex: 0,
      gameStatus: 'waiting',
      createdAt: DateTime.now(),
      maxPlayers: maxPlayers,
      eventLog: ['Room created by $hostName'],
    );
    final room = _Room(state: state, rules: const RuleState(), isPublic: isPublic);
    _rooms[id] = room;
    _emit(room, state);
    return state;
  }

  void addPlayer(
    String gameId, {
    required String uid,
    required String name,
  }) {
    final room = _rooms[gameId];
    if (room == null) return;
    final state = room.state;
    if (state.players.any((p) => p.uid == uid)) return;
    if (state.players.length >= state.maxPlayers) return;

    final players = List<KadiPlayer>.from(state.players)
      ..add(KadiPlayer(uid: uid, name: name, hand: []));

    var updated = state.copyWith(
      players: players,
      eventLog: _appendLog(state.eventLog, '$name joined the room'),
    );

    if (players.length >= 2 && players.length == state.maxPlayers) {
      room.state = updated;
      _startRound(room);
      return;
    }

    room.state = updated;
    _emit(room, updated);
  }

  void removePlayer(String gameId, String uid) {
    final room = _rooms[gameId];
    if (room == null) return;
    final state = room.state;
    final players = List<KadiPlayer>.from(state.players)
      ..removeWhere((p) => p.uid == uid);
    if (players.isEmpty) {
      room.state = state.copyWith(
        players: players,
        gameStatus: 'waiting',
        winnerUid: null,
        eventLog: _appendLog(state.eventLog, 'All players left. Room reset'),
      );
      _emit(room, room.state);
      return;
    }

    room.rules = const RuleState();
    final reset = state.copyWith(
      players: players,
      drawPile: const <KadiCard>[],
      discardPile: const <KadiCard>[],
      gameStatus: 'waiting',
      turnIndex: 0,
      winnerUid: null,
      eventLog: _appendLog(state.eventLog, 'Player left the game'),
    );
    room.state = reset;
    _emit(room, reset);
  }

  void playCard(
    String gameId,
    String playerId,
    KadiCard card, {
    Suit? chosenSuit,
    Rank? requestedRank,
  }) {
    final room = _rooms[gameId];
    if (room == null) return;
    if (room.state.gameStatus != 'playing') return;

    final state = room.state;
    final players = List<KadiPlayer>.from(state.players);
    if (players.isEmpty) return;

    final turnPlayer = players[state.turnIndex];
    if (turnPlayer.uid != playerId) return;

    final handIndex = turnPlayer.hand.indexWhere((c) => c.id == card.id);
    if (handIndex == -1) return;

    final isSkipTarget = room.rules.skipCount > 0;

    final validation = RuleEngine.canPlay(
      state: room.rules,
      card: card,
      topCard: state.discardPile.last,
      playerHand: turnPlayer.hand,
      isSkipTarget: isSkipTarget,
    );

    if (!validation.isValid) {
      return;
    }

    if (card.isAce && room.rules.pendingDraw == 0) {
      if (card.isAceOfSpades) {
        if (requestedRank == null && chosenSuit == null) {
          // Ace of spades must either request rank or change suit.
          return;
        }
      } else {
        if (chosenSuit == null) {
          return;
        }
      }
    }

    final discard = List<KadiCard>.from(state.discardPile)..add(card);
    final drawPile = List<KadiCard>.from(state.drawPile);

    final updatedHand = List<KadiCard>.from(turnPlayer.hand)..removeAt(handIndex);
    players[state.turnIndex] = turnPlayer.copyWith(hand: updatedHand);

    var rules = room.rules;
    final nikoRequired = rules.nikoPending.contains(playerId) ||
        rules.nikoDeclared.contains(playerId);
    final nikoDeclared = rules.nikoDeclared.contains(playerId);

    if (isSkipTarget) {
      rules = rules.copyWith(
        skipCount: max(0, rules.skipCount - 1),
        skipCancelable: false,
      );
    }

    rules = RuleEngine.applyCardEffect(
      state: rules,
      card: card,
      chosenSuit: chosenSuit,
      requestedRank: requestedRank,
    );

    final logMessage = _describePlay(turnPlayer.name, card, chosenSuit, requestedRank);

    if (updatedHand.isEmpty) {
      rules = RuleEngine.removeNikoFlags(rules, playerId);
      room.rules = rules;

      final canWin = !nikoRequired || nikoDeclared;

      if (canWin) {
        final finished = state.copyWith(
          players: players,
          discardPile: discard,
          drawPile: drawPile,
          gameStatus: 'finished',
          winnerUid: playerId,
        );
        _emit(room, finished.copyWith(
          eventLog: _appendLog(finished.eventLog, logMessage),
        ));
        _scheduleRestart(room);
      } else {
        final nextIndex = RuleEngine.nextPlayerIndex(
          state: rules,
          currentIndex: state.turnIndex,
          playerCount: players.length,
        );

        final updated = state.copyWith(
          players: players,
          discardPile: discard,
          drawPile: drawPile,
          turnIndex: nextIndex,
          winnerUid: null,
        );

        _emit(room, updated.copyWith(
          eventLog: _appendLog(
            updated.eventLog,
            '$logMessage (no Niko Kadi call)',
          ),
        ));
      }
      return;
    }

    if (RuleEngine.needsNikoCall(updatedHand)) {
      rules = RuleEngine.markNikoPending(rules, playerId);
    } else {
      rules = RuleEngine.removeNikoFlags(rules, playerId);
    }

    final nextIndex = RuleEngine.nextPlayerIndex(
      state: rules,
      currentIndex: state.turnIndex,
      playerCount: players.length,
    );

    room.rules = rules;

    final updated = state.copyWith(
      players: players,
      discardPile: discard,
      drawPile: drawPile,
      turnIndex: nextIndex,
    );

    _emit(room, updated.copyWith(
      eventLog: _appendLog(updated.eventLog, logMessage),
    ));
  }

  void drawCard(String gameId, String playerId) {
    final room = _rooms[gameId];
    if (room == null) return;
    if (room.state.gameStatus != 'playing') return;

    final state = room.state;
    final players = List<KadiPlayer>.from(state.players);
    if (players.isEmpty) return;

    final turnPlayer = players[state.turnIndex];
    if (turnPlayer.uid != playerId) return;

    if (room.rules.skipCount > 0 && room.rules.skipCancelable) {
      passTurn(gameId, playerId);
      return;
    }

    final drawCount = room.rules.pendingDraw > 0
        ? room.rules.pendingDraw
        : 1;

    final drawResult = _drawCards(state.drawPile, state.discardPile, drawCount);
    final newHand = List<KadiCard>.from(turnPlayer.hand)..addAll(drawResult.drawn);
    players[state.turnIndex] = turnPlayer.copyWith(hand: newHand);

    var rules = room.rules;

    String message;
    if (room.rules.pendingDraw > 0) {
      message = '${turnPlayer.name} drew ${drawResult.drawn.length} penalty cards';
      rules = rules.copyWith(
        pendingDraw: 0,
        skipCancelable: false,
        clearForcedSuit: true,
        clearRequestedRank: true,
      );
    } else if (room.rules.questionSuit != null) {
      message = '${turnPlayer.name} failed the question and drew a card';
      rules = rules.copyWith(clearQuestionSuit: true, skipCancelable: false);
    } else {
      message = '${turnPlayer.name} drew a card';
    }

    rules = RuleEngine.cancelRequestedRankIfImpossible(
      state: rules,
      playerHand: newHand,
    );

    if (RuleEngine.needsNikoCall(newHand)) {
      rules = RuleEngine.markNikoPending(rules, playerId);
    } else {
      rules = RuleEngine.removeNikoFlags(rules, playerId);
    }

    room.rules = rules;

    final updated = state.copyWith(
      players: players,
      drawPile: drawResult.drawPile,
      discardPile: drawResult.discardPile,
    );

    _emit(room, updated.copyWith(
      eventLog: _appendLog(updated.eventLog, message),
    ));

    if (room.rules.pendingDraw == 0 && room.rules.questionSuit == null) {
      passTurn(gameId, playerId);
    }
  }

  void passTurn(String gameId, String playerId) {
    final room = _rooms[gameId];
    if (room == null) return;
    if (room.state.gameStatus != 'playing') return;

    final state = room.state;
    final players = List<KadiPlayer>.from(state.players);
    if (players.isEmpty) return;

    final turnPlayer = players[state.turnIndex];
    if (turnPlayer.uid != playerId) return;

    var rules = room.rules;
    if (rules.skipCount > 0) {
      rules = RuleEngine.clearAfterSkipResolution(rules);
    }

    final nextIndex = RuleEngine.nextPlayerIndex(
      state: rules,
      currentIndex: state.turnIndex,
      playerCount: players.length,
    );

    room.rules = rules;

    final updated = state.copyWith(turnIndex: nextIndex);
    _emit(room, updated.copyWith(
      eventLog: _appendLog(updated.eventLog, '${turnPlayer.name} passed'),
    ));
  }

  void declareNikoKadi(String gameId, String playerId) {
    final room = _rooms[gameId];
    if (room == null) return;
    if (room.state.gameStatus != 'playing') return;

    if (!room.rules.nikoPending.contains(playerId)) return;

    room.rules = RuleEngine.markNikoDeclared(room.rules, playerId);

    final player = room.state.players.firstWhere((p) => p.uid == playerId, orElse: () =>
        KadiPlayer(uid: playerId, name: 'Player', hand: const []));

    _emit(
      room,
      room.state.copyWith(
        eventLog: _appendLog(
          room.state.eventLog,
          '${player.name} called Niko Kadi!',
        ),
      ),
    );
  }

  void _startRound(_Room room) {
    if (room.state.players.length < 2) {
      return;
    }

    final rnd = Random();
    final deck = KadiCard.fullDeck();

    final players = room.state.players
        .map((p) => p.copyWith(hand: []))
        .toList()
      ..shuffle(rnd);

    for (var i = 0; i < players.length; i++) {
      final hand = <KadiCard>[];
      for (var j = 0; j < 4; j++) {
        hand.add(deck.removeLast());
      }
      players[i] = players[i].copyWith(hand: hand);
    }

    var starterIndex = deck.lastIndexWhere((c) => c.isOrdinary);
    if (starterIndex < 0) {
      starterIndex = deck.length - 1;
    }
    final starter = deck.removeAt(starterIndex);
    final discard = <KadiCard>[starter];

    final turnIndex = rnd.nextInt(players.length);

    room.rules = const RuleState();
    room.rules = room.rules.copyWith(clockwise: true);

    final started = room.state.copyWith(
      players: players,
      drawPile: deck,
      discardPile: discard,
      turnIndex: turnIndex,
      gameStatus: 'playing',
      winnerUid: null,
      eventLog: _appendLog(
        room.state.eventLog,
        'Round started. ${players[turnIndex].name} begins with ${starter.rank.label} of ${starter.suit.label}.',
      ),
    );

    room.autoRestartScheduled = false;
    _emit(room, started);
  }

  void _scheduleRestart(_Room room) {
    if (room.autoRestartScheduled) return;
    room.autoRestartScheduled = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (!_rooms.containsKey(room.state.id)) return;
      if (room.state.players.length < 2) {
        final waiting = room.state.copyWith(
          gameStatus: 'waiting',
          eventLog: _appendLog(room.state.eventLog, 'Waiting for more players'),
        );
        room.rules = const RuleState();
        room.autoRestartScheduled = false;
        _emit(room, waiting);
        return;
      }
      _startRound(room);
    });
  }

  void _emit(_Room room, GameState state) {
    final synced = state.copyWith(
      requiredSuit: room.rules.forcedSuit,
      requestedRank: room.rules.requestedRank,
      questionSuit: room.rules.questionSuit,
      pendingDraw: room.rules.pendingDraw,
      clockwise: room.rules.clockwise,
      skipCount: room.rules.skipCount,
      nikoPending: room.rules.nikoPending.toList(),
      nikoDeclared: room.rules.nikoDeclared.toList(),
    );
    room.state = synced;
    _controllers.putIfAbsent(synced.id, () => StreamController<GameState>.broadcast());
    _controllers[synced.id]!.add(synced);
  }

  _DrawResult _drawCards(
    List<KadiCard> drawPile,
    List<KadiCard> discardPile,
    int count,
  ) {
    final draw = List<KadiCard>.from(drawPile);
    final discard = List<KadiCard>.from(discardPile);
    final drawn = <KadiCard>[];

    for (var i = 0; i < count; i++) {
      if (draw.isEmpty) {
        if (discard.length <= 1) {
          break;
        }
        final top = discard.removeLast();
        draw.addAll(discard);
        draw.shuffle();
        discard
          ..clear()
          ..add(top);
      }
      drawn.add(draw.removeLast());
    }

    return _DrawResult(drawPile: draw, discardPile: discard, drawn: drawn);
  }

  List<String> _appendLog(List<String> current, String entry) {
    final updated = List<String>.from(current)..add(entry);
    if (updated.length > 30) {
      updated.removeRange(0, updated.length - 30);
    }
    return updated;
  }

  String _describePlay(String playerName, KadiCard card, Suit? chosenSuit, Rank? requestedRank) {
    final buffer = StringBuffer('$playerName played ${card.rank.label} of ${card.suit.label}');
    if (card.isAce && chosenSuit != null && card.isAceOfSpades == false) {
      buffer.write(' choosing ${chosenSuit.label}');
    }
    if (card.isAceOfSpades && requestedRank != null) {
      buffer.write(' requesting ${requestedRank.label}');
    }
    if (card.isPenaltyCard) {
      buffer.write(' (penalty +${card.penaltyValue})');
    }
    if (card.rank == Rank.jack) {
      buffer.write(' (jump)');
    }
    if (card.rank == Rank.king) {
      buffer.write(' (reverse)');
    }
    if (card.isQuestionCard) {
      buffer.write(' (question)');
    }
    return buffer.toString();
  }

  String randomId() => 'g_${Random().nextInt(1 << 32)}';
}

class _Room {
  _Room({
    required this.state,
    required this.rules,
    required this.isPublic,
  });

  GameState state;
  RuleState rules;
  final bool isPublic;
  bool autoRestartScheduled = false;
}

class _DrawResult {
  _DrawResult({
    required this.drawPile,
    required this.discardPile,
    required this.drawn,
  });

  final List<KadiCard> drawPile;
  final List<KadiCard> discardPile;
  final List<KadiCard> drawn;
}
