import 'package:collection/collection.dart';

import '../models/kadi_card.dart';

class RuleValidationResult {
  final bool isValid;
  final String? reason;

  const RuleValidationResult.valid() : this._(true, null);
  const RuleValidationResult.invalid(String message) : this._(false, message);

  const RuleValidationResult._(this.isValid, this.reason);
}
 
class RuleState {
  final Suit? forcedSuit;
  final Rank? requestedRank;
  final Suit? requestedCardSuit;
  final Suit? questionSuit;
  final int pendingDraw;
  final bool clockwise;
  final int skipCount;
  final bool skipCancelable;
  final Set<String> nikoPending;
  final Set<String> nikoDeclared;
  final CardColor? activeJokerColor;
  final CardColor? requiredJokerColor;
  final DateTime? turnDeadline;
  final Map<String, int> idleStrikes;
  final String? comboOwnerId;
  final Rank? comboRank;

  const RuleState({
    this.forcedSuit,
    this.requestedRank,
    this.requestedCardSuit,
    this.questionSuit,
    this.pendingDraw = 0,
    this.clockwise = true,
    this.skipCount = 0,
    this.skipCancelable = false,
    Set<String>? nikoPending,
    Set<String>? nikoDeclared,
    this.activeJokerColor,
    this.requiredJokerColor,
    this.turnDeadline,
    Map<String, int>? idleStrikes,
    this.comboOwnerId,
    this.comboRank,
  })  : nikoPending = nikoPending ?? const <String>{},
        nikoDeclared = nikoDeclared ?? const <String>{},
        idleStrikes = idleStrikes ?? const <String, int>{};

  RuleState copyWith({
    Suit? forcedSuit,
    bool clearForcedSuit = false,
    Rank? requestedRank,
    bool clearRequestedRank = false,
    Suit? requestedCardSuit,
    bool clearRequestedCardSuit = false,
    Suit? questionSuit,
    bool clearQuestionSuit = false,
    int? pendingDraw,
    bool? clockwise,
    int? skipCount,
    bool? skipCancelable,
    Set<String>? nikoPending,
    Set<String>? nikoDeclared,
    CardColor? activeJokerColor,
    bool clearActiveJokerColor = false,
    CardColor? requiredJokerColor,
    bool clearRequiredJokerColor = false,
    DateTime? turnDeadline,
    bool clearTurnDeadline = false,
    Map<String, int>? idleStrikes,
    String? comboOwnerId,
    bool clearComboOwner = false,
    Rank? comboRank,
    bool clearComboRank = false,
  }) {
    return RuleState(
      forcedSuit: clearForcedSuit
          ? null
          : (forcedSuit ?? this.forcedSuit),
      requestedRank: clearRequestedRank
          ? null
          : (requestedRank ?? this.requestedRank),
      requestedCardSuit: clearRequestedCardSuit
          ? null
          : (requestedCardSuit ?? this.requestedCardSuit),
      questionSuit: clearQuestionSuit
          ? null
          : (questionSuit ?? this.questionSuit),
      pendingDraw: pendingDraw ?? this.pendingDraw,
      clockwise: clockwise ?? this.clockwise,
      skipCount: skipCount ?? this.skipCount,
      skipCancelable: skipCancelable ?? this.skipCancelable,
      nikoPending: nikoPending ?? this.nikoPending,
      nikoDeclared: nikoDeclared ?? this.nikoDeclared,
      activeJokerColor: clearActiveJokerColor
          ? null
          : (activeJokerColor ?? this.activeJokerColor),
      requiredJokerColor: clearRequiredJokerColor
          ? null
          : (requiredJokerColor ?? this.requiredJokerColor),
      turnDeadline:
          clearTurnDeadline ? null : (turnDeadline ?? this.turnDeadline),
      idleStrikes: idleStrikes ?? this.idleStrikes,
      comboOwnerId:
          clearComboOwner ? null : (comboOwnerId ?? this.comboOwnerId),
      comboRank: clearComboRank ? null : (comboRank ?? this.comboRank),
    );
  }

  RuleState toggleDirection() => copyWith(clockwise: !clockwise);

  Map<String, dynamic> toDebugJson() => {
        'forcedSuit': forcedSuit?.name,
        'requestedRank': requestedRank?.name,
        'requestedCardSuit': requestedCardSuit?.name,
        'questionSuit': questionSuit?.name,
        'pendingDraw': pendingDraw,
        'clockwise': clockwise,
        'skipCount': skipCount,
        'skipCancelable': skipCancelable,
        'nikoPending': nikoPending.toList(),
        'nikoDeclared': nikoDeclared.toList(),
        'activeJokerColor': activeJokerColor?.name,
        'requiredJokerColor': requiredJokerColor?.name,
        'turnDeadline': turnDeadline?.toIso8601String(),
        'idleStrikes': idleStrikes,
        'comboOwnerId': comboOwnerId,
        'comboRank': comboRank?.name,
      };
}

