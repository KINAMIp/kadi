import 'package:kadi/models/card_model.dart';

class Player {
  final String uid;
  final String name;
  final List<PlayingCard> hand;

  const Player({
    required this.uid,
    required this.name,
    required this.hand,
  });

  Player copyWith({
    String? uid,
    String? name,
    List<PlayingCard>? hand,
  }) {
    return Player(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      hand: hand ?? this.hand,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'hand': hand.map((c) => c.toJson()).toList(),
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        uid: json['uid'] ?? '',
        name: json['name'] ?? '',
        hand: (json['hand'] as List? ?? [])
            .map((e) =>
                PlayingCard.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}