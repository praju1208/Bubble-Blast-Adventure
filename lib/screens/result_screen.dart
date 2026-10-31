import 'dart:math';

import 'package:flutter/material.dart';

import 'game_screen.dart';

class ResultScreen extends StatefulWidget {
  final String playerId;
  final String playerName;
  final int levelNumber;
  final int score;
  final bool won;
  final int movesLeft;
  final int stars;
  final int targetScore;

  const ResultScreen({
    super.key,
    required this.playerId,
    required this.playerName,
    required this.levelNumber,
    required this.score,
    required this.won,
    this.movesLeft = 0,
    this.stars = 0,
    this.targetScore = 0,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.15,
        1.0,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextLevel() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          levelNumber: widget.levelNumber + 1,
          playerId: widget.playerId,
          playerName: widget.playerName,
        ),
      ),
    );
  }

  void _tryAgain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          levelNumber: widget.levelNumber,
          playerId: widget.playerId,
          playerName: widget.playerName,
        ),
      ),
    );
  }

  void _continue() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _home() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final int target = widget.targetScore > 0
        ? widget.targetScore
        : 1000 * widget.levelNumber;

    final double scoreProgress = target <= 0
        ? 0
        : (widget.score / target).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF092C52),
              Color(0xFF146B83),
              Color(0xFF16B8A8),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const _BackgroundBubbles(),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildCard(
                        context,
                        target,
                        scoreProgress,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    int target,
    double scoreProgress,
  ) {
    final bool won = widget.won;

    return Container(
      constraints: const BoxConstraints(maxWidth: 470),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: const Color(0xFF101D4C).withValues(alpha: 0.92),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 35,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: won
                    ? const [Color(0xFFFFD84D), Color(0xFFFF8B39)]
                    : const [Color(0xFFFF5572), Color(0xFFFF2F58)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (won ? const Color(0xFFFFD84D) : const Color(0xFFFF5572))
                      .withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              won ? Icons.emoji_events_rounded : Icons.refresh_rounded,
              color: Colors.white,
              size: 45,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            won ? 'LEVEL COMPLETE!' : 'LEVEL FAILED',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            won
                ? 'Amazing shot, ${widget.playerName}!'
                : 'Almost there, ${widget.playerName}!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  Icons.layers_rounded,
                  'LEVEL',
                  '${widget.levelNumber}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  Icons.stars_rounded,
                  'STARS',
                  '${widget.stars}/3',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  Icons.speed_rounded,
                  'MOVES',
                  '${widget.movesLeft}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.07),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'YOUR SCORE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '$target TARGET',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${widget.score}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: scoreProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFD84D),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  won
                      ? 'Great! You cleared the board.'
                      : 'Try another strategy and clear more bubbles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (won) ...[
            _mainButton(
              icon: Icons.arrow_forward_rounded,
              text: 'NEXT LEVEL',
              onPressed: _nextLevel,
            ),
            const SizedBox(height: 11),
            _secondaryButton(
              icon: Icons.play_arrow_rounded,
              text: 'CONTINUE',
              onPressed: _continue,
            ),
          ] else ...[
            _mainButton(
              icon: Icons.replay_rounded,
              text: 'TRY AGAIN',
              onPressed: _tryAgain,
            ),
            const SizedBox(height: 11),
            _secondaryButton(
              icon: Icons.play_arrow_rounded,
              text: 'CONTINUE',
              onPressed: _continue,
            ),
          ],
          const SizedBox(height: 11),
          TextButton.icon(
            onPressed: _home,
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('HOME'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.065),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFFD84D), size: 21),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD84D),
              Color(0xFFFF8A3D),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB238).withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: const Color(0xFF27143D)),
          label: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF27143D),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.20),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
        ),
      ),
    );
  }
}

class _BackgroundBubbles extends StatelessWidget {
  const _BackgroundBubbles();

  @override
  Widget build(BuildContext context) {
    final Random random = Random(7);

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _BackgroundBubblePainter(random),
      ),
    );
  }
}

class _BackgroundBubblePainter extends CustomPainter {
  final Random random;

  _BackgroundBubblePainter(this.random);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 28; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      final double radius = 3 + random.nextDouble() * 15;
      final double alpha = 0.035 + random.nextDouble() * 0.09;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundBubblePainter oldDelegate) {
    return false;
  }
}
