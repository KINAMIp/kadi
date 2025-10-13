import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playShuffle() async => _playLocal("sounds/shuffle.mp3");
  Future<void> playCard() async => _playLocal("sounds/play_card.mp3");
  Future<void> playWin() async => _playLocal("sounds/win.mp3");
  Future<void> playDraw() async => _playLocal("sounds/draw.mp3");

  Future<void> _playLocal(String fileName) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(fileName));
    } catch (e) {
      print("AudioService Error: $e");
    }
  }

  Future<void> dispose() async {
    await _player.stop();
    await _player.release();
  }
}