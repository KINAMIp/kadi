import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kadi/models/kadi_card.dart';
import 'package:kadi/models/kadi_player.dart';
import 'package:kadi/models/game_state.dart';
import 'package:kadi/engine/rule_engine.dart';
import 'package:kadi/services/online_service.dart';

class GameService {
  final OnlineService online;
  GameService({OnlineService? onlineService})
      : online = onlineService ?? OnlineService();

  /// Stream live GameState for UI.
  Stream<GameState> watchGame(String gameId) {
    return online.gameRef(gameId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) {
        throw StateError('Game not found');
      }
      // Coerce Firestore types into our model-friendly map
      final json = _gameJsonFromFirestore(snap.id, data);
      return GameState.fromJson(json);
    });
  }

  /// Draw one card for [uid] if it’s their turn & they can’t play.
  Future<void> drawCard(String gameId, String uid) async {
    final ref = online.gameRef(gameId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;

      final json = _gameJsonFromFirestore(snap.id, data);
      var state = GameState.fromJson(json);

      // Reshuffle if needed
      final reshuffled =
          RuleEngine.reshuffleIfNeeded(state.drawPile, state.discardPile);
      var draw = reshuffled.draw;
      var discard = reshuffled.discard;

      // Validate turn
      final current = state.players[state.turnIndex % state.players.length];
      if (current.uid != uid) return;

      // If any playable card exists, do not draw (UI should prevent).
      final canPlayAny = RuleEngine.hasAnyPlayable(
        current.hand,
        discard.last,
        requiredSuit: state.requiredSuit,
        questionAllowed: true,
      );
      if (canPlayAny) return;

      if (draw.isEmpty) return;
      final newCard = draw.removeAt(0);

      // Give card to current player
      final players = List<KadiPlayer>.from(state.players);
      final idx = players.indexWhere((p) => p.uid == uid);
      if (idx < 0) return;

      final hand = List<KadiCard>.from(players[idx].hand)..add(newCard);
      players[idx] = players[idx].copyWith(hand: hand);

      state = state.copyWith(drawPile: draw, discardPile: discard, players: players);

      tx.update(ref, _gameToFirestore(state));
    });
  }

  /// Play [card] for [uid] if legal. Supports Ace suit selection via [chooseSuit].
  Future<void> playCard(
    String gameId,
    String uid,
    KadiCard card, {
    Suit? chooseSuit,
  }) async {
    final ref = online.gameRef(gameId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;

      final json = _gameJsonFromFirestore(snap.id, data);
      var state = GameState.fromJson(json);

      // Check turn
      final current = state.players[state.turnIndex % state.players.length];
      if (current.uid != uid) return;

      // Validate play
      final top = state.discardPile.isNotEmpty
          ? state.discardPile.last
          : (state.drawPile.isNotEmpty ? state.drawPile.first : card);

      // Disallow 8/Q when (hypothetically) there is an active penalty chain.
      final questionAllowed = true; // Adjust if you track penalties externally.

      if (!RuleEngine.canPlay(card: card, top: top, requiredSuit: state.requiredSuit)) {
        return; // Illegal move
      }
      if (!questionAllowed &&
          (card.rank == Rank.eight || card.rank == Rank.queen)) {
        return;
      }

      // Apply effects & advance turn
      state = RuleEngine.applyPlay(
        state: state,
        byUid: uid,
        card: card,
        chooseSuit: chooseSuit,
      );

      tx.update(ref, _gameToFirestore(state));
    });
  }

  // ---------- Helpers to map Firestore <-> model ----------

  Map<String, dynamic> _gameToFirestore(GameState s) {
    // Convert DateTime to Timestamp and enums to strings (already done by toJson)
    final base = s.toJson();
    return {
      ...base,
      'createdAt': FieldValue.serverTimestamp(), // keep server authority
    };
  }

  Map<String, dynamic> _gameJsonFromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    // Convert Firestore types back to our model format
    final players = (data['players'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final draw = (data['drawPile'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final discard = (data['discardPile'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final createdAt = data['createdAt'];
    String? requiredSuit = data['requiredSuit'] as String?;

    return {
      'id': id,
      'players': players,
      'drawPile': draw,
      'discardPile': discard,
      'turnIndex': (data['turnIndex'] ?? 0) as int,
      'gameStatus': (data['gameStatus'] ?? 'playing') as String,
      'createdAt': createdAt is Timestamp
          ? createdAt.toDate().toIso8601String()
          : DateTime.now().toIso8601String(),
      'requiredSuit': requiredSuit,
    };
  }
}