import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/online_service.dart';
import 'game_board_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _nicknameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final OnlineService _onlineService = OnlineService();

  bool _isLoggedIn = false;
  bool _creatingRoom = false;
  bool _joiningRoom = false;
  int _selectedSeats = 4;

  @override
  void dispose() {
    _nicknameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background blurred image
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_cards.png',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _handleLogin,
                            child: Text(
                              _isLoggedIn ? "Signed in" : "Login / Sign up",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      Image.asset(
                        'assets/images/nk_logo.png',
                        width: 40,
                        height: 40,
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Banner
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/kadi_banner.png',
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Nickname input
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nicknameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: "Enter your nickname",
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedSeats,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: List.generate(
                            6,
                            (index) {
                              final value = index + 2;
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text('$value seats'),
                              );
                            },
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedSeats = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB71C1C),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              _creatingRoom ? null : () => _handleCreateRoom(),
                          child: Center(
                            child: _creatingRoom
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    "Create Room",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text("OR",
                            style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _roomCodeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: "Enter invitation code",
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB71C1C),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              _joiningRoom ? null : () => _handleJoinRoom(),
                          child: Center(
                            child: _joiningRoom
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    "Join Room",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogin() {
    FocusScope.of(context).unfocus();
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showSnack('Please enter your nickname first.');
      return;
    }

    if (_isLoggedIn) {
      _showSnack('You are already signed in as $nickname.');
      return;
    }

    setState(() {
      _isLoggedIn = true;
    });
    _showSnack('Signed in as $nickname');
  }

  Future<void> _handleCreateRoom() async {
    FocusScope.of(context).unfocus();
    if (!_ensureAuthenticated()) return;

    setState(() {
      _creatingRoom = true;
    });

    try {
      final nickname = _nicknameController.text.trim();
      final code = await _onlineService.createInviteRoom(
        nickname: nickname,
        seats: _selectedSeats,
      );

      if (!mounted) return;
      await _showRoomCreatedDialog(code);
      if (!mounted) return;
      _roomCodeController.text = code;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameBoardScreen(roomCode: code),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('Failed to create room: ${_humanizeError(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _creatingRoom = false;
        });
      }
    }
  }

  Future<void> _handleJoinRoom() async {
    FocusScope.of(context).unfocus();
    if (!_ensureAuthenticated()) return;

    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.length < 6) {
      _showSnack('Enter a valid invitation code.');
      return;
    }

    setState(() {
      _joiningRoom = true;
    });

    try {
      final nickname = _nicknameController.text.trim();
      final joinedGame = await _onlineService.joinRoom(
        code: code,
        nickname: nickname,
      );

      if (!mounted) return;
      if (joinedGame == null) {
        _showSnack('Room not found or already full.');
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameBoardScreen(roomCode: code),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('Failed to join room: ${_humanizeError(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _joiningRoom = false;
        });
      }
    }
  }

  bool _ensureAuthenticated() {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showSnack('Please enter your nickname first.');
      return false;
    }

    if (!_isLoggedIn) {
      setState(() {
        _isLoggedIn = true;
      });
      _showSnack('Signed in as $nickname');
    }
    return true;
  }

  Future<void> _showRoomCreatedDialog(String code) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Room created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this code with friends to invite them:'),
            const SizedBox(height: 12),
            Center(
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String _humanizeError(Object error) {
    final message = error.toString();
    final separatorIndex = message.indexOf(':');
    if (separatorIndex == -1) return message;
    return message.substring(separatorIndex + 1).trim();
  }
}
