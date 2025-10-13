import 'dart:math';
import '../models/game_state.dart';
import '../models/kadi_card.dart';
import '../models/kadi_player.dart';
import 'game_service.dart';

/// Matchmaking & room management over the local in-memory GameService.
/// If you later switch to Firestore, keep the same API and swap internals.
class MatchmakingService {
  static final MatchmakingService _i = MatchmakingService._internal();
  factory MatchmakingService() => _i;
  MatchmakingService._internal();

  final _svc = GameService();
  final _rooms = <String, String>{}; // roomCode -> gameId

  /// Create a room (game) with host as first player. Returns room code.
  Future<String> createRoom({
    required String hostUid,
    required String hostName,
  }) async {
    final gameId = _svc.randomId();
    _svc.createGame(id: gameId, hostUid: hostUid, hostName: hostName);

    // simple 6-letter uppercase code
    final code = _makeCode();
    _rooms[code] = gameId;
    return code;
  }

  /// Join an existing room by code. Returns the gameId.
  Future<String> joinRoom(String code, String uid, String name) async {
    final gameId = _rooms[code];
    if (gameId == null) {
      throw StateError('Room not found');
    }
    _svc.addPlayer(gameId, uid: uid, name: name);
    return gameId;
  }

  /// Quick play: join the first waiting room or create a new one.
  Future<String> quickJoinOrCreate(String uid, String name) async {
    // naive: pick any existing room with 'waiting'
    for (final entry in _rooms.entries) {
      final state = await watchOnce(entry.value);
      if (state.gameStatus == 'waiting') {
        _svc.addPlayer(entry.value, uid: uid, name: name);
        return entry.value;
      }
    }
    // create host as you
    final code = await createRoom(hostUid: uid, hostName: name);
    return _rooms[code]!;
  }

  /// Utility to fetch a single snapshot once from GameService stream.
  Future<GameState> watchOnce(String gameId) async {
    return await _svc.watch(gameId).first;
  }

  String _makeCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return List.generate(6, (_) => letters[rnd.nextInt(letters.length)]).join();
  }
}