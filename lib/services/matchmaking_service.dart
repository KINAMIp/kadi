import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kadi/models/kadi_card.dart';
import 'package:kadi/models/kadi_player.dart';
import 'package:kadi/models/game_state.dart';
import 'package:kadi/engine/rule_engine.dart';
import 'package:kadi/services/online_service.dart';

class MatchmakingService {
  final OnlineService online;
  MatchmakingService({OnlineService? onlineService})
      : online = onlineService ?? OnlineService();

  /// CREATE ROOM (Invite Mode)
  /// UI calls: createRoom(hostUid: ..., hostName: ..., [desiredPlayers])
  Future<String> createRoom({
    required String hostUid,
    required String hostName,
    int desiredPlayers = 2,
  }) async {
    final code = _generateCode();
    final room = {
      'hostUid': hostUid,
      'desiredPlayers': desiredPlayers.clamp(2, 7),
      'status': 'lobby', // lobby | starting | playing | finished
      'createdAt': FieldValue.serverTimestamp(),
      'code': code,
      'players': [
        {
          'uid': hostUid,
          'name': hostName,
          'joinedAt': FieldValue.serverTimestamp(),
        }
      ],
      'gameId': null,
    };
    final doc = await online.rooms.add(room);
    return doc.id;
  }

  /// JOIN ROOM by 6-char code
  /// UI calls: joinRoom(code, uid, name)
  Future<String> joinRoom(String code, String uid, String name) async {
    // Find room by code

    if (snap.docs.isEmpty) {
      throw StateError('Room code not found.');
    }
    final roomDoc = snap.docs.first;
    final data = roomDoc.data();
    if (data['status'] != 'lobby') {
      throw StateError('Room is not in lobby.');
    }

    final players = List<Map<String, dynamic>>.from(data['players'] as List);
    final desired = (data['desiredPlayers'] ?? 2) as int;

    if (players.any((p) => p['uid'] == uid)) {
      // already joined, return roomId
      return roomDoc.id;
    }
    if (players.length >= desired) {
      throw StateError('Room is full.');
    }

    players.add({
      'uid': uid,
      'name': name,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await roomDoc.reference.update({'players': players});

    // Auto start when full.
    if (players.length >= desired) {
      await _startGameFromRoom(roomDoc.id, players);
    }
    return roomDoc.id;
  }

  /// QUICK PLAY — auto queue by desiredPlayers.
  /// UI currently calls quickJoinOrCreate(uid, name) without desiredPlayers; default to 2.
  Future<String> quickJoinOrCreate(
    String uid,
    String name, {
    int desiredPlayers = 2,
  }) async {
    desiredPlayers = desiredPlayers.clamp(2, 7);

    // Try to find lobby with same desiredPlayers and not full
    final q = await online.rooms
        .where('status', isEqualTo: 'lobby')
        .where('desiredPlayers', isEqualTo: desiredPlayers)
        .orderBy('createdAt', descending: false)
        .limit(10)
        .get();

    for (final d in q.docs) {
      final data = d.data();
      final players = List<Map<String, dynamic>>.from(data['players'] as List);
      if (players.length < desiredPlayers &&
          players.every((p) => p['uid'] != uid)) {
        // join this one
        return await joinRoom(data['code'] as String, uid, name);
      }
    }

    // Otherwise create a new room and join it
    final roomId = await createRoom(
      hostUid: uid,
      hostName: name,
      desiredPlayers: desiredPlayers,
    );
    // Return room id; host is already added. Game will start when others join.
    return roomId;
  }

  /// INTERNAL: Starts game when lobby is full.
  Future<void> _startGameFromRoom(
    String roomId,
    List<Map<String, dynamic>> lobbyPlayers,
  ) async {
    // Build deck
    final deck = RuleEngine.buildDeck();
    final start = RuleEngine.chooseNeutralStart(deck);
    var draw = start.draw;
    final discard = start.discard;

    // Randomize order
    lobbyPlayers.shuffle();

    // Convert to KadiPlayer
    final players = lobbyPlayers

        .toList();

    // Deal
    final dealt = RuleEngine.dealToPlayers(players, draw, handSize: 4);
    final newPlayers = dealt.players;
    draw = dealt.draw;

    final startIndex = RuleEngine.randomStartIndex(newPlayers.length);

    // Build game state document
    final gameData = GameState(
      id: '',
      players: newPlayers,
      drawPile: draw,
      discardPile: discard,
      turnIndex: startIndex,
      gameStatus: 'playing',
      createdAt: DateTime.now(),
      requiredSuit: null,
    ).toJson();

    // Store in Firestore
    final gameDoc = await online.games.add({
      ...gameData,
      'createdAt': FieldValue.serverTimestamp(), // overwrite as server time
    });

    await online.roomRef(roomId).update({
      'status': 'playing',
      'gameId': gameDoc.id,
    });
  }

  String _generateCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => letters[r.nextInt(letters.length)]).join();
  }
}