import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../engine/rule_engine.dart';
import '../models/game_state.dart';
import '../models/kadi_card.dart';
import '../models/kadi_player.dart';

class GameService {
  GameService._();
  static final GameService _instance = GameService._();
  factory GameService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('games');

  Stream<GameState> watch(String gameId) {
    return _games.doc(gameId).snapshots().where((snapshot) => snapshot.exists).map(
      (snapshot) {
        final data = snapshot.data()!;
        final room = _roomFromData(data);
        return _syncRoom(room);
      },
    );
  }

  Future<GameState?> getState(String gameId) async {
    final snapshot = await _games.doc(gameId).get();
    if (!snapshot.exists) return null;
    final room = _roomFromData(snapshot.data()!);
    return _syncRoom(room);
  }

  Future<GameState> createGame({
    required String id,
    required String hostUid,
    required String hostName,
    required int maxPlayers,
    bool isPublic = false,
  }) async {
    final host = KadiPlayer(uid: hostUid, name: hostName, hand: const []);
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
    final data = _serializeRoom(room);
    await _games.doc(id).set(data);
    return room.state;
  }

  Future<void> addPlayer(
    String gameId, {
    required String uid,
    required String name,
  }) async {
    await _mutate(gameId, (room) {
      final state = room.state;
      if (state.players.any((p) => p.uid == uid)) {
        return false;
      }
      if (state.players.length >= state.maxPlayers) {
        return false;
      }

      final players = List<KadiPlayer>.from(state.players)
        ..add(KadiPlayer(uid: uid, name: name, hand: const []));

      room.state = state.copyWith(
        players: players,
        eventLog: _appendLog(state.eventLog, '$name joined the room'),
      );

      if (players.length >= 2 && players.length == state.maxPlayers) {
        _startRound(room);
      }

      return true;
    });
  }

  Future<void> removePlayer(String gameId, String uid) async {
    await _mutate(gameId, (room) {
      final state = room.state;
      if (!state.players.any((p) => p.uid == uid)) {
        return false;
      }

      final players = List<KadiPlayer>.from(state.players)
        ..removeWhere((p) => p.uid == uid);

      if (players.isEmpty) {
        room.rules = const RuleState();
        room.state = state.copyWith(
          players: const [],
          gameStatus: 'waiting',
          drawPile: const <KadiCard>[],
          discardPile: const <KadiCard>[],
          turnIndex: 0,
          winnerUid: null,
          eventLog: _appendLog(state.eventLog, 'All players left. Room reset'),
        );
        return true;
      }

      room.rules = const RuleState();
      room.state = state.copyWith(
        players: players,
        drawPile: const <KadiCard>[],
        discardPile: const <KadiCard>[],
        gameStatus: 'waiting',
        turnIndex: 0,
        winnerUid: null,
        eventLog: _appendLog(state.eventLog, 'Player left the game'),
      );
      return true;
    });
  }

