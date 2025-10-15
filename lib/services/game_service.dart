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
  final Map<String, Timer> _turnTimers = {};
  final Map<String, _TurnInfo> _turnInfos = {};

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
    Suit? requestedCardSuit,
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
          final requestingCard = requestedRank != null;
          final changingSuit = chosenSuit != null;
          if (!requestingCard && !changingSuit) {
            return false;
          }
          if (requestedCardSuit != null && requestedRank == null) {
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
        requestedCardSuit: requestedCardSuit,
      );

      final updatedStrikes = Map<String, int>.from(rules.idleStrikes);
      updatedStrikes.remove(playerId);
      rules = rules.copyWith(idleStrikes: updatedStrikes);

      final logMessage = _describePlay(
        turnPlayer.name,
        card,
        chosenSuit,
        requestedRank,
        requestedCardSuit,
      );

      if (updatedHand.isEmpty) {
        rules = RuleEngine.removeNikoFlags(rules, playerId);
        room.rules = rules.copyWith(clearTurnDeadline: true);
        room.turnChanged = true;

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
          room.rules = rules.copyWith(
            turnDeadline: DateTime.now().add(const Duration(seconds: 10)),
          );
          room.state = updated;
          room.turnChanged = true;
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

      room.rules = rules.copyWith(
        turnDeadline: DateTime.now().add(const Duration(seconds: 10)),
      );
      room.state = state.copyWith(
        players: players,
        discardPile: discard,
        drawPile: drawPile,
        turnIndex: nextIndex,
        eventLog: _appendLog(state.eventLog, logMessage),
      );
      room.turnChanged = true;
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
          clearRequestedCardSuit: true,
          clearRequiredJokerColor: true,
          clearActiveJokerColor: true,
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

      final updatedStrikes = Map<String, int>.from(rules.idleStrikes);
      updatedStrikes.remove(playerId);
      rules = rules.copyWith(idleStrikes: updatedStrikes);

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

      final updatedStrikes = Map<String, int>.from(room.rules.idleStrikes);
      updatedStrikes.remove(playerId);
      room.rules = room.rules.copyWith(idleStrikes: updatedStrikes);

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
    var shouldRescheduleTurn = false;
    DateTime? deadline;
    String? turnPlayerId;
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
      shouldRescheduleTurn = room.turnChanged;
      if (room.turnChanged) {
        deadline = room.rules.turnDeadline;
        if (room.state.gameStatus == 'playing' && room.state.players.isNotEmpty) {
          final currentIndex = room.state.turnIndex % room.state.players.length;
          turnPlayerId = room.state.players[currentIndex].uid;
        } else {
          turnPlayerId = null;
        }
        room.turnChanged = false;
      }
      final data = _serializeRoom(room);
      txn.set(ref, data);
    });
    if (shouldRestart) {
      _scheduleRestart(gameId);
    }
    if (shouldRescheduleTurn) {
      _scheduleTurnTimer(gameId, deadline, turnPlayerId);
    }
  }

  bool _pass(_Room room, KadiPlayer player, {String? logMessage}) {
    var rules = room.rules;
    if (rules.skipCount > 0) {
      rules = RuleEngine.clearAfterSkipResolution(rules);
    }

    final nextIndex = RuleEngine.nextPlayerIndex(
      state: rules,
      currentIndex: room.state.turnIndex,
      playerCount: room.state.players.length,
    );

    final hasNextPlayer = room.state.players.length > 1;
    room.rules = rules.copyWith(
      turnDeadline: hasNextPlayer
          ? DateTime.now().add(const Duration(seconds: 10))
          : null,
    );
    room.state = room.state.copyWith(
      turnIndex: nextIndex,
      eventLog: _appendLog(
        room.state.eventLog,
        logMessage ?? '${player.name} passed',
      ),
    );
    room.turnChanged = true;
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

    final ordinaryStarters = deck.where((c) => c.isOrdinary).toList();
    KadiCard starter;
    if (ordinaryStarters.isEmpty) {
      starter = deck.removeLast();
    } else {
      starter = ordinaryStarters[rnd.nextInt(ordinaryStarters.length)];
      deck.removeWhere((c) => c.id == starter.id);
    }
    final discard = <KadiCard>[starter];

    final turnIndex = rnd.nextInt(players.length);

    room.rules = const RuleState().copyWith(
      turnDeadline: DateTime.now().add(const Duration(seconds: 10)),
      idleStrikes: const <String, int>{},
    );

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
    room.turnChanged = true;
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

  void _scheduleTurnTimer(String gameId, DateTime? deadline, String? playerId) {
    _turnTimers[gameId]?.cancel();
    if (deadline == null || playerId == null) {
      _turnInfos.remove(gameId);
      _turnTimers.remove(gameId);
      return;
    }

    final now = DateTime.now();
    final delay = deadline.difference(now);
    _turnInfos[gameId] = _TurnInfo(playerId: playerId, deadline: deadline);

    if (delay.isNegative) {
      Future.microtask(() => _handleTurnTimeout(gameId));
      return;
    }

    _turnTimers[gameId] = Timer(delay, () => _handleTurnTimeout(gameId));
  }

  Future<void> _handleTurnTimeout(String gameId) async {
    final info = _turnInfos[gameId];
    await _mutate(gameId, (room) {
      if (room.state.gameStatus != 'playing') {
        return false;
      }
      if (room.state.players.isEmpty) {
        return false;
      }

      final deadline = room.rules.turnDeadline;
      final now = DateTime.now();
      if (deadline == null || now.isBefore(deadline)) {
        return false;
      }

      final players = List<KadiPlayer>.from(room.state.players);
      final currentIndex = room.state.turnIndex % players.length;
      final currentPlayer = players[currentIndex];

      if (info != null && info.playerId != null && info.playerId != currentPlayer.uid) {
        return false;
      }

      final drawCount = room.rules.pendingDraw > 0 ? room.rules.pendingDraw : 1;
      final drawResult = _drawCards(room.state.drawPile, room.state.discardPile, drawCount);
      final newHand = List<KadiCard>.from(currentPlayer.hand)..addAll(drawResult.drawn);
      players[currentIndex] = currentPlayer.copyWith(hand: newHand);

      var rules = room.rules;
      String message;
      if (room.rules.pendingDraw > 0) {
        message =
            '${currentPlayer.name} timed out and drew ${drawResult.drawn.length} penalty cards';
        rules = rules.copyWith(
          pendingDraw: 0,
          skipCancelable: false,
          clearForcedSuit: true,
          clearRequestedRank: true,
          clearRequestedCardSuit: true,
          clearRequiredJokerColor: true,
          clearActiveJokerColor: true,
        );
      } else if (room.rules.questionSuit != null) {
        message = '${currentPlayer.name} timed out on a question and drew a card';
        rules = rules.copyWith(clearQuestionSuit: true, skipCancelable: false);
      } else {
        message = '${currentPlayer.name} timed out and drew a card';
      }

      rules = RuleEngine.cancelRequestedRankIfImpossible(
        state: rules,
        playerHand: newHand,
      );

      if (RuleEngine.needsNikoCall(newHand)) {
        rules = RuleEngine.markNikoPending(rules, currentPlayer.uid);
      } else {
        rules = RuleEngine.removeNikoFlags(rules, currentPlayer.uid);
      }

      final strikes = Map<String, int>.from(rules.idleStrikes);
      final strikeCount = (strikes[currentPlayer.uid] ?? 0) + 1;
      strikes[currentPlayer.uid] = strikeCount;

      if (strikeCount >= 3) {
        final removalMessage = '$message. ${currentPlayer.name} was removed after 3 timeouts.';
        final recycled = List<KadiCard>.from(newHand);
        final remainingPlayers = List<KadiPlayer>.from(players)..removeAt(currentIndex);
        var drawPile = List<KadiCard>.from(drawResult.drawPile)..addAll(recycled);
        drawPile.shuffle();
        final discardPile = List<KadiCard>.from(drawResult.discardPile);

        rules = rules.copyWith(
          idleStrikes: Map<String, int>.from(strikes)..remove(currentPlayer.uid),
          clearRequestedRank: true,
          clearRequestedCardSuit: true,
          clearForcedSuit: true,
          skipCancelable: false,
          clearRequiredJokerColor: true,
          clearActiveJokerColor: true,
        );
        rules = RuleEngine.removeNikoFlags(rules, currentPlayer.uid);

        if (remainingPlayers.isEmpty) {
          room.rules = const RuleState();
          room.state = room.state.copyWith(
            players: const [],
            drawPile: const <KadiCard>[],
            discardPile: const <KadiCard>[],
            gameStatus: 'waiting',
            winnerUid: null,
            turnIndex: 0,
            eventLog: _appendLog(room.state.eventLog, removalMessage),
          );
          room.turnChanged = true;
          return true;
        }

        final updatedLog = _appendLog(room.state.eventLog, removalMessage);
        if (remainingPlayers.length == 1) {
          final winner = remainingPlayers.first;
          room.state = room.state.copyWith(
            players: remainingPlayers,
            drawPile: drawPile,
            discardPile: discardPile,
            turnIndex: 0,
            gameStatus: 'finished',
            winnerUid: winner.uid,
            eventLog: updatedLog,
          );
          room.rules = rules.copyWith(clearTurnDeadline: true);
          room.turnChanged = true;
          room.scheduleRestart = true;
          return true;
        }

        final nextIndex = currentIndex % remainingPlayers.length;
        room.state = room.state.copyWith(
          players: remainingPlayers,
          drawPile: drawPile,
          discardPile: discardPile,
          turnIndex: nextIndex,
          eventLog: updatedLog,
        );
        room.rules = rules.copyWith(
          turnDeadline: DateTime.now().add(const Duration(seconds: 10)),
        );
        room.turnChanged = true;
        return true;
      }

      rules = rules.copyWith(idleStrikes: strikes);

      room.rules = rules;
      room.state = room.state.copyWith(
        players: players,
        drawPile: drawResult.drawPile,
        discardPile: drawResult.discardPile,
      );

      _pass(room, players[currentIndex], logMessage: message);
      return true;
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
      requestedCardSuit: _parseSuit(rulesJson['requestedCardSuit'] as String?),
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
      activeJokerColor: _parseCardColor(rulesJson['activeJokerColor'] as String?),
      requiredJokerColor: _parseCardColor(rulesJson['requiredJokerColor'] as String?),
      turnDeadline: _parseDateTime(rulesJson['turnDeadline'] as String?),
      idleStrikes: Map<String, int>.from(
        (rulesJson['idleStrikes'] as Map<String, dynamic>? ?? const {}),
      ),
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
        'requestedCardSuit': room.rules.requestedCardSuit?.name,
        'questionSuit': room.rules.questionSuit?.name,
        'pendingDraw': room.rules.pendingDraw,
        'clockwise': room.rules.clockwise,
        'skipCount': room.rules.skipCount,
        'skipCancelable': room.rules.skipCancelable,
        'nikoPending': room.rules.nikoPending.toList(),
        'nikoDeclared': room.rules.nikoDeclared.toList(),
        'activeJokerColor': room.rules.activeJokerColor?.name,
        'requiredJokerColor': room.rules.requiredJokerColor?.name,
        'turnDeadline': room.rules.turnDeadline?.toIso8601String(),
        'idleStrikes': room.rules.idleStrikes,
      },
      'isPublic': room.isPublic,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  GameState _syncRoom(_Room room) {
    final synced = room.state.copyWith(
      requiredSuit: room.rules.forcedSuit,
      requestedRank: room.rules.requestedRank,
      requestedCardSuit: room.rules.requestedCardSuit,
      questionSuit: room.rules.questionSuit,
      pendingDraw: room.rules.pendingDraw,
      clockwise: room.rules.clockwise,
      skipCount: room.rules.skipCount,
      nikoPending: room.rules.nikoPending.toList(),
      nikoDeclared: room.rules.nikoDeclared.toList(),
      requiredJokerColor: room.rules.requiredJokerColor,
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

  CardColor? _parseCardColor(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final color in CardColor.values) {
      if (color.name == value) {
        return color;
      }
    }
    return null;
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
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
    Suit? requestedCardSuit,
  ) {
    final buffer = StringBuffer(
        '$playerName played ${card.rank.label} of ${card.suit.label}');
    if (card.isAce && chosenSuit != null && card.isAceOfSpades == false) {
      buffer.write(' choosing ${chosenSuit.label}');
    }
    if (card.isAceOfSpades && requestedRank != null) {
      if (requestedCardSuit != null) {
        buffer.write(
            ' requesting ${requestedRank.label} of ${requestedCardSuit.label}');
      } else {
        buffer.write(' requesting ${requestedRank.label}');
      }
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

class _TurnInfo {
  final String? playerId;
  final DateTime? deadline;

  const _TurnInfo({required this.playerId, required this.deadline});
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
  bool turnChanged = false;
}
