import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _bubbleController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _pulse;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // ============================================================
    // MAIN LOGO ANIMATION
    // ============================================================

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.elasticOut,
      ),
    );

    _logoFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeIn,
      ),
    );

    // ============================================================
    // BACKGROUND BUBBLES
    // ============================================================

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    // ============================================================
    // PULSE ANIMATION
    // ============================================================

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _mainController.forward();

    // ============================================================
    // GO TO NEXT SCREEN
    // ============================================================

    _navigationTimer = Timer(
      const Duration(seconds: 4),
      _openNextScreen,
    );
  }

  // ============================================================
  // CHECK LOGGED-IN PLAYER
  // ============================================================

  Future<void> _openNextScreen() async {
    final prefs = await SharedPreferences.getInstance();

    final playerId = prefs.getString('playerId') ?? '';

    if (!mounted) return;

    if (playerId.isNotEmpty) {
      final playerName =
          prefs.getString('playerName') ?? 'Player';

      final playerEmail =
          prefs.getString('playerEmail') ?? '';

      final currentLevel =
          prefs.getInt('currentLevel') ?? 1;

      final currentScore =
          prefs.getInt('currentScore') ?? 0;

      final highestScore =
          prefs.getInt('highestScore') ?? 0;

      final totalStars =
          prefs.getInt('totalStars') ?? 0;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            playerId: playerId,
            playerName: playerName,
            playerEmail: playerEmail,
            currentLevel: currentLevel,
            currentScore: currentScore,
            highestScore: highestScore,
            totalStars: totalStars,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  void dispose() {
    _navigationTimer?.cancel();

    _mainController.dispose();
    _bubbleController.dispose();
    _pulseController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bubbleController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,

            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF08052A),
                  Color(0xFF17105C),
                  Color(0xFF34208A),
                  Color(0xFF642DB5),
                  Color(0xFFB238A5),
                ],
              ),
            ),

            child: Stack(
              children: [
                // ==================================================
                // GLOW EFFECTS
                // ==================================================

                Positioned(
                  top: -120,
                  left: -100,
                  child: _glowCircle(
                    size: 330,
                    color: const Color(0xFF2D8CFF),
                  ),
                ),

                Positioned(
                  bottom: -130,
                  right: -100,
                  child: _glowCircle(
                    size: 350,
                    color: const Color(0xFFFF3DAA),
                  ),
                ),

                // ==================================================
                // FLOATING BUBBLES
                // ==================================================

                ..._buildFloatingBubbles(),

                // ==================================================
                // MAIN CONTENT
                // ==================================================

                SafeArea(
                  child: Center(
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            // --------------------------------------
                            // BUBBLE LOGO
                            // --------------------------------------

                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulse.value,
                                  child: child,
                                );
                              },
                              child: _buildLogo(),
                            ),

                            const SizedBox(height: 32),

                            // --------------------------------------
                            // TITLE
                            // --------------------------------------

                            const Text(
                              'BUBBLE BLAST',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 4),

                            const Text(
                              'ADVENTURE',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE3D8FF),
                                letterSpacing: 7,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // --------------------------------------
                            // TAGLINE
                            // --------------------------------------

                            const Text(
                              'POP • MATCH • BLAST!',
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),

                            const SizedBox(height: 45),

                            // --------------------------------------
                            // LOADING
                            // --------------------------------------

                            SizedBox(
                              width: 180,
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(20),
                                child: const LinearProgressIndicator(
                                  minHeight: 7,
                                  backgroundColor:
                                      Color(0x553A2B73),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                    Color(0xFF66E8FF),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 15),

                            const Text(
                              'Loading adventure...',
                              style: TextStyle(
                                color: Color(0xFFD8D0F5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // VERSION
                // ==================================================

                Positioned(
                  bottom: 18,
                  left: 0,
                  right: 0,
                  child: Text(
                    'BUBBLE BLAST ADVENTURE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.45,
                      ),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _buildLogo() {
    return SizedBox(
      width: 155,
      height: 155,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF48DFFF).withValues(
                    alpha: 0.55,
                  ),
                  blurRadius: 35,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // Outer circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF48E5FF),
                  Color(0xFF267BFF),
                  Color(0xFF733CFF),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
                width: 3,
              ),
            ),
          ),

          // Inner glass
          Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),

          // Main bubble
          const Text(
            '🫧',
            style: TextStyle(
              fontSize: 78,
            ),
          ),

          // Small bubbles
          Positioned(
            top: 8,
            right: 12,
            child: _smallBubble(
              const Color(0xFFFF55A8),
              29,
            ),
          ),

          Positioned(
            bottom: 8,
            left: 8,
            child: _smallBubble(
              const Color(0xFFFFD447),
              24,
            ),
          ),

          Positioned(
            bottom: 28,
            right: 3,
            child: _smallBubble(
              const Color(0xFF6DFFB8),
              19,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SMALL BUBBLE
  // ============================================================

  Widget _smallBubble(
    Color color,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.3, -0.35),
        child: Container(
          width: size * 0.22,
          height: size * 0.22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GLOW
  // ============================================================

  Widget _glowCircle({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FLOATING BUBBLES
  // ============================================================

  List<Widget> _buildFloatingBubbles() {
    final t = _bubbleController.value * 2 * pi;

    return [
      _floatingBubble(
        left: 25,
        top: 100 + sin(t) * 18,
        size: 48,
        color: const Color(0xFF38CFFF),
        opacity: 0.75,
      ),

      _floatingBubble(
        right: 28,
        top: 80 + cos(t * 0.8) * 20,
        size: 35,
        color: const Color(0xFFFF4FA8),
        opacity: 0.8,
      ),

      _floatingBubble(
        left: 55,
        bottom: 150 + sin(t * 1.2) * 25,
        size: 28,
        color: const Color(0xFFFFD447),
        opacity: 0.8,
      ),

      _floatingBubble(
        right: 55,
        bottom: 120 + cos(t * 1.1) * 20,
        size: 55,
        color: const Color(0xFF7C5CFF),
        opacity: 0.65,
      ),

      _floatingBubble(
        left: 145,
        top: 190 + cos(t * 0.7) * 30,
        size: 20,
        color: const Color(0xFF6DFFB8),
        opacity: 0.8,
      ),

      _floatingBubble(
        right: 125,
        bottom: 220 + sin(t * 0.9) * 25,
        size: 23,
        color: const Color(0xFF55E6FF),
        opacity: 0.8,
      ),
    ];
  }

  Widget _floatingBubble({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: opacity * 0.7),
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.55),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: opacity * 0.65,
            ),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha: opacity * 0.45,
              ),
              blurRadius: 15,
            ),
          ],
        ),
        child: Align(
          alignment: const Alignment(-0.3, -0.35),
          child: Container(
            width: size * 0.22,
            height: size * 0.22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(
                alpha: opacity * 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}