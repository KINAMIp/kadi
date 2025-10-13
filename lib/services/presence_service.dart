import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  StreamSubscription? _presenceSub;

  Future<void> setOnline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _firestore.collection('players').doc(uid);
    await ref.set({
      'online': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _presenceSub = FirebaseFirestore.instance
        .collection('players')
        .doc(uid)
        .snapshots()
        .listen((_) {
      ref.update({'lastSeen': FieldValue.serverTimestamp()});
    });
  }

  Future<void> setOffline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('players').doc(uid).update({
      'online': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
    await _presenceSub?.cancel();
  }

  void startListening() {
    FirebaseAuth.instance.userChanges().listen((user) {
      if (user == null) {
        setOffline();
      } else {
        setOnline();
      }
    });
  }
}