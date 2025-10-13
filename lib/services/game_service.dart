import 'dart:async';
import 'dart:math';
import '../models/game_state.dart';
import '../models/kadi_card.dart';
import '../models/kadi_player.dart';

/// Simple in-memory game server for local debugging.
/// If you later plug Firestore, replace the maps/streams with snapshots.
class GameService {
  static final GameService _i = GameService._internal();
  factory GameService() => _i;
  GameService._internal();

  final _states = <String, GameState>{};
  final _controllers = <String, StreamController<GameState>>{};

  Stream<GameState> watch(String gameId) {
    _controllers.putIfAbsent(gameId, () => StreamController<GameState>.broadcast());
    final c = _controllers[gameId]!;
    final s = _states[gameId];
    if (s != null) {
      // emit current
      Future.microtask(() => c.add(s));
    }
    return c.stream;
  }

  void _emit(GameState s) {
    _states[s.id] = s;
    _controllers.putIfAbsent(s.id, () => StreamController<GameState>.broadcast());
    _controllers[s.id]!.add(s);
  }

  /// Create a brand-new game with host as first player
  GameState createGame({required String id, required String hostUid, required String hostName}) {
    final deck = KadiCard.fullDeck();
    final host = KadiPlayer(uid: hostUid, name: hostName, hand: []);
    // deal 7 to each joining player later; for host give 7 now
    for (var i = 0; i < 7; i++) {
      host.hand.add(deck.removeAt(0));
    }
    // flip starter
    final starter = deck.removeAt(0);

    final state = GameState(
      id: id,
      players: [host],
      drawPile: deck,
      discardPile: [starter],
      turnIndex: 0,
      gameStatus: 'waiting', // will turn to 'playing' when >=2 players
      createdAt: DateTime.now(),
    );
    _emit(state);
    return state;
  }

  /// Add a player to an existing game (if not present already)
  void addPlayer(String gameId, {required String uid, required String name}) {
    final s = _states[gameId];
    if (s == null) return;
    if (s.players.any((p) => p.uid == uid)) return;

    final deck = List<KadiCard>.from(s.drawPile);
    final newPlayer = KadiPlayer(uid: uid, name: name, hand: []);
    for (var i = 0; i < 7; i++) {
      newPlayer.hand.add(deck.removeAt(0));
    }

    final players = List<KadiPlayer>.from(s.players)..add(newPlayer);
    final status = players.length >= 2 ? 'playing' : s.gameStatus;

    _emit(s.copyWith(players: players, drawPile: deck, gameStatus: status));
  }

  /// Draw a card from the draw pile
  void drawCard(String gameId, String playerId) {
    final s = _states[gameId];
    if (s == null) return;
    if (s.drawPile.isEmpty) return;
    final idx = s.players.indexWhere((p) => p.uid == playerId);
    if (idx < 0) return;

    final deck = List<KadiCard>.from(s.drawPile);
    final card = deck.removeAt(0);

    final players = List<KadiPlayer>.from(s.players);
    final hand = List<KadiCard>.from(players[idx].hand)..add(card);
    players[idx] = players[idx].copyWith(hand: hand);

    _emit(s.copyWith(players: players, drawPile: deck));
  }

  /// Play a card to the discard pile & advance turn
  void playCard(String gameId, String playerId, KadiCard card) {
    final s = _states[gameId];
    if (s == null) return;

    final idx = s.players.indexWhere((p) => p.uid == playerId);
    if (idx < 0) return;
    final me = s.players[idx];

    // must own the card
    if (!me.hand.any((c) => c.id == card.id)) return;

    // must match rule
    final top = s.top;
    if (!card.matches(top, requiredSuit: s.requiredSuit)) return;

    // remove from hand, add to discard
    final players = List<KadiPlayer>.from(s.players);
    final myHand = List<KadiCard>.from(me.hand)..removeWhere((c) => c.id == card.id);
    players[idx] = me.copyWith(hand: myHand);

    final discard = List<KadiCard>.from(s.discardPile)..add(card);

    // next turn
    var nextIndex = (s.turnIndex + 1) % players.length;

    // ace: choose suit (for now, auto-pick suit of the card)
    Suit? requiredSuit;
    if (card.rank == Rank.ace) {
      requiredSuit = card.suit;
    }

    // win?
    var status = s.gameStatus;
    if (myHand.isEmpty) status = 'finished';

    _emit(s.copyWith(
      players: players,
      discardPile: discard,
      turnIndex: nextIndex,
      gameStatus: status,
      requiredSuit: requiredSuit,
    ));
  }

  /// Quick helper for tests
  String randomId() => 'g_${Random().nextInt(1 << 32)}';
}