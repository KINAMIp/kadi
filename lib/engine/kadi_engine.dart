import 'dart:math';
import '../models/kadi_card.dart';
import '../models/kadi_player.dart';
import 'rule_engine.dart';
import '../services/audio_service.dart';

class KadiGameEngine {
  final List<KadiPlayer> players;
  final List<KadiCard> deck = [];
  final List<KadiCard> discardPile = [];
  final AudioService _audio = AudioService();

  int currentPlayerIndex = 0;
  bool reverseOrder = false;
  bool gameOver = false;
  Suit? requiredSuit;
  int stackedPenalty = 0;

  KadiGameEngine(this.players);

  void initializeGame() {
    _createDeck();
    _shuffleDeck();
    _dealCards();
    final KadiCard first = deck.removeLast();
    discardPile.add(first);
    requiredSuit = first.suit;
    _audio.playShuffle();
  }

  void _createDeck() {
    for (final suit in Suit.values) {
      if (suit == Suit.none) continue;
      for (final rank in Rank.values) {
        if (rank == Rank.none) continue;
        deck.add(KadiCard(suit, rank));
      }
    }
  }

  void _shuffleDeck() => deck.shuffle(Random());

  void _dealCards() {
    for (final player in players) {
      for (int i = 0; i < 5; i++) {
        player.drawCard(deck.removeLast());
      }
    }
  }

  void playCard(KadiPlayer player, KadiCard card) {
    if (gameOver || player != currentPlayer) return;

    final top = discardPile.last;
    if (!RuleEngine.canPlay(card, top, requiredSuit)) return;

    player.playCard(card);
    discardPile.add(card);
    _audio.playCard();

    final newState = RuleEngine.applyCardEffect(
      card,
      RuleState(
        requiredSuit: requiredSuit,
        stackedPenalty: stackedPenalty,
        reverseOrder: reverseOrder,
      ),
    );

    requiredSuit = newState.requiredSuit;
    stackedPenalty = newState.stackedPenalty;
    reverseOrder = newState.reverseOrder;

    if (player.hasWon) {
      gameOver = true;
      _audio.playWin();
    } else {
      nextTurn();
    }
  }

  void nextTurn() {
    currentPlayerIndex = reverseOrder
        ? (currentPlayerIndex - 1 + players.length) % players.length
        : (currentPlayerIndex + 1) % players.length;
  }

  void drawCard(KadiPlayer player) {
    if (deck.isEmpty) _reshuffle();
    final card = deck.removeLast();
    player.drawCard(card);
    _audio.playDraw();
  }

  void _reshuffle() {
    final top = discardPile.removeLast();
    deck.addAll(discardPile);
    discardPile.clear();
    discardPile.add(top);
    deck.shuffle();
  }

  KadiPlayer get currentPlayer => players[currentPlayerIndex];
  KadiCard get topCard => discardPile.last;
}