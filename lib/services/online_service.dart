import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class OnlineService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser?.uid ?? '';

  OnlineService() {
    // Ensure user is signed in anonymously
    _initUser();
  }

  Future<void> _initUser() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  // Firestore collection reference
  CollectionReference<Map<String, dynamic>> get rooms =>
      _db.collection('rooms');

  /// ✅ Create a new game room
  Future<String> createRoom({required String nickname}) async {
    await _initUser();

    final roomCode = _generateRoomCode();
    final player = {
      'uid': uid,
      'name': nickname,
      'hand': [],
    };

    await rooms.doc(roomCode).set({
      'code': roomCode,
      'status': 'waiting',
      'turnIndex': 0,
      'players': [player],
      'pile': [],
      'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return roomCode;
  }

  /// ✅ Join an existing room
  Future<bool> joinRoom({required String code, required String nickname}) async {
    await _initUser();

    final ref = rooms.doc(code);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final data = snap.data()!;
    final players = List<Map<String, dynamic>>.from(data['players']);

    final alreadyJoined =
        players.any((p) => p['uid'] == uid || p['name'] == nickname);
    if (alreadyJoined) return true;

    if (players.length >= 4) return false; // limit to 4 players

    players.add({'uid': uid, 'name': nickname, 'hand': []});
    await ref.update({'players': players});
    return true;
  }

  /// ✅ Real-time updates of room state
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String code) {
    return rooms.doc(code).snapshots();
  }

  /// ✅ Play a card
  Future<void> playCard({
    required String code,
    required Map<String, dynamic> card,
  }) async {
    final ref = rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      final players = List<Map<String, dynamic>>.from(data['players']);
      final pile = List<Map<String, dynamic>>.from(data['pile']);
      final turnIndex = data['turnIndex'] ?? 0;

      final player = players[turnIndex];
      final hand = List<Map<String, dynamic>>.from(player['hand']);
      hand.removeWhere((c) => c['rank'] == card['rank'] && c['suit'] == card['suit']);
      players[turnIndex]['hand'] = hand;

      pile.add(card);

      int nextTurn = (turnIndex + 1) % players.length;
      String? winner;
      String status = data['status'];

      if (hand.isEmpty) {
        status = 'over';
        winner = player['name'];
      }

      tx.update(ref, {
        'players': players,
        'pile': pile,
        'turnIndex': nextTurn,
        'status': status,
        'winner': winner,
      });
    });
  }

  /// ✅ Draw a card (adds 1 new card to player's hand)
  Future<void> drawCard({required String code, int count = 1}) async {
    final ref = rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      final turnIndex = data['turnIndex'] ?? 0;
      final players = List<Map<String, dynamic>>.from(data['players']);
      final hand = List<Map<String, dynamic>>.from(players[turnIndex]['hand']);

      final newCards = _generateCards(count);
      hand.addAll(newCards);
      players[turnIndex]['hand'] = hand;

      tx.update(ref, {'players': players});
    });
  }

  /// ✅ Leave a room
  Future<void> leaveRoom(String code) async {
    final ref = rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      final players = List<Map<String, dynamic>>.from(data['players']);
      players.removeWhere((p) => p['uid'] == uid);

      if (players.isEmpty) {
        tx.delete(ref);
      } else {
        tx.update(ref, {'players': players});
      }
    });
  }

  // 🔹 Utility: generate a random 4-letter room code
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random();
    return String.fromCharCodes(
      Iterable.generate(4, (_) => chars.codeUnitAt(rand.nextInt(chars.length))),
    );
  }

  // 🔹 Utility: generate random playing cards
  List<Map<String, String>> _generateCards(int count) {
    const suits = ['♠', '♥', '♦', '♣'];
    const ranks = [
      'A',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      'J',
      'Q',
      'K'
    ];
    final rand = Random();
    return List.generate(count, (_) {
      final suit = suits[rand.nextInt(suits.length)];
      final rank = ranks[rand.nextInt(ranks.length)];
      return {'suit': suit, 'rank': rank};
    });
  }
}