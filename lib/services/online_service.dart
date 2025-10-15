import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/game_state.dart';
import '../models/kadi_card.dart';
import 'game_service.dart';
import 'matchmaking_service.dart';

/// High level façade used by the UI to interact with the multiplayer engine.
/// It wraps the Firestore-backed [GameService] with matchmaking helpers so that
/// the rest of the app does not need to know about rooms, decks or rule state.
class OnlineService {
  OnlineService._internal() {
    _initAuth();
  }

  static final OnlineService _instance = OnlineService._internal();
  factory OnlineService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MatchmakingService _matchmaking = MatchmakingService();
  final GameService _game = GameService();
  final Completer<void> _readyCompleter = Completer<void>();
  final Map<String, String> _codeToGameId = {};

  String _fallbackUid = 'p_${Random().nextInt(0x7fffffff)}';

  Future<void> get ready => _readyCompleter.future;

  String get uid => _auth.currentUser?.uid ?? _fallbackUid;

  Future<void> _initAuth() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      _fallbackUid = _auth.currentUser?.uid ?? _fallbackUid;
    } catch (_) {
      // Offline fallback keeps the pseudo UID so local play still works.
    } finally {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    }
  }

  /// Create a private invite room. Returns the room code to share.
  Future<String> createInviteRoom({
    required String nickname,
    required int seats,
    bool isPublic = false,
  }) async {
    await ready;
    final code = await _matchmaking.createRoom(
      hostUid: uid,
      hostName: nickname,
      seats: seats,
      isPublic: isPublic,
    );
    final gameId = await _matchmaking.gameIdForCode(code);
    if (gameId != null) {
      _codeToGameId[code] = gameId;
    }
    return code;
  }

  /// Join an invite room by code. Returns the gameId once joined.
  Future<String?> joinRoom({
    required String code,
    required String nickname,
  }) async {
    await ready;
    final joinedGame = await _matchmaking.joinRoom(
      code: code,
      uid: uid,
      name: nickname,
    );
    if (joinedGame != null) {
      _codeToGameId[code] = joinedGame;
      await _matchmaking.refreshRoom(code);
    }
    return joinedGame;
  }

  /// Quick matchmaking by player count. Returns the gameId.
  Future<String> quickPlay({
    required String nickname,
    required int seats,
  }) async {
    await ready;
    final gameId = await _matchmaking.quickPlay(
      uid: uid,
      name: nickname,
      seats: seats,
    );
    return gameId;
  }

  /// Resolve a room code into its live [GameState] stream.
  Stream<GameState> watchRoom(String code) {
    final controller = StreamController<GameState>.broadcast();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? roomSub;
    StreamSubscription<GameState>? gameSub;
    String? currentGameId;

    void listenToGame(String? gameId) {
      if (gameId == currentGameId) {
        return;
      }
      currentGameId = gameId;
      gameSub?.cancel();
      if (gameId == null) {
        return;
      }
      _codeToGameId[code] = gameId;
      gameSub = _game.watch(gameId).listen(
        controller.add,
        onError: controller.addError,
      );
    }

    roomSub = _firestore.collection('rooms').doc(code).snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) {
          listenToGame(null);
          controller.addError(StateError('Room not found'));
          return;
        }
        final gameId = snapshot.data()?['gameId'] as String?;
        listenToGame(gameId);
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await roomSub?.cancel();
      await gameSub?.cancel();
    };

    return controller.stream;
  }

  Future<GameState?> getGame(String gameId) => _game.getState(gameId);

  Future<GameState?> getGameByCode(String code) async {
    final gameId = await _resolveGameId(code);
    if (gameId == null) return null;
    return _game.getState(gameId);
  }

  void playCard({
    required String code,
    required KadiCard card,
    Suit? chosenSuit,
    Rank? requestedRank,
    Suit? requestedCardSuit,
  }) {
    _invokeGameAction(code, (gameId) {
      return _game.playCard(
        gameId,
        uid,
        card,
        chosenSuit: chosenSuit,
        requestedRank: requestedRank,
        requestedCardSuit: requestedCardSuit,
      );
    });
  }

  void drawCard(String code) {
    _invokeGameAction(code, (gameId) => _game.drawCard(gameId, uid));
  }

  void finishCombo(String code) {
    _invokeGameAction(code, (gameId) => _game.finishCombo(gameId, uid));
  }

  void passTurn(String code) {
    _invokeGameAction(code, (gameId) => _game.passTurn(gameId, uid));
  }

  void startGame(String code) {
    _invokeGameAction(code, (gameId) => _game.startGame(gameId, uid));
  }

  void declareNikoKadi(String code) {
    _invokeGameAction(code, (gameId) => _game.declareNikoKadi(gameId, uid));
  }

  void leaveGame(String code) {
    _invokeGameAction(code, (gameId) async {
      await _game.removePlayer(gameId, uid);
      await _matchmaking.refreshRoom(code);
    });
  }

  void _invokeGameAction(
    String code,
    Future<void> Function(String gameId) callback,
  ) {
    unawaited(() async {
      await ready;
      final gameId = await _resolveGameId(code);
      if (gameId == null) {
        return;
      }
      await callback(gameId);
      await _matchmaking.refreshRoom(code);
    }());
  }

  Future<String?> _resolveGameId(String code) async {
    if (_codeToGameId.containsKey(code)) {
      return _codeToGameId[code];
    }
    final fetched = await _matchmaking.gameIdForCode(code);
    if (fetched != null) {
      _codeToGameId[code] = fetched;
    }
    return fetched;
  }
}