class RuleEngine {
  /// Validates whether [card] may be played given [state] and current [topCard].
  static RuleValidationResult canPlay({
    required RuleState state,
    required KadiCard card,
    required KadiCard topCard,
    required List<KadiCard> playerHand,
    bool isSkipTarget = false,
  }) {
    if (state.requiredJokerColor != null) {
      if (!card.isJoker || card.color != state.requiredJokerColor) {
        return RuleValidationResult.invalid(
          'You must play a ${state.requiredJokerColor!.label} Joker.',
        );
      }
      return const RuleValidationResult.valid();
    }

    // If a penalty is pending the only valid actions are stacking penalty or
    // canceling with an Ace.
    if (state.pendingDraw > 0) {
      if (card.isPenaltyCard) {
        return const RuleValidationResult.valid();
      }
      if (card.isAce) {
        return const RuleValidationResult.valid();
      }
      return const RuleValidationResult.invalid(
        'A penalty is active – you must stack a penalty card or cancel with an Ace.',
      );
    }

    // Question follow-up: must play matching suit and ordinary number.
    if (state.questionSuit != null) {
      if (card.suit != state.questionSuit) {
        return RuleValidationResult.invalid(
          'You must answer the question with a ${state.questionSuit!.name} card.',
        );
      }
      if (_isQuestionResponseForbidden(card)) {
        return const RuleValidationResult.invalid(
          'Question cards can only be answered with ordinary numbers (4-10 except specials).',
        );
      }
      return const RuleValidationResult.valid();
    }

    // Jack skip window: only another Jack can be played by the skip target
    // before the skip resolves.
    if (state.skipCount > 0 && state.skipCancelable && isSkipTarget) {
      if (card.rank != Rank.jack) {
        return const RuleValidationResult.invalid(
          'Only a Jack can counter a jump.',
        );
      }
      return const RuleValidationResult.valid();
    }

    // Suit forced by Ace change.
    if (state.forcedSuit != null && card.suit != state.forcedSuit && !card.isJoker) {
      return RuleValidationResult.invalid(
        'Suit forced to ${state.forcedSuit!.label}.',
      );
    }

    // Ace of spades request.
    if (state.requestedRank != null) {
      final requiredSuit = state.requestedCardSuit;
      final hasRequested = playerHand.any((c) {
        if (c.rank != state.requestedRank) return false;
        if (c.isJoker) return false;
        if (requiredSuit != null && c.suit != requiredSuit) return false;
        return true;
      });
      final matchesRank = card.rank == state.requestedRank;
      final matchesSuit = state.requestedCardSuit == null || card.suit == state.requestedCardSuit;
      if (hasRequested && (!matchesRank || !matchesSuit)) {
        final label = state.requestedCardSuit != null
            ? '${state.requestedRank!.label} of ${state.requestedCardSuit!.label}'
            : state.requestedRank!.label;
        return RuleValidationResult.invalid('You were asked for $label.');
      }
      if (matchesRank && matchesSuit) {
        return const RuleValidationResult.valid();
      }
      // If player does not hold requested rank fall back to normal matching.
    }

    if (card.isJoker) {
      if (topCard.isAceOfSpades && state.activeJokerColor == null) {
        return const RuleValidationResult.invalid(
          'You cannot play a Joker on top of the Ace of Spades immediately.',
        );
      }
      final CardColor targetColor;
      if (state.forcedSuit != null) {
        targetColor =
            (state.forcedSuit == Suit.hearts || state.forcedSuit == Suit.diamonds)
                ? CardColor.red
                : CardColor.black;
      } else {
        targetColor = topCard.color;
      }
      if (card.color != targetColor) {
        return RuleValidationResult.invalid(
          'You must match Joker color to the top card.',
        );
      }
      return const RuleValidationResult.valid();
    }

    if (card.rank == topCard.rank || card.suit == topCard.suit) {
      return const RuleValidationResult.valid();
    }

    // Allow Ace to be played at any time to change suit or cancel.
    if (card.isAce) {
      return const RuleValidationResult.valid();
    }

    return RuleValidationResult.invalid(
      'Card must match suit or rank.',
    );
  }

