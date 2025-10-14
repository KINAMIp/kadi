import 'dart:math';
import 'package:kadi/models/kadi_card.dart';
import 'package:kadi/models/kadi_player.dart';
import 'package:kadi/models/game_state.dart';

/// Core KADI rules & state transforms (pure functions).
class RuleEngine {
  /// Build a fresh, shuffled 54-card deck (52 + 2 jokers).
  static List<KadiCard> buildDeck() => KadiCard.fullDeck(includeJokers: true);

  /// Pick a **neutral** start card (4,5,6,9,10) from the deck and move it to discard.
  /// Returns updated drawPile & discardPile.
  static ({List<KadiCard> draw, List<KadiCard> discard}) chooseNeutralStart(
    List<KadiCard> shuffled,
  ) {
    final neutral = shuffled.indexWhere((c) =>
        c.suit != Suit.joker &&
        (c.rank == Rank.four ||
            c.rank == Rank.five ||
            c.rank == Rank.six ||
            c.rank == Rank.nine ||
            c.rank == Rank.ten));

    // Fallback: if not found (very unlikely), just use first non-joker.
    final startIdx = neutral >= 0
        ? neutral
        : shuffled.indexWhere((c) => c.suit != Suit.joker);

    final top = shuffled[startIdx];
    final draw = List<KadiCard>.from(shuffled)..removeAt(startIdx);
    final discard = <KadiCard>[top];
    return (draw: draw, discard: discard);
  }

  /// Deal `handSize` cards to each player, returns a NEW list of players and the new draw pile.
  static ({List<KadiPlayer> players, List<KadiCard> draw}) dealToPlayers(
    List<KadiPlayer> players,
    List<KadiCard> drawPile, {
    int handSize = 4,
  }) {
    final newPlayers = players.map((p) => p.copyWith(hand: [])).toList();
    final draw = List<KadiCard>.from(drawPile);
    for (int i = 0; i < handSize; i++) {
      for (int j = 0; j < newPlayers.length; j++) {
        if (draw.isEmpty) break;
        newPlayers[j].hand.add(draw.removeAt(0));
      }
    }
    return (players: newPlayers, draw: draw);
  }

  /// Random first player.
  static int randomStartIndex(int playerCount) =>
      playerCount == 0 ? 0 : Random().nextInt(playerCount);

  /// Validate if [card] is playable considering top & required suit (after Ace).
  static bool canPlay({
    required KadiCard card,
    required KadiCard top,
    Suit? requiredSuit,
  }) {
    if (card.suit == Suit.joker || card.rank == Rank.joker) return true;
    if (requiredSuit != null) {
      // When a suit has been selected via Ace, you must follow suit (or joker).
      return card.suit == requiredSuit;
    }
    return card.suit == top.suit || card.rank == top.rank;
  }

  /// Apply the effect of a played card and return a NEW GameState.
  /// Implements:
  /// - 2 => next picks +2 (stackable)
  /// - 3 => next picks +3 (stackable)
  /// - Joker => next picks +5 (stackable with 2/3)
  /// - A => cancels pick chain OR choose suit (here: we set requiredSuit; UI should ask desired suit before calling)
  /// - J => skip next player
  /// - K => reverse direction
  /// - 8/Q => valid only if no active pick chain (enforced by canPlayFromHand helper)
  static GameState applyPlay({
    required GameState state,
    required String byUid,
    required KadiCard card,
    Suit? chooseSuit, // pass when using Ace to choose suit
    int stackedPenalty = 0, // current stack to carry
    bool skipNext = false,
  }) {
    // Remove from player's hand + push to discard.
    final players = List<KadiPlayer>.from(state.players);
    final pIdx = players.indexWhere((p) => p.uid == byUid);
    if (pIdx < 0) return state;

    final hand = List<KadiCard>.from(players[pIdx].hand);
    hand.removeWhere((c) => c.id == card.id);
    players[pIdx] = players[pIdx].copyWith(hand: hand);

    final discard = List<KadiCard>.from(state.discardPile)..add(card);

    int dir = 1; // +1 clockwise, -1 reverse
    bool skip = skipNext;
    int penalty = stackedPenalty;
    Suit? requiredSuit = state.requiredSuit;

    // Resolve effects
    if (card.suit == Suit.joker || card.rank == Rank.joker) {
      penalty += 5;
      requiredSuit = null; // Joker does not set a suit itself.
    } else {
      switch (card.rank) {
        case Rank.two:
          penalty += 2;
          requiredSuit = null;
          break;
        case Rank.three:
          penalty += 3;
          requiredSuit = null;
          break;
        case Rank.ace:
          if (penalty > 0) {
            // Ace cancels current penalty chain.
            penalty = 0;
            requiredSuit = null;
          } else {
            // Choose suit (UI should pass chooseSuit)
            if (chooseSuit != null && chooseSuit != Suit.joker) {
              requiredSuit = chooseSuit;
            }
          }
          break;
        case Rank.jack:
          skip = true;
          requiredSuit = null;
          break;
        case Rank.king:
          dir = -1;
          requiredSuit = null;
          break;
        case Rank.eight:
        case Rank.queen:
          // No special effect here; rule validity (not after penalty) is enforced before play.
          requiredSuit = null;
          break;
        default:
          requiredSuit = null;
      }
    }

    // Advance turn index considering skip/reverse
    final n = players.length;
    int direction = dir == -1 ? -1 : 1; // applied to this move
    // Apply reverse by flipping the sign of direction of play; we control via turn math below
    int nextIndex = state.turnIndex;

    // If we reversed, we simulate it by subtracting instead of adding.
    nextIndex = (nextIndex + direction + n) % n; // normal step
    if (skip) {
      nextIndex = (nextIndex + direction + n) % n; // skip one more
    }

    return state.copyWith(
      players: players,
      discardPile: discard,
      turnIndex: nextIndex,
      requiredSuit: requiredSuit,
      gameStatus: hand.isEmpty ? "finished" : state.gameStatus,
    );
  }

  /// When draw pile is empty, reshuffle from discard (keeping top).
  static ({List<KadiCard> draw, List<KadiCard> discard}) reshuffleIfNeeded(
    List<KadiCard> drawPile,
    List<KadiCard> discardPile,
  ) {
    if (drawPile.isNotEmpty || discardPile.length <= 1) {
      return (draw: drawPile, discard: discardPile);
    }
    final top = discardPile.last;
    final rest = List<KadiCard>.from(discardPile)..removeLast();
    rest.shuffle();
    return (draw: rest, discard: [top]);
  }

  /// True if 8/Q “question” is allowed now (not after a penalty stacking).
  /// Pass in current stackedPenalty value your app tracks. For this simplified
  /// engine, call with 0 to allow, >0 to block.
  static bool questionAllowed(int stackedPenalty) => stackedPenalty == 0;

  /// Utility: scan a hand for any legal card given the current top & required suit.
  static bool hasAnyPlayable(
    List<KadiCard> hand,
    KadiCard top, {
    Suit? requiredSuit,
    bool questionAllowed = true,
  }) {
    for (final c in hand) {
      if (!questionAllowed &&
          (c.rank == Rank.eight || c.rank == Rank.queen)) {
        continue;
      }
      if (canPlay(card: c, top: top, requiredSuit: requiredSuit)) return true;
    }
    return false;
  }
}