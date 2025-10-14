import 'dart:math';

import '../models/game_state.dart';
import '../models/kadi_card.dart';
import 'game_service.dart';
import 'matchmaking_service.dart';

/// High level façade used by the UI to interact with the multiplayer engine.
/// It wraps the in-memory [GameService] with matchmaking helpers so that the
/// rest of the app does not need to know about rooms, decks or rule state.
class OnlineService {
  OnlineService()
      : _uid = 'p_${Random().nextInt(1 << 32)}';

  final GameService _game = GameService();
  final MatchmakingService _matchmaking = MatchmakingService();
  final String _uid;

  String get uid => _uid;

  /// Create a private invite room. Returns the room code to share.
  Future<String> createInviteRoom({
    required String nickname,
    required int seats,
  }) async {
    return _matchmaking.createRoom(
      hostUid: uid,
      hostName: nickname,
      seats: seats,
    );
  }

  /// Join an invite room by code. Returns the gameId once joined.
  Future<String?> joinRoom({
    required String code,
    required String nickname,
  }) async {
    try {
      return _matchmaking.joinRoom(code, uid, nickname);
    } on StateError {
      return null;
    }
  }

  /// Quick matchmaking by player count. Returns the gameId.
  Future<String> quickPlay({
    required String nickname,
    required int seats,
  }) async {
    return _matchmaking.quickPlay(uid: uid, name: nickname, seats: seats);
  }

  /// Resolve a room code into its live [GameState] stream.
  Stream<GameState> watchRoom(String code) {
    final gameId = _matchmaking.gameIdForCode(code);
    if (gameId == null) {
      return const Stream.empty();
    }
    return _game.watch(gameId);
  }

  GameState? getGameByCode(String code) {
    final gameId = _matchmaking.gameIdForCode(code);
    if (gameId == null) return null;
    return _game.getState(gameId);
  }

  GameState? getGame(String gameId) => _game.getState(gameId);

  void playCard({
    required String code,
    required KadiCard card,
    Suit? chosenSuit,
    Rank? requestedRank,
  }) {
    final gameId = _matchmaking.gameIdForCode(code);
    if (gameId == null) return;
    _game.playCard(gameId, uid, card, chosenSuit: chosenSuit, requestedRank: requestedRank);
  }

  void drawCard(String code) {
    final gameId = _matchmaking.gameIdForCode(code);
    if (gameId == null) return;
    _game.drawCard(gameId, uid);
  }

  void passTurn(String code) {
    final gameId = _matchmaking.gameIdForCode(code);
    if (gameId == null) return;
    _game.passTurn(gameId, uid);
  }

  void declareNikoKadi(String code) {
    final gameId = _matchmaking.gameIdForCode(code);
    if (gameId == null) return;
    _game.declareNikoKadi(gameId, uid);
  }

  void leaveGame(String code) {
    final gameId = _matchmaking.gameIdForCode(code);
    if (gameId == null) return;
    _game.removePlayer(gameId, uid);
  }
}
