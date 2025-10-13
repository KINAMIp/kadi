import '../models/kadi_card.dart';

class RuleState {
  final Suit? requiredSuit;
  final int stackedPenalty;
  final bool reverseOrder;

  RuleState({
    this.requiredSuit,
    this.stackedPenalty = 0,
    this.reverseOrder = false,
  });

  RuleState copyWith({
    Suit? requiredSuit,
    int? stackedPenalty,
    bool? reverseOrder,
  }) {
    return RuleState(
      requiredSuit: requiredSuit ?? this.requiredSuit,
      stackedPenalty: stackedPenalty ?? this.stackedPenalty,
      reverseOrder: reverseOrder ?? this.reverseOrder,
    );
  }
}

class RuleEngine {
  static bool canPlay(KadiCard card, KadiCard top, Suit? requiredSuit) {
    if (requiredSuit != null && card.suit == requiredSuit) return true;
    return card.rank == top.rank || card.suit == top.suit || card.isAce;
  }

  static RuleState applyCardEffect(KadiCard card, RuleState state) {
    if (card.isReverse) {
      return state.copyWith(reverseOrder: !state.reverseOrder);
    } else if (card.isSkip) {
      return state.copyWith();
    } else if (card.isPenalty) {
      return state.copyWith(stackedPenalty: state.stackedPenalty + 2);
    } else if (card.isAce) {
      // Normally you'd prompt for new suit
      return state.copyWith(requiredSuit: Suit.spades);
    }
    return state;
  }
}