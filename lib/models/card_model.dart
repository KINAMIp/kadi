enum Suit { hearts, diamonds, clubs, spades, joker }

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

extension SuitLabel on Suit {
  String get label => switch (this) {
        Suit.hearts => '♥',
        Suit.diamonds => '♦',
        Suit.clubs => '♣',
        Suit.spades => '♠',
        Suit.joker => '🃏',
      };
}

extension RankLabel on Rank {
  String get label => switch (this) {
        Rank.ace => 'A',
        Rank.jack => 'J',
        Rank.queen => 'Q',
        Rank.king => 'K',
        Rank.joker => 'Joker',
        _ => (index + 1).toString(),
      };
}

class PlayingCard {
  final Suit suit;
  final Rank rank;

  const PlayingCard(this.suit, this.rank);

  bool get isJoker => suit == Suit.joker || rank == Rank.joker;

  Map<String, dynamic> toJson() => {
        'suit': suit.name,
        'rank': rank.name,
      };

  factory PlayingCard.fromJson(Map<String, dynamic> json) => PlayingCard(
        Suit.values.firstWhere(
          (s) => s.name == json['suit'],
          orElse: () => Suit.hearts,
        ),
        Rank.values.firstWhere(
          (r) => r.name == json['rank'],
          orElse: () => Rank.ace,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);
}