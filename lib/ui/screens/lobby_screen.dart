import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/online_service.dart';
import 'game_board_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  final _nicknameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final OnlineService _onlineService = OnlineService();
  final ScrollController _pageScrollController = ScrollController();

  bool _isLoggedIn = false;
  bool _creatingRoom = false;
  bool _joiningRoom = false;
  int _selectedSeats = 4;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void dispose() {
    _glowController.dispose();
    _nicknameController.dispose();
    _roomCodeController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0B132B),
                    Color(0xFF1C2541),
                    Color(0xFF1B262C),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                final t = _glowAnimation.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -180 + 120 * t,
                      left: -150,
                      child: _buildGlowCircle(
                        const Color(0xFFFF7043).withOpacity(0.55),
                        360,
                      ),
                    ),
                    Positioned(
                      bottom: -220 + 140 * (1 - t),
                      right: -170,
                      child: _buildGlowCircle(
                        const Color(0xFF26C6DA).withOpacity(0.5),
                        420,
                      ),
                    ),
                    Positioned(
                      top: 140 + 80 * (0.5 - t),
                      right: -120,
                      child: _buildGlowCircle(
                        const Color(0xFF9575CD).withOpacity(0.42),
                        300,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: Scrollbar(
                  controller: _pageScrollController,
                  thumbVisibility: true,
                  radius: const Radius.circular(16),
                  child: SingleChildScrollView(
                    controller: _pageScrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 780;
                          final formContent = _buildFormContent(isWide);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.38 + 0.1 * _glowAnimation.value),
                                  blurRadius: 40,
                                  offset: const Offset(0, 24),
                                ),
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.18 + 0.05 * _glowAnimation.value),
                                  blurRadius: 80,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: isWide
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildLeftPromo()),
                                      const SizedBox(width: 36),
                                      Expanded(child: formContent),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildLeftPromo(),
                                      const SizedBox(height: 32),
                                      formContent,
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowCircle(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPromo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            final shift = _glowAnimation.value.clamp(0.2, 0.8);
            return ShaderMask(
              shaderCallback: (rect) {
                final gradient = LinearGradient(
                  colors: const [
                    Color(0xFFFFE082),
                    Color(0xFFFF8A65),
                    Color(0xFF7E57C2),
                  ],
                  stops: [0.0, shift, 1.0],
                );
                return gradient.createShader(rect);
              },
              child: const Text(
                'KADI LOUNGE',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Host cinematic matches, reserve shining seats, and share codes in seconds.',
          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/kadi_banner.png',
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _FeatureChip(icon: Icons.timer_rounded, label: '30-second turns'),
            _FeatureChip(icon: Icons.chair_alt, label: 'Seat spotlight'),
            _FeatureChip(icon: Icons.nightlife, label: 'Modern lounge vibe'),
          ],
        ),
      ],
    );
  }

  Widget _buildFormContent(bool isWide) {
    final nickname = _nicknameController.text.trim();
    final greeting = _isLoggedIn
        ? 'Ready when you are${nickname.isNotEmpty ? ', $nickname' : ''}!'
        : 'Pick a nickname to get started.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in once and keep the seats glowing for your crew.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _handleLogin,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: _isLoggedIn
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
              ),
              icon: Icon(_isLoggedIn ? Icons.verified : Icons.login, size: 18),
              label: Text(
                _isLoggedIn ? 'Signed in' : 'Login / Sign up',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        SizedBox(height: isWide ? 24 : 20),
        _buildCreateCard(),
        const SizedBox(height: 20),
        _buildJoinCard(),
      ],
    );
  }

  Widget _buildLobbySurface({required bool isWide, required Widget formContent}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.38 + 0.1 * _glowAnimation.value),
            blurRadius: 40,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLeftPromo()),
                const SizedBox(width: 36),
                Expanded(child: formContent),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLeftPromo(),
                const SizedBox(height: 32),
                formContent,
              ],
            ),
    );
  }

  Widget _buildCreateCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create a room',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose your nickname and highlight the number of seats to reserve.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nicknameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              label: 'Nickname',
              hint: 'Enter your nickname',
              icon: Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Seat selection',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _buildSeatSelector(),
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.chair_alt, color: Colors.white54, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose how many chairs to reserve before sharing your invite.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _creatingRoom ? null : _handleCreateRoom,
            style: _primaryButtonStyle(const Color(0xFFFF7043)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _creatingRoom
                  ? const SizedBox(
                      key: ValueKey('creating'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      key: const ValueKey('create-label'),
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.bolt, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Create room',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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

  Widget _buildJoinCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Join with a code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Drop in to an existing lounge using a six-character invite.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _roomCodeController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            style: const TextStyle(
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            decoration: _inputDecoration(
              label: 'Room code',
              hint: 'Enter invitation code',
              icon: Icons.vpn_key,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _joiningRoom ? null : _handleJoinRoom,
            style: _primaryButtonStyle(const Color(0xFF26C6DA)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _joiningRoom
                  ? const SizedBox(
                      key: ValueKey('joining'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      key: const ValueKey('join-label'),
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.vpn_key, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Join room',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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

  Widget _buildSeatSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(6, (index) {
        final value = index + 2;
        final selected = value == _selectedSeats;
        return ChoiceChip(
          label: Text('$value seats'),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _selectedSeats = value;
            });
          },
          selectedColor: const Color(0xFFFFD54F),
          labelStyle: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          backgroundColor: Colors.white.withOpacity(0.1),
          side: BorderSide(
            color: selected ? Colors.white : Colors.white24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
      }),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      color: Colors.white.withOpacity(0.08),
      border: Border.all(color: Colors.white.withOpacity(0.14)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.28),
          blurRadius: 18,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      elevation: 8,
      shadowColor: color.withOpacity(0.6),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFFB74D), width: 1.6),
      ),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
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

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
