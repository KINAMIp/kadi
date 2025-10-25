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

  static const int _initialHandSize = 5;
  static const Duration _turnDuration = Duration(seconds: 30);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RuleEngine _engine = const RuleEngine();

  final Map<String, Timer> _turnTimers = {};
  final Map<String, Timer> _jumpTimers = {};
  final Map<String, Timer> _kickTimers = {};

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('games');

  Stream<GameState> watch(String gameId) {
    return _games.doc(gameId).snapshots().where((event) => event.exists).map(
      (snapshot) {
        final data = snapshot.data()!;
        return _roomFromData(data).state;
      },
    );
  }

  Future<GameState?> getState(String gameId) async {
    final snapshot = await _games.doc(gameId).get();
    if (!snapshot.exists) return null;
    return _roomFromData(snapshot.data()!).state;
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
      hostUid: hostUid,
      hostName: hostName,
      drawPile: const [],
      discardPile: const [],
      turnIndex: 0,
      gameStatus: 'waiting',
      createdAt: DateTime.now(),
      maxPlayers: maxPlayers,
      eventLog: ['Room created by $hostName'],
    );
    final room = _Room(state: state, isPublic: isPublic);
    await _games.doc(id).set(_serializeRoom(room));
    return state;
  }

  Future<void> addPlayer(
    String gameId, {
    required String uid,
    required String name,
  }) async {
    await _mutate(gameId, (room) {
      if (room.state.players.any((p) => p.uid == uid)) {
        throw StateError('Player already joined.');
      }
      if (room.state.players.length >= room.state.maxPlayers) {
        throw StateError('Lobby is full.');
      }
      if (room.state.gameStatus != 'waiting') {
        throw StateError('Game already started.');
      }
      final players = List<KadiPlayer>.from(room.state.players)
        ..add(KadiPlayer(uid: uid, name: name, hand: const []));
      room.state = room.state.copyWith(
        players: players,
        eventLog: List<String>.from(room.state.eventLog)
          ..add('$name joined the table.'),
      );
      return true;
    });
  }

  Future<void> removePlayer(String gameId, String uid) async {
    await _mutate(gameId, (room) {
      final players = List<KadiPlayer>.from(room.state.players);
      final index = players.indexWhere((p) => p.uid == uid);
      if (index == -1) {
        return false;
      }
      final name = players[index].name;
      players.removeAt(index);
      var turnIndex = room.state.turnIndex;
      if (turnIndex >= players.length) {
        turnIndex = players.isEmpty ? 0 : turnIndex % players.length;
      }
      room.state = room.state.copyWith(
        players: players,
        turnIndex: turnIndex,
        eventLog: List<String>.from(room.state.eventLog)
          ..add('$name left the table.'),
      );
      if (players.isEmpty) {
        _cancelAllTimers(gameId);
      }
      return true;
    });
  }

  String randomId({int length = 20}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> startGame(String gameId, String hostUid) async {
    await _mutate(gameId, (room) {
      if (room.state.gameStatus != 'waiting') {
        throw StateError('Game already started.');
      }
      if (room.state.players.length < 2) {
        throw StateError('Need at least two players to start.');
      }
      if (room.state.hostUid != hostUid) {
        throw StateError('Only the host can start the game.');
      }
      final deck = KadiCard.fullDeck(includeJokers: true);
      final drawPile = List<KadiCard>.from(deck);
      final players = <KadiPlayer>[];
      for (final player in room.state.players) {
        final hand = <KadiCard>[];
        for (var i = 0; i < _initialHandSize; i++) {
          hand.add(drawPile.removeLast());
        }
        players.add(player.copyWith(hand: hand));
      }
      final discard = <KadiCard>[];
      discard.add(drawPile.removeLast());
      final state = room.state.copyWith(
        gameStatus: 'playing',
        drawPile: drawPile,
        discardPile: discard,
        players: players,
        turnIndex: 0,
        eventLog: List<String>.from(room.state.eventLog)
          ..add('Game started.'),
      );
      room.state = state;
      _scheduleTurnTimer(gameId, state);
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
  }) {
    AceRequest? request;
    if (card.isAceOfSpades && requestedRank != null && requestedCardSuit != null) {
      request = AceRequest(
        requesterId: playerId,
        rank: requestedRank,
        suit: requestedCardSuit,
      );
    }
    return playCards(
      gameId,
      playerId: playerId,
      cardIds: [card.id],
      aceRequest: request,
    );
  }

  Future<void> playCards(
    String gameId, {
    required String playerId,
    required List<String> cardIds,
    AceRequest? aceRequest,
  }) async {
    await _mutate(gameId, (room) {
      final state = room.state;
      if (state.gameStatus != 'playing') {
        throw StateError('Game not running.');
      }
      final playerIndex = state.players.indexWhere((p) => p.uid == playerId);
      if (playerIndex == -1) {
        throw StateError('Player not found.');
      }
      final player = state.players[playerIndex];
      final isPlayersTurn = playerIndex == state.turnIndex;
      final ruleState = RuleState.fromGame(state);
      final jumpActive = ruleState.jumpWindow != null &&
          DateTime.now().isBefore(ruleState.jumpWindow!.expiresAt);
      final kickActive = ruleState.kickWindow != null &&
          DateTime.now().isBefore(ruleState.kickWindow!.expiresAt);
      if (!isPlayersTurn && !jumpActive && !kickActive) {
        throw StateError('Not your turn.');
      }
      final cards = cardIds
          .map((id) => player.hand.firstWhere((c) => c.id == id))
          .toList();
      final outcome = _engine.play(
        game: state,
        player: player,
        cards: cards,
        aceRequest: aceRequest,
      );
      if (!outcome.isValid) {
        throw StateError(outcome.reason ?? 'Invalid move');
      }
      final updatedPlayers = List<KadiPlayer>.from(state.players);
      final updatedHand = List<KadiCard>.from(player.hand);
      for (final card in cards) {
        updatedHand.removeWhere((c) => c.id == card.id);
      }
      updatedPlayers[playerIndex] =
          player.copyWith(hand: updatedHand);
      final discard = List<KadiCard>.from(state.discardPile)..addAll(cards);
      var nextState = outcome.state.apply(state).copyWith(
        players: updatedPlayers,
        discardPile: discard,
        eventLog: List<String>.from(state.eventLog)
          ..addAll(outcome.timeline),
      );
      if (outcome.instruction != null) {
        nextState = nextState.copyWith(
          eventLog: List<String>.from(nextState.eventLog)
            ..add(outcome.instruction!),
        );
      }

      if (!isPlayersTurn) {
        nextState = nextState.copyWith(turnIndex: playerIndex);
      }

      if (outcome.advanceTurn) {
        nextState = _advanceTurn(nextState);
      }

      nextState = _refreshNikoFlags(nextState);
      nextState = _checkForWin(nextState, playerIndex);

      room.state = nextState;

      if (outcome.startJumpTimer) {
        _restartJumpTimer(gameId, nextState);
      } else {
        _cancelJumpTimer(gameId);
      }
      if (outcome.startKickTimer) {
        _restartKickTimer(gameId, nextState);
      } else {
        _cancelKickTimer(gameId);
      }

      if (outcome.startJumpTimer || outcome.startKickTimer) {
        _turnTimers.remove(gameId)?.cancel();
      }

      if (!outcome.startJumpTimer && !outcome.startKickTimer) {
        _scheduleTurnTimer(gameId, nextState);
      }
      return true;
    });
  }

  Future<void> drawCard(String gameId, String playerId) async {
    await drawCards(gameId, playerId);
  }

  Future<void> drawCards(String gameId, String playerId) async {
    await _mutate(gameId, (room) {
      final state = room.state;
      final playerIndex = state.players.indexWhere((p) => p.uid == playerId);
      if (playerIndex == -1) {
        throw StateError('Player not found.');
      }
      if (playerIndex != state.turnIndex) {
        throw StateError('Not your turn to draw.');
      }
      final requestActive =
          state.requestedRank != null && state.requestedCardSuit != null;
      var drawCount = state.pendingDraw > 0 ? state.pendingDraw : 1;
      final drawPile = List<KadiCard>.from(state.drawPile);
      final discard = List<KadiCard>.from(state.discardPile);
      _refillDrawPile(drawPile, discard);
      final drawnCards = <KadiCard>[];
      for (var i = 0; i < drawCount; i++) {
        if (drawPile.isEmpty) break;
        drawnCards.add(drawPile.removeLast());
      }
      final players = List<KadiPlayer>.from(state.players);
      final player = players[playerIndex];
      players[playerIndex] =
          player.copyWith(hand: List<KadiCard>.from(player.hand)..addAll(drawnCards));
      final message = state.pendingDraw > 0
          ? '${player.name} picked $drawCount card${drawCount == 1 ? '' : 's'} from the penalty.'
          : requestActive
              ? '${player.name} could not answer the request and drew 1 card.'
              : '${player.name} drew ${drawnCards.length} card${drawnCards.length == 1 ? '' : 's'}.';
      var nextState = state.copyWith(
        drawPile: drawPile,
        discardPile: discard,
        players: players,
        pendingDraw: 0,
        penaltyStarterId: null,
        requestedRank: null,
        requestedCardSuit: null,
        aceRequesterId: null,
        eventLog: List<String>.from(state.eventLog)..add(message),
      );
      nextState = _advanceTurn(nextState);
      nextState = _refreshNikoFlags(nextState);
      room.state = nextState;
      _scheduleTurnTimer(gameId, nextState);
      return true;
    });
  }

  Future<void> finishCombo(String gameId, String playerId) async {
    await _mutate(gameId, (_) => false);
  }

  Future<void> passTurn(String gameId, String playerId) async {
    await _mutate(gameId, (room) {
      final state = room.state;
      if (state.gameStatus != 'playing') {
        return false;
      }
      final players = state.players;
      if (players.isEmpty) return false;
      final index = state.turnIndex;
      if (players[index].uid != playerId) {
        return false;
      }
      final player = players[index];
      var nextState = state.copyWith(
        eventLog: List<String>.from(state.eventLog)
          ..add('${player.name} passed.'),
      );
      nextState = _advanceTurn(nextState);
      room.state = nextState;
      _scheduleTurnTimer(gameId, nextState);
      return true;
    });
  }

  Future<void> announceNiko(String gameId, String playerId) async {
    await _mutate(gameId, (room) {
      final state = room.state;
      final players = state.players;
      final player = players.firstWhere((p) => p.uid == playerId);
      if (!RuleEngine.winningHand(player.hand)) {
        throw StateError('Hand does not qualify for Niko Kadi.');
      }
      final pending = state.nikoPending.toList();
      final declared = state.nikoDeclared.toList();
      if (!declared.contains(playerId)) {
        declared.add(playerId);
      }
      pending.remove(playerId);
      room.state = state.copyWith(
        nikoPending: pending,
        nikoDeclared: declared,
        eventLog: List<String>.from(state.eventLog)
          ..add('${player.name} announced "Niko Kadi".'),
      );
      return true;
    });
  }

  Future<void> declareNikoKadi(String gameId, String playerId) async {
    await announceNiko(gameId, playerId);
  }

  Future<void> confirmWinner(String gameId, String playerId) async {
    await _mutate(gameId, (room) {
      final state = room.state;
      if (!state.waitingForWinnerConfirmation) {
        return false;
      }
      final confirmations = state.winnerConfirmations.toList();
      if (!confirmations.contains(playerId)) {
        confirmations.add(playerId);
      }
      final allConfirmed = confirmations.length >= state.players.length;
      room.state = state.copyWith(
        winnerConfirmations: confirmations,
        gameStatus: allConfirmed ? 'finished' : state.gameStatus,
        eventLog: allConfirmed
            ? (List<String>.from(state.eventLog)
              ..add('Round complete.'))
            : state.eventLog,
      );
      if (allConfirmed) {
        _cancelAllTimers(gameId);
      }
      return true;
    });
  }

  Future<void> completeJump(String gameId) async {
    await _mutate(gameId, (room) {
      final outcome = _engine.applyJumpExpiry(room.state);
      if (!outcome.isValid) {
        return false;
      }
      var nextState = outcome.state.apply(room.state).copyWith(
        eventLog: List<String>.from(room.state.eventLog)..addAll(outcome.timeline),
      );
      if (outcome.instruction != null) {
        nextState = nextState.copyWith(
          eventLog: List<String>.from(nextState.eventLog)
            ..add(outcome.instruction!),
        );
      }
      nextState = _advanceTurn(nextState);
      room.state = nextState;
      _scheduleTurnTimer(gameId, nextState);
      return true;
    });
  }

  Future<void> completeKick(String gameId) async {
    await _mutate(gameId, (room) {
      final outcome = _engine.applyKickExpiry(room.state);
      if (!outcome.isValid) {
        return false;
      }
      var nextState = outcome.state.apply(room.state).copyWith(
        eventLog: List<String>.from(room.state.eventLog)..addAll(outcome.timeline),
      );
      if (outcome.instruction != null) {
        nextState = nextState.copyWith(
          eventLog: List<String>.from(nextState.eventLog)
            ..add(outcome.instruction!),
        );
      }
      nextState = _advanceTurn(nextState);
      room.state = nextState;
      _scheduleTurnTimer(gameId, nextState);
      return true;
    });
  }

  Future<void> forceAdvance(String gameId) async {
    await _mutate(gameId, (room) {
      room.state = _advanceTurn(room.state);
      _scheduleTurnTimer(gameId, room.state);
      return true;
    });
  }

  void _restartJumpTimer(String gameId, GameState state) {
    _cancelJumpTimer(gameId);
    final expiresAt = state.jumpExpiresAt;
    if (expiresAt == null) return;
    final duration = expiresAt.difference(DateTime.now());
    if (duration.isNegative) {
      completeJump(gameId);
      return;
    }
    _jumpTimers[gameId] = Timer(duration, () => completeJump(gameId));
  }

  void _restartKickTimer(String gameId, GameState state) {
    _cancelKickTimer(gameId);
    final expiresAt = state.kickExpiresAt;
    if (expiresAt == null) return;
    final duration = expiresAt.difference(DateTime.now());
    if (duration.isNegative) {
      completeKick(gameId);
      return;
    }
    _kickTimers[gameId] = Timer(duration, () => completeKick(gameId));
  }

  void _cancelJumpTimer(String gameId) {
    _jumpTimers.remove(gameId)?.cancel();
  }

  void _cancelKickTimer(String gameId) {
    _kickTimers.remove(gameId)?.cancel();
  }

  void _cancelAllTimers(String gameId) {
    _cancelJumpTimer(gameId);
    _cancelKickTimer(gameId);
    _turnTimers.remove(gameId)?.cancel();
  }

  void _scheduleTurnTimer(String gameId, GameState state) {
    _turnTimers.remove(gameId)?.cancel();
    if (state.gameStatus != 'playing') return;
    _turnTimers[gameId] =
        Timer(_turnDuration, () => forceAdvance(gameId));
  }

  GameState _advanceTurn(GameState state) {
    if (state.players.isEmpty) return state;
    var index = state.turnIndex;
    final steps = 1 + state.skipCount;
    final direction = state.clockwise ? 1 : -1;
    index = (index + direction * steps) % state.players.length;
    if (index < 0) {
      index += state.players.length;
    }
    return state.copyWith(
      turnIndex: index,
      skipCount: 0,
    );
  }

  GameState _refreshNikoFlags(GameState state) {
    final pending = <String>[];
    final declared = state.nikoDeclared.toList();
    for (final player in state.players) {
      final qualifies = RuleEngine.winningHand(player.hand);
      if (qualifies && !declared.contains(player.uid)) {
        pending.add(player.uid);
      }
    }
    return state.copyWith(nikoPending: pending);
  }

  GameState _checkForWin(GameState state, int playerIndex) {
    final player = state.players[playerIndex];
    if (player.hand.isNotEmpty) {
      return state;
    }
    if (!state.nikoDeclared.contains(player.uid)) {
      final log = List<String>.from(state.eventLog)
        ..add('${player.name} attempted to win without announcing Niko Kadi.');
      final drawPile = List<KadiCard>.from(state.drawPile);
      final discard = List<KadiCard>.from(state.discardPile);
      _refillDrawPile(drawPile, discard);
      final penalty = drawPile.isEmpty ? null : drawPile.removeLast();
      final updatedPlayers = List<KadiPlayer>.from(state.players);
      final restoredHand = <KadiCard>[];
      if (penalty != null) {
        restoredHand.add(penalty);
      }
      updatedPlayers[playerIndex] =
          player.copyWith(hand: restoredHand);
      return state.copyWith(
        players: updatedPlayers,
        drawPile: drawPile,
        discardPile: discard,
        eventLog: log,
      );
    }
    final log = List<String>.from(state.eventLog)
      ..add('${player.name} finished the round. Waiting for everyone to confirm the winning play.');
    return state.copyWith(
      winnerUid: player.uid,
      waitingForWinnerConfirmation: true,
      winnerConfirmations: const [],
      eventLog: log,
      gameStatus: 'review',
    );
  }

  void _refillDrawPile(List<KadiCard> drawPile, List<KadiCard> discard) {
    if (drawPile.isNotEmpty) return;
    if (discard.length <= 1) return;
    final top = discard.removeLast();
    drawPile.addAll(discard);
    discard
      ..clear()
      ..add(top);
    drawPile.shuffle(Random());
  }

  Future<void> _mutate(
    String gameId,
    bool Function(_Room room) updates,
  ) async {
    final doc = _games.doc(gameId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      if (!snapshot.exists) {
        throw StateError('Game does not exist.');
      }
      final room = _roomFromData(snapshot.data()!);
      final shouldWrite = updates(room);
      if (shouldWrite) {
        transaction.set(doc, _serializeRoom(room));
      }
    });
  }

  _Room _roomFromData(Map<String, dynamic> data) {
    final state = GameState.fromJson(
      Map<String, dynamic>.from(data['state'] as Map),
    );
    final isPublic = (data['isPublic'] ?? false) as bool;
    return _Room(state: state, isPublic: isPublic);
  }

  Map<String, dynamic> _serializeRoom(_Room room) {
    return {
      'state': room.state.toJson(),
      'isPublic': room.isPublic,
    };
  }
}

class _Room {
  _Room({required this.state, required this.isPublic});

  GameState state;
  final bool isPublic;
}
