import 'dart:math';

import '../models/game_state.dart';
import 'game_service.dart';

class MatchmakingService {
  static final MatchmakingService _instance = MatchmakingService._internal();
  factory MatchmakingService() => _instance;
  MatchmakingService._internal();

  final GameService _gameService = GameService();
  final _rooms = <String, _RoomInfo>{};

  Future<String> createRoom({
    required String hostUid,
    required String hostName,
    required int seats,
  }) async {
    _validateSeatCount(seats);
    final gameId = _gameService.randomId();
    _gameService.createGame(
      id: gameId,
      hostUid: hostUid,
      hostName: hostName,
      maxPlayers: seats,
      isPublic: false,
    );
    final code = _generateUniqueCode();
    _rooms[code] = _RoomInfo(gameId: gameId, capacity: seats, isPublic: false);
    return code;
  }

  Future<String> joinRoom(
    String code,
    String uid,
    String name,
  ) async {
    final info = _rooms[code];
    if (info == null) {
      throw StateError('Room not found');
    }

    final state = _gameService.getState(info.gameId);
    if (state == null) {
      throw StateError('Game not initialised');
    }

    if (state.players.any((p) => p.uid == uid)) {
      return info.gameId;
    }

    if (state.players.length >= info.capacity) {
      throw StateError('Room is full');
    }

    _gameService.addPlayer(info.gameId, uid: uid, name: name);
    return info.gameId;
  }

  Future<String> quickPlay({
    required String uid,
    required String name,
    required int seats,
  }) async {
    _validateSeatCount(seats);
    final available = _findPublicRoom(seats);
    if (available != null) {
      _gameService.addPlayer(available.gameId, uid: uid, name: name);
      return available.gameId;
    }

    final gameId = _gameService.randomId();
    _gameService.createGame(
      id: gameId,
      hostUid: uid,
      hostName: name,
      maxPlayers: seats,
      isPublic: true,
    );
    final code = _generateUniqueCode();
    _rooms[code] = _RoomInfo(gameId: gameId, capacity: seats, isPublic: true);
    return gameId;
  }

  Future<GameState> watchOnce(String gameId) async {
    return _gameService.watch(gameId).first;
  }

  String? gameIdForCode(String code) => _rooms[code]?.gameId;

  void _validateSeatCount(int seats) {
    if (seats < 2 || seats > 7) {
      throw ArgumentError('Kadi supports between 2 and 7 players.');
    }
  }

  _RoomInfo? _findPublicRoom(int seats) {
    for (final entry in _rooms.entries) {
      final info = entry.value;
      if (!info.isPublic || info.capacity != seats) continue;
      final state = _gameService.getState(info.gameId);
      if (state == null) continue;
      if (state.gameStatus == 'waiting' && state.players.length < info.capacity) {
        return info;
      }
    }
    return null;
  }

  String _generateUniqueCode() {
    String code;
    do {
      code = _makeCode();
    } while (_rooms.containsKey(code));
    return code;
  }

  String _makeCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return List.generate(6, (_) => letters[rnd.nextInt(letters.length)]).join();
  }
}

class _RoomInfo {
  const _RoomInfo({
    required this.gameId,
    required this.capacity,
    required this.isPublic,
  });

  final String gameId;
  final int capacity;
  final bool isPublic;
}
