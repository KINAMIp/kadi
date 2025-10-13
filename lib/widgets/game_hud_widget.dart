import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../utils/constants.dart';
import '../widgets/turn_timer_widget.dart';

class GameHUDWidget extends StatefulWidget {
  final String currentPlayer;
  final Duration turnSeconds;
  final VoidCallback onTimeout;
  final bool isYourTurn;

  const GameHUDWidget({
    super.key,
    required this.currentPlayer,
    required this.turnSeconds,
    required this.onTimeout,
    required this.isYourTurn,
  });

  @override
  State<GameHUDWidget> createState() => _GameHUDWidgetState();
}

class _GameHUDWidgetState extends State<GameHUDWidget> {
  final _voice = VoiceService();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isYourTurn
                  ? AppColors.highlight
                  : Colors.white24,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Player turn info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isYourTurn
                        ? "Your Turn"
                        : "Turn: ${widget.currentPlayer}",
                    style: TextStyle(
                      color: widget.isYourTurn
                          ? AppColors.highlight
                          : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TurnTimerWidget(
                    duration: widget.turnSeconds,
                    onTimeout: widget.onTimeout,
                    isRunning: widget.isYourTurn,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Voice bar
              VoiceBar(voice: _voice),
            ],
          ),
        ),
      ),
    );
  }
}

class VoiceBar extends StatefulWidget {
  final VoiceService voice;
  const VoiceBar({super.key, required this.voice});

  @override
  State<VoiceBar> createState() => _VoiceBarState();
}

class _VoiceBarState extends State<VoiceBar> {
  late final VoiceService _svc;
  bool _connected = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _svc = widget.voice;
    _svc.connected$.listen((v) => setState(() => _connected = v));
    _svc.muted$.listen((v) => setState(() => _muted = v));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            _connected ? Icons.mic : Icons.mic_off_outlined,
            color: _connected ? Colors.greenAccent : Colors.grey,
          ),
          tooltip: _connected ? "Connected to voice" : "Join voice chat",
          onPressed: _toggleConnection,
        ),
        IconButton(
          icon: Icon(
            _muted ? Icons.volume_off : Icons.volume_up,
            color: _muted ? Colors.redAccent : Colors.white70,
          ),
          tooltip: _muted ? "Unmute mic" : "Mute mic",
          onPressed: _connected ? _toggleMute : null,
        ),
      ],
    );
  }

  Future<void> _toggleConnection() async {
    if (_connected) {
      await _svc.leave();
    } else {
      await _svc.join("global-room");
    }
    setState(() {});
  }

  Future<void> _toggleMute() async {
    await _svc.toggleMute();
    setState(() {});
  }
}