  /// Applies card effects and returns an updated [RuleState].
  static RuleState applyCardEffect({
    required RuleState state,
    required KadiCard card,
    Suit? chosenSuit,
    Rank? requestedRank,
    Suit? requestedCardSuit,
  }) {
    RuleState result = state;

    // Clear transient requirements when appropriate.
    if (state.forcedSuit != null && card.suit == state.forcedSuit) {
      result = result.copyWith(clearForcedSuit: true);
    }
    if (state.requestedRank != null && card.rank == state.requestedRank) {
      final matchesSuit = state.requestedCardSuit == null || card.suit == state.requestedCardSuit;
      if (matchesSuit) {
        result = result.copyWith(clearRequestedRank: true, clearRequestedCardSuit: true);
      }
    }
    if (state.questionSuit != null && card.suit == state.questionSuit) {
      result = result.copyWith(clearQuestionSuit: true);
    }

    if (card.isJoker) {
      result = result.copyWith(
        pendingDraw: state.pendingDraw + card.penaltyValue,
        skipCancelable: false,
        activeJokerColor: card.color,
        clearRequiredJokerColor: true,
      );
      return result;
    }

    if (card.rank == Rank.two || card.rank == Rank.three) {
      result = result.copyWith(
        pendingDraw: state.pendingDraw + card.penaltyValue,
        skipCancelable: false,
      );
      return result;
    }

    if (card.isAce) {
      if (state.pendingDraw > 0) {
        result = result.copyWith(
          pendingDraw: 0,
          clearForcedSuit: true,
          clearRequestedRank: true,
          clearRequestedCardSuit: true,
          skipCancelable: false,
          requiredJokerColor: state.activeJokerColor,
          clearActiveJokerColor: true,
        );
        return result;
      }
      if (card.isAceOfSpades && requestedRank != null) {
        result = result.copyWith(
          requestedRank: requestedRank,
          requestedCardSuit: requestedCardSuit,
          skipCancelable: false,
          clearForcedSuit: true,
        );
        return result;
      }
      if (chosenSuit != null) {
        result = result.copyWith(
          forcedSuit: chosenSuit,
          skipCancelable: false,
          clearRequestedCardSuit: true,
        );
      }
      return result;
    }

    if (card.rank == Rank.jack) {
      return result.copyWith(
        skipCount: state.skipCount + 1,
        skipCancelable: true,
        clearQuestionSuit: true,
      );
    }

    if (card.rank == Rank.king) {
      return result.toggleDirection().copyWith(skipCancelable: false);
    }

    if (card.isQuestionCard) {
      return result.copyWith(
        questionSuit: card.suit,
        skipCancelable: false,
      );
    }

    // Ordinary card clears skip cancel window.
    return result.copyWith(skipCancelable: false, clearActiveJokerColor: true);
  }

  static int nextPlayerIndex({
    required RuleState state,
    required int currentIndex,
    required int playerCount,
  }) {
    if (playerCount == 0) return 0;
    final direction = state.clockwise ? 1 : -1;
    var next = (currentIndex + direction) % playerCount;
    if (next < 0) {
      next += playerCount;
    }
    return next;
  }

  static bool needsNikoCall(List<KadiCard> hand) {
    if (hand.length != 1) return false;
    return hand.first.isOrdinary;
  }

  static bool _isQuestionResponseForbidden(KadiCard card) {
    if (card.isJoker) return true;
    const allowedRanks = {
      Rank.four,
      Rank.five,
      Rank.six,
      Rank.seven,
      Rank.nine,
      Rank.ten,
    };
    if (!allowedRanks.contains(card.rank)) {
      return true;
    }
    return false;
  }

  static RuleState clearAfterSkipResolution(RuleState state) {
    if (state.skipCount <= 0) {
      return state.copyWith(skipCancelable: false);
    }
    return state.copyWith(skipCount: state.skipCount - 1, skipCancelable: false);
  }

  static RuleState cancelRequestedRankIfImpossible({
    required RuleState state,
    required List<KadiCard> playerHand,
  }) {
    if (state.requestedRank == null) return state;
    final hasRank = playerHand.any((c) {
      if (c.rank != state.requestedRank) return false;
      if (c.isJoker) return false;
      if (state.requestedCardSuit != null && c.suit != state.requestedCardSuit) {
        return false;
      }
      return true;
    });
    if (!hasRank) {
      return state.copyWith(clearRequestedRank: true, clearRequestedCardSuit: true);
    }
    return state;
  }

  static RuleState resetQuestionIfInvalid({
    required RuleState state,
    required bool playedValidResponse,
  }) {
    if (!playedValidResponse && state.questionSuit != null) {
      return state.copyWith(clearQuestionSuit: true);
    }
    return state;
  }

  static RuleState removeNikoFlags(RuleState state, String playerId) {
    final pending = state.nikoPending.whereNot((id) => id == playerId).toSet();
    final declared = state.nikoDeclared.whereNot((id) => id == playerId).toSet();
    return state.copyWith(nikoPending: pending, nikoDeclared: declared);
  }

  static RuleState markNikoPending(RuleState state, String playerId) {
    final pending = state.nikoPending.toSet()..add(playerId);
    final declared = state.nikoDeclared.whereNot((id) => id == playerId).toSet();
    return state.copyWith(nikoPending: pending, nikoDeclared: declared);
  }

  static RuleState markNikoDeclared(RuleState state, String playerId) {
    final pending = state.nikoPending.whereNot((id) => id == playerId).toSet();
    final declared = state.nikoDeclared.toSet()..add(playerId);
    return state.copyWith(nikoPending: pending, nikoDeclared: declared);
  }
}