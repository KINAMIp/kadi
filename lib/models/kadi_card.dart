import 'dart:math';

enum Suit { clubs, diamonds, hearts, spades, joker }

enum CardColor { red, black }

enum Rank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  joker,
}


extension RankLabel on Rank {
  String get label {
    switch (this) {
      case Rank.ace:   return 'A';
      case Rank.two:   return '2';
      case Rank.three: return '3';
      case Rank.four:  return '4';
      case Rank.five:  return '5';
      case Rank.six:   return '6';
      case Rank.seven: return '7';
      case Rank.eight: return '8';
      case Rank.nine:  return '9';
      case Rank.ten:   return '10';
      case Rank.jack:  return 'J';
      case Rank.queen: return 'Q';
      case Rank.king:  return 'K';
      case Rank.joker: return 'Jkr';
    }
  }
}

extension SuitLabel on Suit {
  String get label {
    switch (this) {
      case Suit.clubs:    return 'Clubs';
      case Suit.diamonds: return 'Diamonds';
      case Suit.hearts:   return 'Hearts';
      case Suit.spades:   return 'Spades';
      case Suit.joker:    return 'Joker';
    }
  }
}

class KadiCard {
  final String id;
  final Suit suit;
  final Rank rank;

  final CardColor? jokerColor;

  KadiCard({
    required this.id,
    required this.suit,
    required this.rank,
    this.jokerColor,
  });

  /// Simple helper used by UI
  bool get isSpecial =>
      isJoker || rank == Rank.two || rank == Rank.three || rank == Rank.ace || rank == Rank.jack;

  bool get isJoker => suit == Suit.joker || rank == Rank.joker;

  CardColor get color {
    if (isJoker) {
      return jokerColor ?? CardColor.values[id.hashCode & 1];
    }
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return CardColor.red;
      case Suit.spades:
      case Suit.clubs:
        return CardColor.black;
      case Suit.joker:
        return jokerColor ?? CardColor.red;
    }
  }

  bool get isAce => rank == Rank.ace;

  bool get isAceOfSpades => isAce && suit == Suit.spades;

  bool get isPenaltyCard => rank == Rank.two || rank == Rank.three || isJoker;

  int get penaltyValue {
    if (isJoker) return 5;
    if (rank == Rank.two) return 2;
    if (rank == Rank.three) return 3;
    return 0;
  }

  bool get isReverse => rank == Rank.king;

  bool get isSkip => rank == Rank.jack;

  bool get isQuestionCard => rank == Rank.eight || rank == Rank.queen;

  bool get isOrdinary =>
      suit != Suit.joker &&
      (rank == Rank.four ||
          rank == Rank.five ||
          rank == Rank.six ||
          rank == Rank.seven ||
          rank == Rank.nine ||
          rank == Rank.ten);

  /// Can this card be played on top of [top]?
  bool matches(KadiCard top, {Suit? requiredSuit}) {
    if (suit == Suit.joker || rank == Rank.joker) return true; // wild
    if (requiredSuit != null) return suit == requiredSuit;
    return suit == top.suit || rank == top.rank;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'suit': suit.name,
        'rank': rank.name,
        'jokerColor': jokerColor?.name,
      };

  factory KadiCard.fromJson(Map<String, dynamic> json) => KadiCard(
        id: json['id'] as String,
        suit: Suit.values.firstWhere((e) => e.name == json['suit']),
        rank: Rank.values.firstWhere((e) => e.name == json['rank']),
        jokerColor: json['jokerColor'] == null
            ? null
            : CardColor.values.firstWhere((e) => e.name == json['jokerColor']),
      );

  static List<KadiCard> fullDeck({bool includeJokers = true}) {
    final list = <KadiCard>[];
    final rnd = Random();
    for (final s in [Suit.clubs, Suit.diamonds, Suit.hearts, Suit.spades]) {
      for (final r in [
        Rank.ace, Rank.two, Rank.three, Rank.four, Rank.five, Rank.six,
        Rank.seven, Rank.eight, Rank.nine, Rank.ten, Rank.jack, Rank.queen, Rank.king
      ]) {
        list.add(KadiCard(
          id: 'c_${s.name}_${r.name}_${rnd.nextInt(1 << 32)}',
          suit: s,
          rank: r,
        ));
      }
    }
    if (includeJokers) {
      list.add(
        KadiCard(
          id: 'j1_${rnd.nextInt(1 << 32)}',
          suit: Suit.joker,
          rank: Rank.joker,
          jokerColor: CardColor.red,
        ),
      );
      list.add(
        KadiCard(
          id: 'j2_${rnd.nextInt(1 << 32)}',
          suit: Suit.joker,
          rank: Rank.joker,
          jokerColor: CardColor.black,
        ),
      );
    }
    list.shuffle();
    return list;
  }
}

/// Helper responsible for resolving card image asset paths.
class CardAssets {
  static const String _basePath = 'assets/cards';
  static const Map<Rank, String> _rankAssetNames = {
    Rank.ace: 'ace',
    Rank.two: '2',
    Rank.three: '3',
    Rank.four: '4',
    Rank.five: '5',
    Rank.six: '6',
    Rank.seven: '7',
    Rank.eight: '8',
    Rank.nine: '9',
    Rank.ten: '10',
    Rank.jack: 'jack',
    Rank.queen: 'queen',
    Rank.king: 'king',
  };

  static const List<String> _jokerVariants = ['red_joker', 'black_joker'];

  static const String back = '$_basePath/back.png';

  static String assetFor(KadiCard card) {
    if (card.isJoker) {
      return '$_basePath/${_jokerAssetFor(card)}.png';
    }

    final rankKey = _rankAssetNames[card.rank];
    if (rankKey == null) {
      throw StateError('No asset mapping found for rank ${card.rank}.');
    }

    return '$_basePath/${rankKey}_of_${card.suit.name}.png';
  }

  static String _jokerAssetFor(KadiCard card) {
    if (card.jokerColor == CardColor.black) {
      return _jokerVariants[1];
    }
    return _jokerVariants[0];
  }
}
extension CardColorLabel on CardColor {
  String get label => this == CardColor.red ? 'Red' : 'Black';
}
