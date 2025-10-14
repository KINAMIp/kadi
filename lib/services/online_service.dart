import 'package:cloud_firestore/cloud_firestore.dart';

/// Thin Firestore wrapper used by the other services.
class OnlineService {
  final FirebaseFirestore _db;

  // Collections
  CollectionReference<Map<String, dynamic>> get rooms =>
      _db.collection('rooms');

  CollectionReference<Map<String, dynamic>> get games =>
      _db.collection('games');

  // Helpers
  DocumentReference<Map<String, dynamic>> roomRef(String roomId) =>
      rooms.doc(roomId);

  DocumentReference<Map<String, dynamic>> gameRef(String gameId) =>
      games.doc(gameId);

  Future<void> runTransaction(
    Future<void> Function(Transaction tx) body,
  ) async {
    await _db.runTransaction((tx) async => body(tx));
  }
}