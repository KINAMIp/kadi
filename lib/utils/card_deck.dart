import 'dart:math';
import '../models/card_model.dart';
import '../models/player_model.dart';
import '../models/game_state.dart';

List<PlayingCard> generateStandardDeck() {
  const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  final deck = <PlayingCard>[];

  for (final suit in [
    Suit.hearts,
    Suit.diamonds,
    Suit.clubs,
    Suit.spades,
  ]) {
    for (final rank in ranks) {
      deck.add(PlayingCard(suit, rank));
    }
  }

  // Add 2 Jokers
  deck.add(PlayingCard(Suit.joker, 'JOKER'));
  deck.add(PlayingCard(Suit.joker, 'JOKER'));
  return deck;
}

void shuffleDeck(List<PlayingCard> deck) {
  deck.shuffle(Random());
}

bool _isInvalidStartCard(PlayingCard card) {
  // Kadi rules: cannot start with 2,3,J,Q,K,8,A or Jokers
  if (card.isJoker) return true;
  const invalidRanks = {'2', '3', 'J', 'Q', 'K', '8', 'A'};
  return invalidRanks.contains(card.rank);
}

GameState dealCards(List<String> playerNames) {
  final deck = generateStandardDeck();
  shuffleDeck(deck);

  final numPlayers = playerNames.length;
  final cardsPerPlayer = numPlayers > 4 ? 3 : 4;

  final players = <Player>[];
  for (final name in playerNames) {
    final hand = deck.take(cardsPerPlayer).toList();
    deck.removeRange(0, cardsPerPlayer);
    players.add(Player(uid: name, name: name, hand: hand));
  }

  // Find valid starting card
  PlayingCard firstCard;
  do {
    firstCard = deck.removeAt(0);
    if (!_isInvalidStartCard(firstCard)) break;
    deck.add(firstCard);
  } while (true);

  return GameState(
    players: players,
    turnIndex: 0,
    deck: deck,
    discardPile: [firstCard],
    gameStatus: 'waiting',
  );
}