  Future<void> playCard(
    String gameId,
    String playerId,
    KadiCard card, {
    Suit? chosenSuit,
    Rank? requestedRank,
  }) async {
    await _mutate(gameId, (room) {
      if (room.state.gameStatus != 'playing') {
        return false;
      }

      final state = room.state;
      final players = List<KadiPlayer>.from(state.players);
      if (players.isEmpty) return false;

      final turnPlayer = players[state.turnIndex];
      if (turnPlayer.uid != playerId) return false;

      final handIndex = turnPlayer.hand.indexWhere((c) => c.id == card.id);
      if (handIndex == -1) return false;

      final isSkipTarget = room.rules.skipCount > 0;
      final validation = RuleEngine.canPlay(
        state: room.rules,
        card: card,
        topCard: state.discardPile.last,
        playerHand: turnPlayer.hand,
        isSkipTarget: isSkipTarget,
      );
      if (!validation.isValid) {
        return false;
      }

      if (card.isAce && room.rules.pendingDraw == 0) {
        if (card.isAceOfSpades) {
          if (requestedRank == null && chosenSuit == null) {
            return false;
          }
        } else {
          if (chosenSuit == null) {
            return false;
          }
        }
      }

      final discard = List<KadiCard>.from(state.discardPile)..add(card);
      final drawPile = List<KadiCard>.from(state.drawPile);

      final updatedHand = List<KadiCard>.from(turnPlayer.hand)..removeAt(handIndex);
      players[state.turnIndex] = turnPlayer.copyWith(hand: updatedHand);

      var rules = room.rules;
      final nikoRequired =
          rules.nikoPending.contains(playerId) || rules.nikoDeclared.contains(playerId);
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
            eventLog: _appendLog(state.eventLog, logMessage),
          );
          room.state = finished;
          room.scheduleRestart = true;
          return true;
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
            eventLog: _appendLog(
              state.eventLog,
              '$logMessage (no Niko Kadi call)',
            ),
          );
          room.rules = rules;
          room.state = updated;
          return true;
        }
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
      room.state = state.copyWith(
        players: players,
        discardPile: discard,
        drawPile: drawPile,
        turnIndex: nextIndex,
        eventLog: _appendLog(state.eventLog, logMessage),
      );
      return true;
    });
  }

  Future<void> drawCard(String gameId, String playerId) async {
    await _mutate(gameId, (room) {
      if (room.state.gameStatus != 'playing') {
        return false;
      }

      final state = room.state;
      final players = List<KadiPlayer>.from(state.players);
      if (players.isEmpty) return false;

      final turnPlayer = players[state.turnIndex];
      if (turnPlayer.uid != playerId) return false;

      if (room.rules.skipCount > 0 && room.rules.skipCancelable) {
        return _pass(room, turnPlayer);
      }

      final drawCount = room.rules.pendingDraw > 0 ? room.rules.pendingDraw : 1;
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
      room.state = state.copyWith(
        players: players,
        drawPile: drawResult.drawPile,
        discardPile: drawResult.discardPile,
        eventLog: _appendLog(state.eventLog, message),
      );

      if (room.rules.pendingDraw == 0 && room.rules.questionSuit == null) {
        _pass(room, players[state.turnIndex]);
      }

      return true;
    });
  }

  Future<void> passTurn(String gameId, String playerId) async {
    await _mutate(gameId, (room) {
      if (room.state.gameStatus != 'playing') {
        return false;
      }

      final state = room.state;
      final players = List<KadiPlayer>.from(state.players);
      if (players.isEmpty) return false;

      final turnPlayer = players[state.turnIndex];
      if (turnPlayer.uid != playerId) return false;

      return _pass(room, turnPlayer);
    });
  }

  Future<void> declareNikoKadi(String gameId, String playerId) async {
    await _mutate(gameId, (room) {
      if (room.state.gameStatus != 'playing') {
        return false;
      }
      if (!room.rules.nikoPending.contains(playerId)) {
        return false;
      }

      room.rules = RuleEngine.markNikoDeclared(room.rules, playerId);
      final player = room.state.players.firstWhere(
        (p) => p.uid == playerId,
        orElse: () => KadiPlayer(uid: playerId, name: 'Player', hand: const []),
      );

      room.state = room.state.copyWith(
        eventLog: _appendLog(
          room.state.eventLog,
          '${player.name} called Niko Kadi!',
        ),
      );
      return true;
    });
  }

  String randomId() => 'g_${Random().nextInt(1 << 32)}';

  Future<void> _mutate(
    String gameId,
    bool Function(_Room room) mutator,
  ) async {
    final ref = _games.doc(gameId);
    var shouldRestart = false;
    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(ref);
      if (!snapshot.exists) {
        throw StateError('Game not found');
      }
      final room = _roomFromData(snapshot.data()!);
      final changed = mutator(room);
      if (!changed) {
        return;
      }
      shouldRestart = room.scheduleRestart;
      room.scheduleRestart = false;
      final data = _serializeRoom(room);
      txn.set(ref, data);
    });
    if (shouldRestart) {
      _scheduleRestart(gameId);
    }
  }

  bool _pass(_Room room, KadiPlayer player) {
    var rules = room.rules;
    if (rules.skipCount > 0) {
      rules = RuleEngine.clearAfterSkipResolution(rules);
    }

    final nextIndex = RuleEngine.nextPlayerIndex(
      state: rules,
      currentIndex: room.state.turnIndex,
      playerCount: room.state.players.length,
    );

    room.rules = rules;
    room.state = room.state.copyWith(
      turnIndex: nextIndex,
      eventLog: _appendLog(room.state.eventLog, '${player.name} passed'),
    );
    return true;
  }

  void _startRound(_Room room) {
    if (room.state.players.length < 2) {
      return;
    }

    final rnd = Random();
    final deck = KadiCard.fullDeck();

    final players = room.state.players.map((p) => p.copyWith(hand: const [])).toList()
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

    room.state = room.state.copyWith(
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
  }

  void _scheduleRestart(String gameId) {
    Future.delayed(const Duration(seconds: 3), () async {
      final ref = _games.doc(gameId);
      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(ref);
        if (!snapshot.exists) {
          return;
        }
        final room = _roomFromData(snapshot.data()!);
        if (room.state.gameStatus != 'finished') {
          return;
        }
        if (room.state.players.length < 2) {
          room.rules = const RuleState();
          room.state = room.state.copyWith(
            gameStatus: 'waiting',
            drawPile: const <KadiCard>[],
            discardPile: const <KadiCard>[],
            turnIndex: 0,
            winnerUid: null,
            eventLog: _appendLog(
              room.state.eventLog,
              'Waiting for more players',
            ),
          );
        } else {
          _startRound(room);
        }
        final data = _serializeRoom(room);
        txn.set(ref, data);
      });
    });
  }

  _Room _roomFromData(Map<String, dynamic> data) {
    final stateJson = Map<String, dynamic>.from(
      (data['state'] as Map<String, dynamic>?) ?? const {},
    );
    final state = GameState.fromJson(stateJson);

    final rulesJson = Map<String, dynamic>.from(
      (data['rules'] as Map<String, dynamic>?) ?? const {},
    );

    final rules = RuleState(
      forcedSuit: _parseSuit(rulesJson['forcedSuit'] as String?),
      requestedRank: _parseRank(rulesJson['requestedRank'] as String?),
      questionSuit: _parseSuit(rulesJson['questionSuit'] as String?),
      pendingDraw: (rulesJson['pendingDraw'] ?? 0) as int,
      clockwise: (rulesJson['clockwise'] ?? true) as bool,
      skipCount: (rulesJson['skipCount'] ?? 0) as int,
      skipCancelable: (rulesJson['skipCancelable'] ?? false) as bool,
      nikoPending: ((rulesJson['nikoPending'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toSet()),
      nikoDeclared: ((rulesJson['nikoDeclared'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toSet()),
    );

    return _Room(
      state: state,
      rules: rules,
      isPublic: (data['isPublic'] ?? false) as bool,
    );
  }

  Map<String, dynamic> _serializeRoom(_Room room) {
    final synced = _syncRoom(room);
    return {
      'state': synced.toJson(),
      'rules': {
        'forcedSuit': room.rules.forcedSuit?.name,
        'requestedRank': room.rules.requestedRank?.name,
        'questionSuit': room.rules.questionSuit?.name,
        'pendingDraw': room.rules.pendingDraw,
        'clockwise': room.rules.clockwise,
        'skipCount': room.rules.skipCount,
        'skipCancelable': room.rules.skipCancelable,
        'nikoPending': room.rules.nikoPending.toList(),
        'nikoDeclared': room.rules.nikoDeclared.toList(),
      },
      'isPublic': room.isPublic,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  GameState _syncRoom(_Room room) {
    final synced = room.state.copyWith(
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
    return synced;
  }

  Suit? _parseSuit(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final suit in Suit.values) {
      if (suit.name == value) {
        return suit;
      }
    }
    return null;
  }

  Rank? _parseRank(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final rank in Rank.values) {
      if (rank.name == value) {
        return rank;
      }
    }
    return null;
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

  String _describePlay(
    String playerName,
    KadiCard card,
    Suit? chosenSuit,
    Rank? requestedRank,
  ) {
    final buffer = StringBuffer(
        '$playerName played ${card.rank.label} of ${card.suit.label}');
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
}

class _DrawResult {
  final List<KadiCard> drawPile;
  final List<KadiCard> discardPile;
  final List<KadiCard> drawn;

  const _DrawResult({
    required this.drawPile,
    required this.discardPile,
    required this.drawn,
  });
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
  bool scheduleRestart = false;
}
