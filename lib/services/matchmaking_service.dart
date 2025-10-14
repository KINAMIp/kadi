import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_state.dart';
import 'game_service.dart';

class MatchmakingService {
  MatchmakingService._internal();
  static final MatchmakingService _instance = MatchmakingService._internal();
  factory MatchmakingService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameService _gameService = GameService();

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  Future<String> createRoom({
    required String hostUid,
    required String hostName,
    required int seats,
    bool isPublic = false,
  }) async {
    _validateSeatCount(seats);

    final gameId = _gameService.randomId();
    await _gameService.createGame(
      id: gameId,
      hostUid: hostUid,
      hostName: hostName,
      maxPlayers: seats,
      isPublic: isPublic,
    );

    final code = await _reserveCode();
    await _rooms.doc(code).set({
      'code': code,
      'gameId': gameId,
      'capacity': seats,
      'hostUid': hostUid,
      'hostName': hostName,
      'isPublic': isPublic,
      'status': 'waiting',
      'playerCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _updateRoomStatus(code, gameId);
    return code;
  }

  Future<String?> joinRoom({
    required String code,
    required String uid,
    required String name,
  }) async {
    final snapshot = await _rooms.doc(code).get();
    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data()!;
    final gameId = data['gameId'] as String?;
    if (gameId == null) {
      return null;
    }

    final capacity = (data['capacity'] ?? 2) as int;
    final state = await _gameService.getState(gameId);
    if (state == null) {
      return null;
    }

    if (!state.players.any((p) => p.uid == uid) &&
        state.players.length >= capacity) {
      return null;
    }

    await _gameService.addPlayer(gameId, uid: uid, name: name);
    await _updateRoomStatus(code, gameId);
    return gameId;
  }

  Future<String> quickPlay({
    required String uid,
    required String name,
    required int seats,
  }) async {
    _validateSeatCount(seats);

    final query = await _rooms
        .where('isPublic', isEqualTo: true)
        .where('capacity', isEqualTo: seats)
        .orderBy('createdAt', descending: false)
        .limit(10)
        .get();

    for (final doc in query.docs) {
      final data = doc.data();
      final gameId = data['gameId'] as String?;
      if (gameId == null) {
        continue;
      }
      final state = await _gameService.getState(gameId);
      if (state == null) {
        continue;
      }
      if (state.gameStatus == 'waiting' && state.players.length < seats) {
        await _gameService.addPlayer(gameId, uid: uid, name: name);
        await _updateRoomStatus(doc.id, gameId);
        return gameId;
      }
    }

    final gameId = _gameService.randomId();
    await _gameService.createGame(
      id: gameId,
      hostUid: uid,
      hostName: name,
      maxPlayers: seats,
      isPublic: true,
    );

    final code = await _reserveCode();
    await _rooms.doc(code).set({
      'code': code,
      'gameId': gameId,
      'capacity': seats,
      'hostUid': uid,
      'hostName': name,
      'isPublic': true,
      'status': 'waiting',
      'playerCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _updateRoomStatus(code, gameId);
    return gameId;
  }

  Future<GameState?> watchOnce(String gameId) => _gameService.watch(gameId).first;

  Future<String?> gameIdForCode(String code) async {
    final snapshot = await _rooms.doc(code).get();
    if (!snapshot.exists) {
      return null;
    }
    return snapshot.data()!['gameId'] as String?;
  }

  Future<void> refreshRoom(String code) async {
    final snapshot = await _rooms.doc(code).get();
    if (!snapshot.exists) return;
    final gameId = snapshot.data()!['gameId'] as String?;
    if (gameId == null) return;
    await _updateRoomStatus(code, gameId);
  }

  Future<void> _updateRoomStatus(String code, String gameId) async {
    final state = await _gameService.getState(gameId);
    if (state == null) return;
    await _rooms.doc(code).set({
      'status': state.gameStatus,
      'playerCount': state.players.length,
      'winnerUid': state.winnerUid,
    }, SetOptions(merge: true));
  }

  Future<String> _reserveCode() async {
    const attempts = 6;
    for (var i = 0; i < attempts; i++) {
      final code = _makeCode();
      final doc = await _rooms.doc(code).get();
      if (!doc.exists) {
        return code;
      }
    }
    throw StateError('Could not allocate a unique room code');
  }

  void _validateSeatCount(int seats) {
    if (seats < 2 || seats > 7) {
      throw ArgumentError('Kadi supports between 2 and 7 players.');
    }
  }

  String _makeCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return List.generate(6, (_) => letters[rnd.nextInt(letters.length)]).join();
  }
}
