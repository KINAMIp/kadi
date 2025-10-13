import 'dart:async';

/// VoiceService is a thin facade to manage in-game voice chat state.
/// This implementation is a no-op (no SDK), but provides a stable API.
/// Later, you can swap internals to use Agora / WebRTC without touching UI code.
class VoiceService {
  static final VoiceService _i = VoiceService._internal();
  factory VoiceService() => _i;
  VoiceService._internal();

  final _connectedC = StreamController<bool>.broadcast();
  final _mutedC = StreamController<bool>.broadcast();

  bool _connected = false;
  bool _muted = false;
  String? _roomId;

  /// Emits true while voice session is connected to a room.
  Stream<bool> get connected$ => _connectedC.stream;

  /// Emits true if the local mic is muted.
  Stream<bool> get muted$ => _mutedC.stream;

  bool get isConnected => _connected;
  bool get isMuted => _muted;
  String? get roomId => _roomId;

  /// Join a room's voice channel (no-op stub).
  Future<void> join(String roomId, {String? uid, String? token}) async {
    _roomId = roomId;
    _connected = true;
    _connectedC.add(_connected);
    // In a real impl: initialize engine, request mic permission, join channel.
    // e.g. AgoraRtcEngine.create, enableAudio, joinChannel(token, roomId, null, uid)
  }

  /// Leave current voice channel (no-op stub).
  Future<void> leave() async {
    _connected = false;
    _connectedC.add(_connected);
    _roomId = null;
    // Real impl: engine.leaveChannel(); engine.destroy();
  }

  /// Toggle local mute (no-op stub).
  Future<void> toggleMute() async {
    _muted = !_muted;
    _mutedC.add(_muted);
    // Real impl: engine.muteLocalAudioStream(_muted);
  }

  /// Ensure controllers are closed on app shutdown.
  void dispose() {
    _connectedC.close();
    _mutedC.close();
  }
}