import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_bubble.dart';
import '../models/game_particle.dart';
import '../models/score_popup.dart';
import 'result_screen.dart';
enum PowerMode {
  none,
  bomb,
  lightning,
  rainbow,
  rocket,
}
class _PowerTapArea {
  final double centerX;
  final PowerMode mode;
  final int count;
  const _PowerTapArea(this.centerX, this.mode, this.count);
}
class TrajectoryResult {
  final List<Offset> points;
  final GameBubble? collision;
  final Offset end;

  const TrajectoryResult({
    required this.points,
    required this.collision,
    required this.end,
  });
}
class GameScreen extends StatefulWidget {
  final int levelNumber;
  final String playerId;
  final String playerName;

  const GameScreen({
    super.key,
    required this.levelNumber,
    required this.playerId,
    required this.playerName,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}
class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {

  static const String baseUrl = 'http://localhost:5000';
  final Random _random = Random();
  bool _buildingLevel = false;
  final List<GameBubble> _bubbles = [];

  static const int _columns = 24;

  BubbleType _currentBubble = BubbleType.red;
  BubbleType _nextBubble = BubbleType.blue;

  double _aimX = 0.50;
  double _aimY = 0.25;

  bool _dragging = false;

  int _score = 0;

  int _movesLeft = 35;

  int _misses = 0;

  int _combo = 0;

  PowerMode _selectedPower = PowerMode.none;

  int _bombCount = 6;
  int _lightningCount = 8;
  int _rainbowCount = 9;
  int _rocketCount = 21;

  bool _paused = false;
  bool _gameFinished = false;
  bool _savingResult = false;
  bool _shooting = false;
  bool _completionCheckPending = false;
  String _message = '';

  double _messageLife = 0;
  late AnimationController _animationController;

  double _animationTime = 0;
  Timer? _gameTimer;

  bool _flyingBubbleVisible = false;

  double _flyingX = 0;

  double _flyingY = 0;

  BubbleType _flyingType = BubbleType.red;
  final List<GameParticle> _particles = [];

  final List<ScorePopup> _scorePopups = [];
  double _shake = 0;
  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(() {
        if (!mounted) return;

        setState(() {
          _animationTime = _animationController.value * pi * 2;
        });
      });

    _animationController.repeat();

    _createLevel();

    _gameTimer = Timer.periodic(
      const Duration(milliseconds: 32),
      (_) {
        _updateGameAnimation();
      },
    );
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _gameTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ==============================================================
  // CREATE LEVEL
  // ==============================================================

  void _createLevel() {
    _buildingLevel = true;
    _bubbles.clear();
    _particles.clear();
    _scorePopups.clear();

    // Level difficulty: every level adds one full row until 10 rows.
    // This keeps the board full-width and makes higher levels visibly harder.
    final int rows = min(2 + widget.levelNumber, 10);

    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < _columns; column++) {
        BubbleType type = _randomNormalBubble();

        // --------------------------------------------------------
        // Stone obstacles.
        // --------------------------------------------------------

        if (widget.levelNumber >= 2 &&
            _random.nextInt(100) < 8) {
          type = BubbleType.stone;
        }

        // --------------------------------------------------------
        // Bombs.
        // --------------------------------------------------------

        if (widget.levelNumber >= 3 &&
            _random.nextInt(100) < 3) {
          type = BubbleType.bomb;
        }

        // --------------------------------------------------------
        // Rainbow bubbles.
        // --------------------------------------------------------

        if (widget.levelNumber >= 4 &&
            _random.nextInt(100) < 2) {
          type = BubbleType.rainbow;
        }

        _bubbles.add(
          GameBubble(
            row: row,
            column: column,
            type: type,
            x: 0,
            y: 0,
            rotation: (_random.nextDouble() - 0.5) * 0.15,
          ),
        );
      }
    }

    _buildingLevel = false;

    _currentBubble = _randomShooterBubble();
    _nextBubble = _randomShooterBubble();

    _movesLeft = max(
      24,
      38 - ((widget.levelNumber - 1) ~/ 2),
    );

    _score = 0;
    _misses = 0;
    _combo = 0;

    _selectedPower = PowerMode.none;

    _message = '';
    _messageLife = 0;

    _paused = false;
    _gameFinished = false;
    _savingResult = false;
    _shooting = false;
    _completionCheckPending = false;

    _flyingBubbleVisible = false;

    _bombCount = 6;
    _lightningCount = 8;
    _rainbowCount = 9;
    _rocketCount = 21;
  }

  // ==============================================================
  // NORMAL COLORS
  // ==============================================================

  BubbleType _randomNormalBubble() {
    const List<BubbleType> allTypes = [
      BubbleType.red,
      BubbleType.blue,
      BubbleType.green,
      BubbleType.yellow,
      BubbleType.purple,
      BubbleType.orange,
    ];

    // During level creation the complete level color pool is used.
    // This prevents the first few bubbles from accidentally deciding
    // the whole level's color set.
    if (_buildingLevel || _bubbles.isEmpty) {
      if (widget.levelNumber <= 2) {
        return allTypes[_random.nextInt(4)];
      }
      return allTypes[_random.nextInt(allTypes.length)];
    }

    // --------------------------------------------------------------
    // END-GAME COLOR LOCK
    // --------------------------------------------------------------
    // When only a small number of normal colored bubbles remain,
    // shooter bubbles and newly-added penalty rows must use ONLY the
    // colors that are still present on the board.
    //
    // This prevents the game from giving unrelated colors near the
    // end, which otherwise makes the last bubbles unnecessarily
    // difficult to clear.
    final List<BubbleType> remainingColors = <BubbleType>[];

    final Set<BubbleType> present = <BubbleType>{};

    for (final GameBubble bubble in _bubbles) {
      if (bubble.falling ||
          bubble.removing ||
          bubble.type == BubbleType.bomb ||
          bubble.type == BubbleType.rainbow ||
          bubble.type == BubbleType.stone) {
        continue;
      }

      present.add(bubble.type);
    }

    // Once the level has been created, always use only colors that are
    // currently present on the board. This becomes especially important
    // near the end of the game, and it also keeps penalty rows from
    // re-introducing colors that have already been completely cleared.
    if (present.isNotEmpty) {
      remainingColors.addAll(present);
      return remainingColors[_random.nextInt(remainingColors.length)];
    }

    // Normal gameplay: use the normal level color pool.
    if (widget.levelNumber <= 2) {
      return allTypes[_random.nextInt(4)];
    }

    return allTypes[_random.nextInt(allTypes.length)];
  }

  // ==============================================================
  // SHOOTER BUBBLE
  // ==============================================================

  bool _isEndgameColorLockActive() {
    if (_buildingLevel || _bubbles.isEmpty) {
      return false;
    }

    int remainingNormalCount = 0;

    for (final GameBubble bubble in _bubbles) {
      if (bubble.falling ||
          bubble.removing ||
          bubble.type == BubbleType.bomb ||
          bubble.type == BubbleType.rainbow ||
          bubble.type == BubbleType.stone) {
        continue;
      }
      remainingNormalCount++;
    }

    return remainingNormalCount <= 30;
  }

  // ==============================================================
  // REMAINING BOARD COLORS
  // ==============================================================

  List<BubbleType> _remainingBoardColors() {
    final Set<BubbleType> colors = <BubbleType>{};
    for (final GameBubble bubble in _bubbles) {
      if (bubble.falling || bubble.removing) continue;
      if (bubble.type == BubbleType.bomb || bubble.type == BubbleType.rainbow || bubble.type == BubbleType.stone) continue;
      colors.add(bubble.type);
    }
    return colors.toList();
  }

  bool _isValidShooterColor(BubbleType type) {
    if (type == BubbleType.bomb || type == BubbleType.rainbow || type == BubbleType.stone) return false;
    return _remainingBoardColors().contains(type);
  }

  void _refreshShooterColors() {
    if (_buildingLevel) return;
    final colors = _remainingBoardColors();
    if (colors.isEmpty) return;
    if (!_isValidShooterColor(_currentBubble)) _currentBubble = colors[_random.nextInt(colors.length)];
    if (!_isValidShooterColor(_nextBubble)) _nextBubble = colors[_random.nextInt(colors.length)];
  }

  BubbleType _randomShooterBubble() {
    // Near the end, never introduce a random bomb/rainbow through the
    // normal shooter queue. Only colors that still exist on the board
    // should be offered.
    if (!_buildingLevel && _isEndgameColorLockActive()) {
      return _randomNormalBubble();
    }

    if (widget.levelNumber >= 3) {
      final int chance = _random.nextInt(40);

      if (chance == 0) {
        return BubbleType.bomb;
      }

      if (chance == 1) {
        return BubbleType.rainbow;
      }
    }

    return _randomNormalBubble();
  }

  // ==============================================================
  // BOARD RADIUS
  // ==============================================================

  double _radiusForWidth(double width) {
    // 24 smaller columns use almost the complete available width.
    // The formula keeps bubbles responsive on both desktop and mobile.
    return min(
      23.0,
      max(
        7.5,
        (width - 16) / (_columns * 2 + 1),
      ),
    );
  }

  // ==============================================================
  // BOARD TOP
  // ==============================================================

  double _boardTop() {
    return 132;
  }

  // ==============================================================
  // CELL POSITION
  // ==============================================================

  Offset _cellPosition(
    int row,
    int column,
    double width,
  ) {
    final double radius = _radiusForWidth(width);

    final double horizontalSpacing = radius * 2;
    final double verticalSpacing = radius * 1.72;

    // Full-width board with a small safe margin.
    final double boardWidth =
        _columns * horizontalSpacing + radius;
    final double boardLeft =
        max(10.0, (width - boardWidth) / 2);

    final double shift = row.isOdd ? radius : 0;

    final double x =
        boardLeft +
        radius +
        column * horizontalSpacing +
        shift;

    final double y =
        _boardTop() +
        radius +
        row * verticalSpacing;

    return Offset(x, y);
  }

  // ==============================================================
  // UPDATE BUBBLE POSITIONS
  // ==============================================================

  void _updateBubblePositions(Size size) {
    for (final GameBubble bubble in _bubbles) {
      if (bubble.falling) continue;

      final Offset position = _cellPosition(
        bubble.row,
        bubble.column,
        size.width,
      );

      bubble.x = position.dx;
      bubble.y = position.dy;
    }
  }

  // ==============================================================
  // GAME ANIMATION
  // ==============================================================

  void _updateGameAnimation() {
    if (!mounted) return;

    if (_messageLife > 0) {
      _messageLife -= 0.032;

      if (_messageLife <= 0) {
        _message = '';
      }
    }

    if (_shake > 0) {
      _shake *= 0.82;

      if (_shake < 0.15) {
        _shake = 0;
      }
    }

    // ------------------------------------------------------------
    // Particles
    // ------------------------------------------------------------

    for (final GameParticle particle in _particles) {
      particle.x += particle.vx;
      particle.y += particle.vy;

      particle.vy += 0.08;

      particle.life -= 0.035;
    }

    _particles.removeWhere(
      (particle) => particle.life <= 0,
    );

    // ------------------------------------------------------------
    // Score popups
    // ------------------------------------------------------------

    for (final ScorePopup popup in _scorePopups) {
      popup.y -= 0.7;
      popup.life -= 0.025;
    }

    _scorePopups.removeWhere(
      (popup) => popup.life <= 0,
    );

    // ------------------------------------------------------------
    // Falling bubbles
    // ------------------------------------------------------------

    if (!_paused && !_gameFinished) {
      for (final GameBubble bubble in _bubbles) {
        if (!bubble.falling) continue;

        bubble.y += bubble.velocityY;

        bubble.velocityY += 0.38;

        bubble.rotation += 0.075;

        bubble.opacity -= 0.012;
      }

      _bubbles.removeWhere(
        (bubble) =>
            bubble.falling &&
            bubble.opacity <= 0,
      );
    }

    setState(() {});
  }

  // ==============================================================
  // AIM
  // ==============================================================

  void _aim(
    Offset position,
    Size size,
  ) {
    if (_paused ||
        _gameFinished ||
        _shooting) {
      return;
    }

    setState(() {
      _aimX = (position.dx / size.width)
          .clamp(0.04, 0.96)
          .toDouble();

      _aimY = (position.dy / size.height)
          .clamp(0.10, 0.72)
          .toDouble();
    });
  }

  // ==============================================================
  // TAP
  // ==============================================================

  void _handleTap(
    Offset position,
    Size size,
  ) {
    // ------------------------------------------------------------
    // PAUSE OVERLAY CONTINUE BUTTON
    // ------------------------------------------------------------
    if (_paused) {
      final Rect continueButton = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2 + 55),
        width: 210,
        height: 48,
      );

      // Continue can be tapped directly on the pause panel.
      if (continueButton.contains(position)) {
        _togglePause();
        return;
      }

      // Restart is also available while the pause panel is open.
      if (position.dx > size.width - 96 &&
          position.dx < size.width - 48 &&
          position.dy < 75) {
        _restartGame();
        return;
      }

      // The top-right pause/play icon also resumes the game.
      if (position.dx > size.width - 48 &&
          position.dy < 75) {
        _togglePause();
      }
      return;
    }

    // ------------------------------------------------------------
    // HOME
    // ------------------------------------------------------------

    if (position.dx < 70 &&
        position.dy < 75) {
      _backHome();
      return;
    }

    // ------------------------------------------------------------
    // RESTART
    // ------------------------------------------------------------

    if (position.dx > size.width - 96 &&
        position.dx < size.width - 48 &&
        position.dy < 75) {
      _restartGame();
      return;
    }

    // ------------------------------------------------------------
    // PAUSE
    // ------------------------------------------------------------

    if (position.dx > size.width - 48 &&
        position.dy < 75) {
      _togglePause();
      return;
    }

    if (_paused ||
        _gameFinished ||
        _shooting) {
      return;
    }

    // ------------------------------------------------------------
    // SELECT / SWAP NEXT BUBBLE
    // ------------------------------------------------------------
    // The small bubble shown beside the cannon is interactive.
    // Tapping it makes it the current shooting bubble and moves
    // the old current bubble into the NEXT position.
    final double shooterX = size.width / 2;
    final double shooterY = size.height - 137;
    final Offset nextBubbleCenter =
        Offset(shooterX + 62, shooterY + 20);

    final double nextDx =
        position.dx - nextBubbleCenter.dx;
    final double nextDy =
        position.dy - nextBubbleCenter.dy;

    if (nextDx * nextDx + nextDy * nextDy <= 34 * 34) {
      _swapShooterBubbles();
      return;
    }

    // ------------------------------------------------------------
    // POWER UPS
    // ------------------------------------------------------------

    if (position.dy > size.height - 92) {
      if (_handlePowerTap(position, size)) {
        return;
      }
    }

    // ------------------------------------------------------------
    // SHOOT
    // ------------------------------------------------------------

    _aim(position, size);

    _shoot(size);
  }

  // ==============================================================
  // SWAP CURRENT / NEXT BUBBLE
  // ==============================================================

  void _swapShooterBubbles() {
    if (_paused ||
        _gameFinished ||
        _shooting) {
      return;
    }

    setState(() {
      final BubbleType oldCurrent = _currentBubble;
      _currentBubble = _nextBubble;
      _nextBubble = oldCurrent;
    });
  }

  // ==============================================================
  // POWER TAP
  // ==============================================================

  bool _handlePowerTap(
    Offset position,
    Size size,
  ) {
    // Exact button hit areas. The old wide-screen ranges missed the
    // rocket button, causing its tap to fall through and fire a normal shot.
    final double center = size.width / 2;
    final List<_PowerTapArea> powers = [
      _PowerTapArea(center - 120, PowerMode.bomb, _bombCount),
      _PowerTapArea(center - 40, PowerMode.lightning, _lightningCount),
      _PowerTapArea(center + 40, PowerMode.rainbow, _rainbowCount),
      _PowerTapArea(center + 120, PowerMode.rocket, _rocketCount),
    ];

    for (final area in powers) {
      final dx = position.dx - area.centerX;
      final dy = position.dy - (size.height - 47);
      if (dx * dx + dy * dy <= 34 * 34) {
        if (area.count > 0) {
          setState(() {
            _selectedPower = _selectedPower == area.mode ? PowerMode.none : area.mode;
            _message = _selectedPower == PowerMode.none ? '' : '${_powerName(_selectedPower)} SELECTED';
            _messageLife = _selectedPower == PowerMode.none ? 0 : 1.2;
          });
        }
        return true;
      }
    }
    return false;
  }

  String _powerName(PowerMode power) {
    switch (power) {
      case PowerMode.bomb: return 'BOMB';
      case PowerMode.lightning: return 'LIGHTNING';
      case PowerMode.rainbow: return 'RAINBOW';
      case PowerMode.rocket: return 'ROCKET';
      case PowerMode.none: return '';
    }
  }

  // ==============================================================
  // NEIGHBORS
  // ==============================================================

  List<List<int>> _neighbors(
    int row,
    int column,
  ) {
    if (row.isEven) {
      return [
        [row, column - 1],
        [row, column + 1],
        [row - 1, column - 1],
        [row - 1, column],
        [row + 1, column - 1],
        [row + 1, column],
      ];
    }

    return [
      [row, column - 1],
      [row, column + 1],
      [row - 1, column],
      [row - 1, column + 1],
      [row + 1, column],
      [row + 1, column + 1],
    ];
  }

  // ==============================================================
  // FIND BUBBLE
  // ==============================================================

  GameBubble? _bubbleAt(
    int row,
    int column,
  ) {
    for (final GameBubble bubble in _bubbles) {
      if (bubble.falling ||
          bubble.removing) {
        continue;
      }

      if (bubble.row == row &&
          bubble.column == column) {
        return bubble;
      }
    }

    return null;
  }

  // ==============================================================
  // CELL VALID
  // ==============================================================

  bool _validCell(
    int row,
    int column,
  ) {
    if (row < 0 ||
        column < 0 ||
        column >= _columns) {
      return false;
    }

    return true;
  }

  // ==============================================================
  // FIND EMPTY CELL
  // ==============================================================

  List<int>? _findBestSnapCell(
    Offset point,
    GameBubble? collision,
    double boardWidth,
  ) {
    final List<List<int>> candidates = [];

    // If the shot hit a bubble, first consider only its six
    // neighboring hex cells. This is what makes a reflected shot
    // attach to the correct side of the bubble it actually hit.
    if (collision != null) {
      for (final List<int> cell in _neighbors(
        collision.row,
        collision.column,
      )) {
        if (!_validCell(cell[0], cell[1])) {
          continue;
        }

        if (_bubbleAt(cell[0], cell[1]) == null) {
          candidates.add(cell);
        }
      }
    }

    // Ceiling shot: choose the closest empty top-row cell.
    if (candidates.isEmpty && collision == null) {
      for (int column = 0; column < _columns; column++) {
        if (_bubbleAt(0, column) == null) {
          candidates.add([0, column]);
        }
      }
    }

    // Very dense boards can temporarily have every immediate
    // neighbor occupied. Find the closest empty cell on the board
    // instead of dropping the flying bubble below the board.
    if (candidates.isEmpty) {
      double bestFallbackDistance = double.infinity;
      List<int>? fallback;

      for (int row = 0; row < 20; row++) {
        for (int column = 0; column < _columns; column++) {
          if (_bubbleAt(row, column) != null) {
            continue;
          }

          final Offset candidatePosition =
              _cellPosition(row, column, boardWidth);

          final double dx =
              candidatePosition.dx - point.dx;
          final double dy =
              candidatePosition.dy - point.dy;
          final double distance =
              dx * dx + dy * dy;

          if (distance < bestFallbackDistance) {
            bestFallbackDistance = distance;
            fallback = [row, column];
          }
        }
      }

      return fallback;
    }

    List<int> best = candidates.first;
    double bestDistance = double.infinity;

    for (final List<int> cell in candidates) {
      final Offset candidatePosition =
          _cellPosition(
        cell[0],
        cell[1],
        boardWidth,
      );

      final double dx =
          candidatePosition.dx - point.dx;
      final double dy =
          candidatePosition.dy - point.dy;
      final double distance =
          dx * dx + dy * dy;

      if (distance < bestDistance) {
        bestDistance = distance;
        best = cell;
      }
    }

    return best;
  }

  // ==============================================================
  // TRAJECTORY
  // ==============================================================

  TrajectoryResult _calculateTrajectory(
    Size size,
  ) {
    final double radius =
        _radiusForWidth(size.width);

    final double shooterX =
        size.width / 2;

    final double shooterY =
        size.height - 135;

    final double targetX =
        _aimX * size.width;

    final double targetY =
        _aimY * size.height;

    double dx = targetX - shooterX;
    double dy = targetY - shooterY;

    // Never shoot downward. Keep a useful upward angle even when
    // the player taps close to the bottom of the screen.
    if (dy > -60) {
      dy = -60;
    }

    double length = sqrt(dx * dx + dy * dy);
    if (length < 1) {
      length = 1;
    }

    dx /= length;
    dy /= length;

    double x = shooterX;
    double y = shooterY;
    double vx = dx;
    double vy = dy;

    final List<Offset> points = [];
    GameBubble? collision;

    // Use small steps and test the whole movement segment against
    // every bubble. This prevents a fast reflected shot from
    // skipping over a bubble between two trajectory points.
    const double step = 2.5;

    for (int i = 0; i < 1400; i++) {
      final double previousX = x;
      final double previousY = y;

      x += vx * step;
      y += vy * step;

      // ----------------------------------------------------------
      // WALL REFLECTION
      // ----------------------------------------------------------
      // Reflect using the actual screen edges. The bubble itself
      // must stay inside the screen, so its center is clamped by
      // the radius.
      final double leftWall = radius;
      final double rightWall = size.width - radius;

      if (x <= leftWall) {
        // Bounce from the left wall and keep the center inside it.
        x = leftWall + (leftWall - x);
        vx = vx.abs();
        if (x <= leftWall) x = leftWall + 0.01;
      } else if (x >= rightWall) {
        // Bounce from the right wall and keep the center inside it.
        x = rightWall - (x - rightWall);
        vx = -vx.abs();
        if (x >= rightWall) x = rightWall - 0.01;
      }

      points.add(Offset(x, y));

      // ----------------------------------------------------------
      // BUBBLE COLLISION
      // ----------------------------------------------------------
      for (final GameBubble bubble in _bubbles) {
        if (bubble.falling || bubble.removing) {
          continue;
        }

        final double segmentX = x - previousX;
        final double segmentY = y - previousY;
        final double segmentLengthSquared =
            segmentX * segmentX +
                segmentY * segmentY;

        double t = 0;
        if (segmentLengthSquared > 0) {
          t = ((bubble.x - previousX) * segmentX +
                  (bubble.y - previousY) * segmentY) /
              segmentLengthSquared;
          t = t.clamp(0.0, 1.0).toDouble();
        }

        final double closestX =
            previousX + segmentX * t;
        final double closestY =
            previousY + segmentY * t;

        final double hitDx =
            closestX - bubble.x;
        final double hitDy =
            closestY - bubble.y;

        final double distanceSquared =
            hitDx * hitDx + hitDy * hitDy;

        // A little tolerance makes edge/reflected shots reliable.
        final double collisionDistance =
            radius * 2.0 + 3.5;

        if (distanceSquared <=
            collisionDistance * collisionDistance) {
          collision = bubble;

          // End exactly at the first contact point. This gives the
          // snap calculation the real reflected impact location.
          x = closestX;
          y = closestY;
          points[points.length - 1] =
              Offset(x, y);
          break;
        }
      }

      if (collision != null) {
        break;
      }

      // ----------------------------------------------------------
      // CEILING
      // ----------------------------------------------------------
      if (y <= _boardTop() - radius) {
        y = _boardTop() - radius;
        points[points.length - 1] =
            Offset(x, y);
        break;
      }
    }

    return TrajectoryResult(
      points: points,
      collision: collision,
      end: Offset(x, y),
    );
  }

  // ==============================================================
  // SHOOT
  // ==============================================================

  Future<void> _shoot(Size size) async {
    if (_paused || _gameFinished || _shooting || _movesLeft <= 0) return;

    // Never shoot a normal color that no longer exists on the board.
    if (_selectedPower == PowerMode.none) {
      _refreshShooterColors();
    }

    _updateBubblePositions(size);
    final trajectory = _calculateTrajectory(size);
    if (trajectory.points.isEmpty) return;

    setState(() {
      _shooting = true;
      _message = '';
      _messageLife = 0;
      _flyingBubbleVisible = true;
      _flyingType = _selectedPower == PowerMode.bomb
          ? BubbleType.bomb
          : _selectedPower == PowerMode.rainbow
              ? BubbleType.rainbow
              : _currentBubble;
      _flyingX = size.width / 2;
      _flyingY = size.height - 135;
    });

    // Smoothly animate the bubble along the calculated trajectory.
    final path = trajectory.points;
    const desiredFrames = 5;
    final stepSize = max(5, path.length ~/ desiredFrames);
    Offset lastPoint = Offset(_flyingX, _flyingY);

    for (int i = 0; i < path.length; i += stepSize) {
      if (!mounted) return;
      while (_paused && mounted && !_gameFinished) {
        await Future.delayed(const Duration(milliseconds: 80));
      }
      if (!mounted || _gameFinished) return;

      final point = path[i];
      setState(() {
        _flyingX = point.dx;
        _flyingY = point.dy;
      });
      lastPoint = point;
      await Future.delayed(const Duration(milliseconds: 7));
    }

    // Always show the bubble at the exact collision/end point.
    if (mounted && (lastPoint - trajectory.end).distance > 0.5) {
      setState(() {
        _flyingX = trajectory.end.dx;
        _flyingY = trajectory.end.dy;
      });
      await Future.delayed(const Duration(milliseconds: 15));
    }
    if (!mounted) return;

    final cell = _findBestSnapCell(
      trajectory.end,
      trajectory.collision,
      size.width,
    );

    if (cell == null) {
      setState(() {
        _flyingBubbleVisible = false;
        _shooting = false;
      });
      return;
    }

    final row = cell[0];
    final column = cell[1];
    final snapPosition = _cellPosition(row, column, size.width);

    if (_selectedPower != PowerMode.none) {
      await _resolvePowerShot(row, column, snapPosition);
    } else {
      final shot = GameBubble(
        row: row,
        column: column,
        type: _currentBubble,
        x: snapPosition.dx,
        y: snapPosition.dy,
        scale: 0.20,
      );

      setState(() {
        _bubbles.add(shot);
        _flyingBubbleVisible = false;
        _movesLeft--;
      });

      // Small scale-in animation when the bubble snaps to the board.
      const animationSteps = 10;
      for (int i = 0; i <= animationSteps; i++) {
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 18));
        final progress = i / animationSteps;
        final scale = 0.20 + 0.80 * (1 - pow(1 - progress, 3));
        setState(() => shot.scale = scale.toDouble());
      }
      if (mounted) setState(() => shot.scale = 1.0);

      await _resolveNormalShot(shot);
      if (!mounted) return;

      setState(() {
        _currentBubble = _nextBubble;
        _nextBubble = _randomShooterBubble();
        _refreshShooterColors();
      });
    }

    if (!mounted) return;
    setState(() {
      _shooting = false;
      _selectedPower = PowerMode.none;
    });
    _checkGameState();
  }

  // ==============================================================
  // NORMAL SHOT
  // ==============================================================

  Future<void> _resolveNormalShot(
    GameBubble shot,
  ) async {
    final List<GameBubble> group =
        _findConnectedGroup(
      shot,
    );

    if (group.length >= 3) {
      _combo++;

      final int comboMultiplier =
          min(5, _combo);

      final int basePoints =
          group.length *
              25 *
              widget.levelNumber;

      final int comboBonus =
          comboMultiplier *
              30 *
              widget.levelNumber;

      int bonus = comboBonus;

      if (group.length >= 5) {
        bonus +=
            100 *
                widget.levelNumber;
      }

      if (group.length >= 7) {
        bonus +=
            250 *
                widget.levelNumber;
      }

      final int totalPoints =
          basePoints + bonus;

      if (group.length >= 7) {
        _message =
            'SUPER COMBO  +$totalPoints';
      } else if (group.length >= 5) {
        _message =
            'GREAT COMBO  +$totalPoints';
      } else {
        _message =
            'MATCH  +$totalPoints';
      }

      _messageLife = 1.8;

      _score += totalPoints;

      // ----------------------------------------------------------
      // Mark bubbles
      // ----------------------------------------------------------

      for (final GameBubble bubble
          in group) {
        bubble.removing = true;
      }

      // ----------------------------------------------------------
      // Particles
      // ----------------------------------------------------------

      for (final GameBubble bubble
          in group) {
        _createBurst(
          bubble.x,
          bubble.y,
          bubble.type,
          amount: 12,
        );
      }

      _addScorePopup(
        group.first.x,
        group.first.y,
        '+$totalPoints',
      );

      _shake = 3;

      // ----------------------------------------------------------
      // POP
      // ----------------------------------------------------------

      for (int i = 0;
          i < 10;
          i++) {
        if (!mounted) return;

        await Future.delayed(
          const Duration(milliseconds: 28),
        );

        setState(() {
          for (final GameBubble bubble
              in group) {
            bubble.scale =
                1.0 + i * 0.045;

            bubble.opacity =
                1.0 - i / 10;
          }
        });
      }

      if (!mounted) return;

      setState(() {
        _bubbles.removeWhere(
          group.contains,
        );
      });

      await Future.delayed(
        const Duration(milliseconds: 80),
      );

      await _dropFloatingBubbles();
    } else {
      _combo = 0;

      _misses++;

      if (!mounted) return;

      setState(() {
        _message =
            'GOOD SHOT';
        _messageLife = 0.8;
      });

      // ----------------------------------------------------------
      // Five misses = penalty row
      // ----------------------------------------------------------

      if (_misses >= 5) {
        _misses = 0;

        await Future.delayed(
          const Duration(milliseconds: 150),
        );
      }
    }
  }

  // ==============================================================
  // FIND CONNECTED GROUP
  // ==============================================================

  List<GameBubble> _findConnectedGroup(
    GameBubble start,
  ) {
    if (start.type ==
            BubbleType.bomb ||
        start.type ==
            BubbleType.rainbow ||
        start.type ==
            BubbleType.stone) {
      return [start];
    }

    final List<GameBubble> result =
        [start];

    final List<GameBubble> queue =
        [start];

    while (queue.isNotEmpty) {
      final GameBubble current =
          queue.removeAt(0);

      for (final List<int> cell
          in _neighbors(
        current.row,
        current.column,
      )) {
        final GameBubble? bubble =
            _bubbleAt(
          cell[0],
          cell[1],
        );

        if (bubble == null ||
            result.contains(bubble)) {
          continue;
        }

        if (bubble.type !=
            start.type) {
          continue;
        }

        result.add(bubble);

        queue.add(bubble);
      }
    }

    return result;
  }

  // ==============================================================
  // POWER SHOT
  // ==============================================================

  Future<void> _resolvePowerShot(
    int row,
    int column,
    Offset position,
  ) async {
    final PowerMode power =
        _selectedPower;

    // ============================================================
    // BOMB
    // ============================================================

    if (power ==
        PowerMode.bomb) {
      if (_bombCount <= 0) return;

      _bombCount--;

      _movesLeft--;

      final List<GameBubble> affected =
          _bubbles.where(
        (bubble) {
          if (bubble.falling) {
            return false;
          }

          final double dx =
              bubble.x - position.dx;

          final double dy =
              bubble.y - position.dy;

          return sqrt(
                dx * dx +
                    dy * dy,
              ) <=
              92;
        },
      ).toList();

      final int points =
          max(
            1,
            affected.length,
          ) *
          45 *
          widget.levelNumber;

      _score += points;

      _message =
          'BOMB BLAST  +$points';

      _messageLife = 1.8;

      _shake = 12;

      _createExplosion(
        position.dx,
        position.dy,
      );

      _addScorePopup(
        position.dx,
        position.dy,
        '+$points',
      );

      for (final GameBubble bubble
          in affected) {
        bubble.removing = true;
      }

      for (int i = 0;
          i < 12;
          i++) {
        if (!mounted) return;

        await Future.delayed(
          const Duration(milliseconds: 30),
        );

        setState(() {
          for (final GameBubble bubble
              in affected) {
            bubble.scale =
                1 + i * 0.08;

            bubble.opacity =
                1 - i / 12;
          }
        });
      }

      if (!mounted) return;

      setState(() {
        _bubbles.removeWhere(
          affected.contains,
        );

        _flyingBubbleVisible =
            false;
      });

      await _dropFloatingBubbles();

      return;
    }

    // ============================================================
    // RAINBOW
    // ============================================================

    if (power ==
        PowerMode.rainbow) {
      if (_rainbowCount <= 0) return;

      _rainbowCount--;

      _movesLeft--;

      final List<GameBubble>
          normalBubbles =
          _bubbles.where(
        (bubble) =>
            bubble.type !=
                BubbleType.stone &&
            bubble.type !=
                BubbleType.bomb &&
            bubble.type !=
                BubbleType.rainbow &&
            !bubble.falling,
      ).toList();

      if (normalBubbles.isEmpty) {
        _flyingBubbleVisible =
            false;
        return;
      }

      final BubbleType target =
          normalBubbles[
            _random.nextInt(
              normalBubbles.length,
            )
          ].type;

      final List<GameBubble>
          affected =
          _bubbles.where(
        (bubble) =>
            bubble.type == target,
      ).toList();

      final int points =
          max(
            1,
            affected.length,
          ) *
          40 *
          widget.levelNumber;

      _score += points;

      _message =
          'RAINBOW BLAST  +$points';

      _messageLife = 1.8;

      _shake = 6;

      for (final GameBubble bubble
          in affected) {
        bubble.removing = true;

        _createBurst(
          bubble.x,
          bubble.y,
          target,
          amount: 10,
        );
      }

      _addScorePopup(
        position.dx,
        position.dy,
        '+$points',
      );

      for (int i = 0;
          i < 10;
          i++) {
        if (!mounted) return;

        await Future.delayed(
          const Duration(milliseconds: 28),
        );

        setState(() {
          for (final GameBubble bubble
              in affected) {
            bubble.scale =
                1 - i / 12;

            bubble.opacity =
                1 - i / 10;
          }
        });
      }

      if (!mounted) return;

      setState(() {
        _bubbles.removeWhere(
          affected.contains,
        );

        _flyingBubbleVisible =
            false;
      });

      await _dropFloatingBubbles();

      return;
    }

    // ============================================================
    // LIGHTNING
    // ============================================================

    if (power ==
        PowerMode.lightning) {
      if (_lightningCount <= 0) return;

      _lightningCount--;

      _movesLeft--;

      final List<GameBubble>
          affected =
          _bubbles.where(
        (bubble) {
          if (bubble.falling) {
            return false;
          }

          return (bubble.column -
                      column)
                  .abs() <=
              1;
        },
      ).toList();

      final int points =
          max(
            1,
            affected.length,
          ) *
          50 *
          widget.levelNumber;

      _score += points;

      _message =
          'LIGHTNING  +$points';

      _messageLife = 1.8;

      _shake = 7;

      _createLightning(
        position,
      );

      _addScorePopup(
        position.dx,
        position.dy,
        '+$points',
      );

      for (final GameBubble bubble
          in affected) {
        bubble.removing = true;
      }

      for (int i = 0;
          i < 9;
          i++) {
        if (!mounted) return;

        await Future.delayed(
          const Duration(milliseconds: 30),
        );

        setState(() {
          for (final GameBubble bubble
              in affected) {
            bubble.scale =
                1.15 - i / 10;

            bubble.opacity =
                1 - i / 9;
          }
        });
      }

      if (!mounted) return;

      setState(() {
        _bubbles.removeWhere(
          affected.contains,
        );

        _flyingBubbleVisible =
            false;
      });

      await _dropFloatingBubbles();

      return;
    }

    // ============================================================
    // ROCKET
    // ============================================================

    if (power ==
        PowerMode.rocket) {
      if (_rocketCount <= 0) return;

      _rocketCount--;

      _movesLeft--;

      // Rocket clears a complete horizontal row. If the exact snap row
      // has no bubbles, clear the nearest active row instead.
      final activeRows = _bubbles
          .where((bubble) => !bubble.falling && !bubble.removing)
          .map((bubble) => bubble.row)
          .toSet()
          .toList();

      int targetRow = row;
      if (activeRows.isNotEmpty && !activeRows.contains(targetRow)) {
        activeRows.sort((a, b) => (a - row).abs().compareTo((b - row).abs()));
        targetRow = activeRows.first;
      }

      final List<GameBubble> affected = _bubbles.where(
        (bubble) =>
            !bubble.falling &&
            !bubble.removing &&
            bubble.row == targetRow,
      ).toList();

      final int points =
          max(
            1,
            affected.length,
          ) *
          55 *
          widget.levelNumber;

      _score += points;

      _message =
          'ROCKET STRIKE  +$points';

      _messageLife = 1.8;

      _shake = 8;

      _createRocketTrail(
        position,
      );

      _addScorePopup(
        position.dx,
        position.dy,
        '+$points',
      );

      for (final GameBubble bubble
          in affected) {
        bubble.removing = true;
      }

      for (int i = 0;
          i < 10;
          i++) {
        if (!mounted) return;

        await Future.delayed(
          const Duration(milliseconds: 28),
        );

        setState(() {
          for (final GameBubble bubble
              in affected) {
            bubble.scale =
                1.0 - i / 12;

            bubble.opacity =
                1 - i / 10;
          }
        });
      }

      if (!mounted) return;

      setState(() {
        _bubbles.removeWhere(
          affected.contains,
        );

        _flyingBubbleVisible =
            false;
      });

      await _dropFloatingBubbles();
    }
  }

  // ==============================================================
  // DROP FLOATING BUBBLES
  // ==============================================================

  Future<void> _dropFloatingBubbles() async {
    final Set<GameBubble>
        connected = {};

    // ------------------------------------------------------------
    // Anything connected to top row remains.
    // ------------------------------------------------------------

    final List<GameBubble>
        queue =
        _bubbles.where(
      (bubble) =>
          !bubble.falling &&
          !bubble.removing &&
          bubble.row == 0,
    ).toList();

    while (queue.isNotEmpty) {
      final GameBubble current =
          queue.removeLast();

      if (!connected.add(
        current,
      )) {
        continue;
      }

      for (final List<int> cell
          in _neighbors(
        current.row,
        current.column,
      )) {
        final GameBubble? bubble =
            _bubbleAt(
          cell[0],
          cell[1],
        );

        if (bubble == null ||
            connected.contains(
              bubble,
            )) {
          continue;
        }

        queue.add(bubble);
      }
    }

    // ------------------------------------------------------------
    // Floating bubbles.
    // ------------------------------------------------------------

    final List<GameBubble>
        floating =
        _bubbles.where(
      (bubble) =>
          !bubble.falling &&
          !bubble.removing &&
          !connected.contains(
            bubble,
          ),
    ).toList();

    if (floating.isEmpty) {
      return;
    }

    final int points =
        floating.length *
            35 *
            widget.levelNumber;

    _score += points;

    if (floating.length >= 4) {
    }

    _message =
        'DROP BONUS  +$points';

    _messageLife = 1.6;

    _addScorePopup(
      floating.first.x,
      floating.first.y,
      '+$points',
    );

    _shake = 5;

    for (final GameBubble bubble
        in floating) {
      bubble.falling = true;

      bubble.velocityY =
          1.0 +
              _random.nextDouble() *
                  2.5;

      bubble.rotation =
          (_random.nextDouble() -
                  0.5) *
              0.25;

      _createBurst(
        bubble.x,
        bubble.y,
        bubble.type,
        amount: 5,
      );
    }

    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    setState(() {
      _bubbles.removeWhere(
        floating.contains,
      );
    });
  }

  // ==============================================================
  // PENALTY ROW
  // ==============================================================

  // ==============================================================
  // TARGET SCORE / STARS
  // ==============================================================

  int _targetScore() => 1000 * widget.levelNumber;

  int _calculateResultStars(bool won) {
    if (!won) return 0;

    final int target = _targetScore();

    // Clearing the board is the win condition.
    // Score controls the quality of the result, not whether the level ends.
    if (_score >= target + (target ~/ 2)) return 3;
    if (_score >= target) return 2;
    return 1;
  }

  // ==============================================================
  // LEVEL COMPLETION
  // ==============================================================

  Future<void> _checkLevelCompletion() async {
    if (_gameFinished || _completionCheckPending || !mounted) return;

    _completionCheckPending = true;

    // Allow the final pop and floating-bubble animations to finish.
    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted || _gameFinished) {
      _completionCheckPending = false;
      return;
    }

    final bool boardEmpty = _bubbles.every(
      (bubble) => bubble.falling || bubble.removing,
    );

    _completionCheckPending = false;

    if (boardEmpty) {
      setState(() {
        _message = 'LEVEL COMPLETE!';
        _messageLife = 1.2;
      });

      await Future.delayed(const Duration(milliseconds: 650));

      if (mounted && !_gameFinished) {
        await _finishGame(true);
      }
    }
  }

  // ==============================================================
  // CHECK GAME STATE
  // ==============================================================

  void _checkGameState() {
    if (_gameFinished || !mounted) return;

    final List<GameBubble> active = _bubbles.where(
      (bubble) => !bubble.falling && !bubble.removing,
    ).toList();

    // WIN: the board is empty. Target score is NOT required to win.
    if (active.isEmpty) {
      _checkLevelCompletion();
      return;
    }

    // LOSE: an active bubble crosses the danger line.
    final double height = MediaQuery.sizeOf(context).height;
    final bool dangerous = active.any(
      (bubble) => bubble.y > height - 185,
    );

    if (dangerous) {
      _finishGame(false);
      return;
    }

    // LOSE: no moves remain and the board is still not empty.
    if (_movesLeft <= 0 && !_shooting) {
      _finishGame(false);
    }
  }

  // ==============================================================
  // FINISH GAME
  // ==============================================================

  Future<void> _finishGame(bool won) async {
    if (_gameFinished || !mounted) return;

    setState(() {
      _gameFinished = true;
      _paused = false;
      _completionCheckPending = false;
    });

    final int calculatedStars = _calculateResultStars(won);
    final int target = _targetScore();

    await _saveResult(won, calculatedStars);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          playerId: widget.playerId,
          playerName: widget.playerName,
          levelNumber: widget.levelNumber,
          score: _score,
          won: won,
          movesLeft: _movesLeft,
          stars: calculatedStars,
          targetScore: target,
        ),
      ),
    );
  }

  // ==============================================================
  // SAVE RESULT
  // ==============================================================

  Future<void> _saveResult(
    bool won,
    int stars,
  ) async {
    if (_savingResult) {
      return;
    }

    _savingResult = true;

    try {
      final prefs =
          await SharedPreferences
              .getInstance();

      final int oldBest =
          prefs.getInt(
                'highestScore',
              ) ??
              0;

      final int oldStars =
          prefs.getInt(
                'totalStars',
              ) ??
              0;

      final int oldLevel =
          prefs.getInt(
                'currentLevel',
              ) ??
              1;

      final int oldWon =
          prefs.getInt(
                'gamesWon',
              ) ??
              0;

      final int bestScore =
          max(
            oldBest,
            _score,
          );

      final int totalStars =
          oldStars + stars;

      final int newLevel =
          won
              ? max(
                  oldLevel,
                  widget.levelNumber + 1,
                )
              : max(
                  oldLevel,
                  widget.levelNumber,
                );

      final int gamesWon =
          won
              ? oldWon + 1
              : oldWon;

      await prefs.setInt(
        'currentLevel',
        newLevel,
      );

      await prefs.setInt(
        'currentScore',
        _score,
      );

      await prefs.setInt(
        'highestScore',
        bestScore,
      );

      await prefs.setInt(
        'totalStars',
        totalStars,
      );

      await prefs.setInt(
        'gamesWon',
        gamesWon,
      );

      // ----------------------------------------------------------
      // Backend
      // ----------------------------------------------------------

      await http
          .put(
            Uri.parse(
              '$baseUrl/api/players/'
              '${widget.playerId}/progress',
            ),
            headers: const {
              'Content-Type':
                  'application/json',
            },
            body: jsonEncode({
              'currentLevel':
                  newLevel,
              'currentScore':
                  _score,
              'highestScore':
                  bestScore,
              'totalStars':
                  totalStars,
              'gamesWon':
                  gamesWon,
              'gameWon':
                  won,
              'gameLost':
                  !won,
            }),
          )
          .timeout(
            const Duration(
              seconds: 5,
            ),
          );
    } catch (e) {
      debugPrint(
        'Save game result error: $e',
      );
    } finally {
      _savingResult = false;
    }
  }

  // ==============================================================
  // CREATE BURST
  // ==============================================================

  void _createBurst(
    double x,
    double y,
    BubbleType type, {
    int amount = 10,
  }) {
    final Color color =
        BubbleGamePainter
            .bubbleColorStatic(type);

    for (int i = 0;
        i < amount;
        i++) {
      final double angle =
          _random.nextDouble() *
              pi *
              2;

      final double speed =
          1.2 +
              _random.nextDouble() *
                  3.8;

      _particles.add(
        GameParticle(
          x: x,
          y: y,
          vx:
              cos(angle) *
                  speed,
          vy:
              sin(angle) *
                  speed,
          size:
              1.5 +
                  _random.nextDouble() *
                      3.2,
          life:
              0.55 +
                  _random.nextDouble() *
                      0.5,
          color: color,
        ),
      );
    }
  }

  // ==============================================================
  // EXPLOSION
  // ==============================================================

  void _createExplosion(
    double x,
    double y,
  ) {
    const List<Color> colors = [
      Color(0xFFFFE066),
      Color(0xFFFF8A30),
      Color(0xFFFF4D6D),
      Colors.white,
    ];

    for (int i = 0;
        i < 80;
        i++) {
      final double angle =
          _random.nextDouble() *
              pi *
              2;

      final double speed =
          1.5 +
              _random.nextDouble() *
                  7;

      _particles.add(
        GameParticle(
          x: x,
          y: y,
          vx:
              cos(angle) *
                  speed,
          vy:
              sin(angle) *
                  speed,
          size:
              2 +
                  _random.nextDouble() *
                      5,
          life:
              0.5 +
                  _random.nextDouble() *
                      0.8,
          color:
              colors[
                _random.nextInt(
                  colors.length,
                )
              ],
        ),
      );
    }
  }

  // ==============================================================
  // LIGHTNING
  // ==============================================================

  void _createLightning(
    Offset start,
  ) {
    for (int i = 0;
        i < 40;
        i++) {
      final double angle =
          _random.nextDouble() *
              pi *
              2;

      final double speed =
          1 +
              _random.nextDouble() *
                  5;

      _particles.add(
        GameParticle(
          x: start.dx,
          y: start.dy,
          vx:
              cos(angle) *
                  speed,
          vy:
              sin(angle) *
                  speed,
          size:
              2 +
                  _random.nextDouble() *
                      3,
          life:
              0.4 +
                  _random.nextDouble() *
                      0.5,
          color:
              const Color(
            0xFF80E8FF,
          ),
        ),
      );
    }
  }

  // ==============================================================
  // ROCKET
  // ==============================================================

  void _createRocketTrail(
    Offset start,
  ) {
    for (int i = 0;
        i < 45;
        i++) {
      _particles.add(
        GameParticle(
          x:
              start.dx +
                  (_random.nextDouble() -
                          0.5) *
                      18,
          y:
              start.dy +
                  _random.nextDouble() *
                      70,
          vx:
              (_random.nextDouble() -
                      0.5) *
                  2,
          vy:
              1 +
                  _random.nextDouble() *
                      4,
          size:
              2 +
                  _random.nextDouble() *
                      3,
          life:
              0.4 +
                  _random.nextDouble() *
                      0.6,
          color:
              const Color(
            0xFFFFD54A,
          ),
        ),
      );
    }
  }

  // ==============================================================
  // SCORE POPUP
  // ==============================================================

  void _addScorePopup(
    double x,
    double y,
    String text,
  ) {
    _scorePopups.add(
      ScorePopup(
        x: x,
        y: y,
        text: text,
      ),
    );
  }

  // ==============================================================
  // RESTART GAME
  // ==============================================================

  void _restartGame() {
    // Do not interrupt a bubble that is currently flying.
    if (!mounted || _shooting) {
      return;
    }

    setState(() {
      _createLevel();

      _aimX = 0.50;
      _aimY = 0.25;
      _dragging = false;

      _flyingBubbleVisible = false;
      _flyingX = 0;
      _flyingY = 0;

      _message = '';
      _messageLife = 0;
      _shake = 0;
    });
  }

  // ==============================================================
  // PAUSE
  // ==============================================================

  void _togglePause() {
    if (_gameFinished) {
      return;
    }

    setState(() {
      _paused = !_paused;
    });
  }

  // ==============================================================
  // CONFIRM BACK
  // ==============================================================

  Future<bool>
      _confirmBackHome() async {
    if (_gameFinished) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final bool? answer =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          backgroundColor:
              const Color(
            0xFF19113F,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              24,
            ),
          ),
          title:
              const Text(
            'Leave Game?',
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content:
              const Text(
            'Your current round will be lost.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text(
                'CANCEL',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF7C4DFF,
                ),
              ),
              child:
                  const Text(
                'LEAVE',
              ),
            ),
          ],
        );
      },
    );

    return answer == true;
  }

  // ==============================================================
  // BACK HOME
  // ==============================================================

  Future<void> _backHome() async {
    if (!mounted) {
      return;
    }

    final bool leave =
        await _confirmBackHome();

    if (!mounted ||
        !leave) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (
        bool didPop,
        dynamic result,
      ) async {
        if (didPop) return;

        await _backHome();
      },
      child: Scaffold(
        backgroundColor:
            const Color(
          0xFF073C5B,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder:
                (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              final Size size =
                  constraints.biggest;

              _updateBubblePositions(
                size,
              );

              final TrajectoryResult
                  trajectory =
                  _calculateTrajectory(
                size,
              );

              return GestureDetector(
                behavior:
                    HitTestBehavior.opaque,

                // ------------------------------------------------
                // TAP
                // ------------------------------------------------

                onTapUp:
                    (TapUpDetails details) {
                  if (!_dragging) {
                    _handleTap(
                      details.localPosition,
                      size,
                    );
                  }

                  _dragging = false;
                },

                // ------------------------------------------------
                // AIM
                // ------------------------------------------------

                onPanStart:
                    (_) {
                  _dragging = true;
                },

                onPanUpdate:
                    (DragUpdateDetails details) {
                  if (!_paused &&
                      !_gameFinished) {
                    _aim(
                      details.localPosition,
                      size,
                    );
                  }
                },

                // ------------------------------------------------
                // SHOOT WHEN DRAG RELEASES
                // ------------------------------------------------

                onPanEnd:
                    (_) {
                  if (_dragging &&
                      !_paused &&
                      !_gameFinished) {
                    _shoot(size);
                  }

                  _dragging = false;
                },

                child: CustomPaint(
                  size: size,
                  painter:
                      BubbleGamePainter(
                    bubbles: _bubbles,
                    particles:
                        _particles,
                    scorePopups:
                        _scorePopups,
                    levelNumber:
                        widget.levelNumber,
                    score:
                        _score,
                    movesLeft:
                        _movesLeft,
                    stars:
                        _score >= _targetScore() + (_targetScore() ~/ 2)
                            ? 3
                            : _score >= _targetScore()
                                ? 2
                                : 0,
                    currentBubble:
                        _currentBubble,
                    nextBubble:
                        _nextBubble,
                    aimX:
                        _aimX,
                    aimY:
                        _aimY,
                    paused:
                        _paused,
                    gameFinished:
                        _gameFinished,
                    message: _message,
messageLife: _messageLife,
animationTime: _animationTime,
                    flyingBubbleVisible:
                        _flyingBubbleVisible,
                    flyingX:
                        _flyingX,
                    flyingY:
                        _flyingY,
                    flyingType:
                        _flyingType,
                    selectedPower:
                        _selectedPower,
                    bombCount:
                        _bombCount,
                    lightningCount:
                        _lightningCount,
                    rainbowCount:
                        _rainbowCount,
                    rocketCount:
                        _rocketCount,
                    trajectory:
                        trajectory,
                    shake:
                        _shake,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// PAINTER
// ==================================================================

class BubbleGamePainter
    extends CustomPainter {
  final List<GameBubble> bubbles;

  final List<GameParticle> particles;

  final List<ScorePopup> scorePopups;

  final int levelNumber;

  final int score;

  final int movesLeft;

  final int stars;

  final BubbleType currentBubble;

  final BubbleType nextBubble;

  final double aimX;

  final double aimY;

  final bool paused;

  final bool gameFinished;

final String message;
final double messageLife;
final double animationTime;

  final bool flyingBubbleVisible;

  final double flyingX;

  final double flyingY;

  final BubbleType flyingType;

  final PowerMode selectedPower;

  final int bombCount;

  final int lightningCount;

  final int rainbowCount;

  final int rocketCount;

  final TrajectoryResult trajectory;

  final double shake;

  BubbleGamePainter({
    required this.bubbles,
    required this.particles,
    required this.scorePopups,
    required this.levelNumber,
    required this.score,
    required this.movesLeft,
    required this.stars,
    required this.currentBubble,
    required this.nextBubble,
    required this.aimX,
    required this.aimY,
    required this.paused,
   required this.gameFinished,
required this.message,
required this.messageLife,
required this.animationTime,
    required this.flyingBubbleVisible,
    required this.flyingX,
    required this.flyingY,
    required this.flyingType,
    required this.selectedPower,
    required this.bombCount,
    required this.lightningCount,
    required this.rainbowCount,
    required this.rocketCount,
    required this.trajectory,
    required this.shake,
  });

  // ==============================================================
  // STATIC BUBBLE COLOR
  // ==============================================================

  static Color bubbleColorStatic(
    BubbleType type,
  ) {
    switch (type) {
      case BubbleType.red:
        return const Color(
          0xFFFF3B64,
        );

      case BubbleType.blue:
        return const Color(
          0xFF2584FF,
        );

      case BubbleType.green:
        return const Color(
          0xFF18D889,
        );

      case BubbleType.yellow:
        return const Color(
          0xFFFFCA28,
        );

      case BubbleType.purple:
        return const Color(
          0xFFB94DFF,
        );

      case BubbleType.orange:
        return const Color(
          0xFFFF8A32,
        );

      case BubbleType.bomb:
        return const Color(
          0xFF343B4D,
        );

      case BubbleType.rainbow:
        return const Color(
          0xFFFF54D9,
        );

      case BubbleType.stone:
        return const Color(
          0xFF747A82,
        );
    }
  }

  // ==============================================================
  // BACKGROUND
  // ==============================================================

  List<Color> _backgroundColors() {
    const List<List<Color>>
        themes = [
      [
        Color(0xFF063A55),
        Color(0xFF19B8A7),
      ],
      [
        Color(0xFF071F4D),
        Color(0xFF075985),
      ],
      [
        Color(0xFF24104D),
        Color(0xFF8B2FC9),
      ],
      [
        Color(0xFF064E52),
        Color(0xFF10A989),
      ],
      [
        Color(0xFF103A50),
        Color(0xFF167D9A),
      ],
    ];

    return themes[
        ((levelNumber - 1) ~/ 5) %
            themes.length];
  }

  // ==============================================================
  // TEXT
  // ==============================================================

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    double size, {
    bool bold = false,
    Color color = Colors.white,
  }) {
    final TextPainter painter =
        TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold
              ? FontWeight.w900
              : FontWeight.w600,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      position,
    );
  }

  // ==============================================================
  // CENTER TEXT
  // ==============================================================

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    double size, {
    bool bold = false,
    Color color = Colors.white,
  }) {
    final TextPainter painter =
        TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold
              ? FontWeight.w900
              : FontWeight.w600,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      center -
          Offset(
            painter.width / 2,
            painter.height / 2,
          ),
    );
  }

  // ==============================================================
  // ROUNDED CARD
  // ==============================================================

  void _drawCard(
    Canvas canvas,
    Rect rect, {
    double radius = 16,
    double opacity = 0.16,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(radius),
      ),
      Paint()
        ..color =
            Colors.white.withValues(
          alpha: opacity,
        ),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(radius),
      ),
      Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 1
        ..color =
            Colors.white.withValues(
          alpha: 0.16,
        ),
    );
  }

  // ==============================================================
  // BUBBLE
  // ==============================================================

  void _drawBubble(
    Canvas canvas,
    Offset center,
    BubbleType type,
    double radius, {
    double scale = 1,
    double opacity = 1,
    double rotation = 0,
  }) {
    canvas.save();

    canvas.translate(
      center.dx,
      center.dy,
    );

    canvas.rotate(rotation);

    canvas.scale(scale);

    final Color color =
        bubbleColorStatic(type);

    // ------------------------------------------------------------
    // Outer glow
    // ------------------------------------------------------------

    canvas.drawCircle(
      const Offset(0, 2),
      radius + 3,
      Paint()
        ..color =
            color.withValues(
          alpha: 0.18 * opacity,
        ),
    );

    // ------------------------------------------------------------
    // Shadow
    // ------------------------------------------------------------

    canvas.drawCircle(
      const Offset(2, 4),
      radius,
      Paint()
        ..color =
            Colors.black.withValues(
          alpha: 0.30 * opacity,
        ),
    );

    // ------------------------------------------------------------
    // Glossy gradient
    // ------------------------------------------------------------

    final RadialGradient
        gradient =
        RadialGradient(
      center:
          const Alignment(
        -0.35,
        -0.42,
      ),
      radius: 0.85,
      colors: [
        Colors.white.withValues(
          alpha:
              0.95 * opacity,
        ),
        color.withValues(
          alpha: opacity,
        ),
        Color.lerp(
              color,
              Colors.black,
              0.20,
            )!
            .withValues(
          alpha:
              0.90 * opacity,
        ),
      ],
      stops: const [
        0.0,
        0.42,
        1.0,
      ],
    );

    final Paint paint =
        Paint()
          ..shader =
              gradient.createShader(
        Rect.fromCircle(
          center: Offset.zero,
          radius: radius,
        ),
      );

    canvas.drawCircle(
      Offset.zero,
      radius,
      paint,
    );

    // ------------------------------------------------------------
    // Border
    // ------------------------------------------------------------

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color =
            Colors.white.withValues(
          alpha:
              0.42 * opacity,
        ),
    );

    // ------------------------------------------------------------
    // Highlight
    // ------------------------------------------------------------

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          -radius * 0.32,
          -radius * 0.36,
        ),
        width: radius * 0.48,
        height: radius * 0.26,
      ),
      Paint()
        ..color =
            Colors.white.withValues(
          alpha:
              0.68 * opacity,
        ),
    );

    // ------------------------------------------------------------
    // SMALL REFLECTION
    // ------------------------------------------------------------

    canvas.drawCircle(
      Offset(
        radius * 0.30,
        radius * 0.30,
      ),
      radius * 0.07,
      Paint()
        ..color =
            Colors.white.withValues(
          alpha:
              0.32 * opacity,
        ),
    );

    // ============================================================
    // BOMB
    // ============================================================

    if (type ==
        BubbleType.bomb) {
      canvas.drawCircle(
        Offset.zero,
        radius * 0.56,
        Paint()
          ..color =
              const Color(
            0xFF171B28,
          ).withValues(
            alpha:
                opacity,
          ),
      );

      canvas.drawCircle(
        Offset.zero,
        radius * 0.56,
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color =
              Colors.white.withValues(
            alpha:
                0.25 * opacity,
          ),
      );

      // Fuse
      final Path fuse =
          Path();

      fuse.moveTo(
        radius * 0.10,
        -radius * 0.53,
      );

      fuse.cubicTo(
        radius * 0.35,
        -radius * 0.85,
        radius * 0.70,
        -radius * 0.62,
        radius * 0.52,
        -radius * 0.92,
      );

      canvas.drawPath(
        fuse,
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap =
              StrokeCap.round
          ..color =
              const Color(
            0xFFFFC857,
          ).withValues(
            alpha:
                opacity,
          ),
      );

      // Bomb shine
      canvas.drawCircle(
        Offset(
          -radius * 0.22,
          -radius * 0.22,
        ),
        radius * 0.10,
        Paint()
          ..color =
              Colors.white.withValues(
            alpha:
                0.70 * opacity,
          ),
      );
    }

    // ============================================================
    // RAINBOW
    // ============================================================

    if (type ==
        BubbleType.rainbow) {
      final Paint ring =
          Paint()
            ..style =
                PaintingStyle.stroke
            ..strokeWidth =
                radius * 0.15;

      const List<Color>
          rainbow = [
        Color(0xFFFF3B5C),
        Color(0xFFFF8A30),
        Color(0xFFFFD43B),
        Color(0xFF20D68B),
        Color(0xFF2684FF),
        Color(0xFFB84DFF),
      ];

      for (int i = 0;
          i < rainbow.length;
          i++) {
        ring.color =
            rainbow[i].withValues(
          alpha: opacity,
        );

        canvas.drawArc(
          Rect.fromCircle(
            center: Offset.zero,
            radius:
                radius * 0.58,
          ),
          i * pi / 3,
          pi / 3,
          false,
          ring,
        );
      }

      canvas.drawCircle(
        Offset.zero,
        radius * 0.25,
        Paint()
          ..color =
              Colors.white.withValues(
            alpha:
                0.65 * opacity,
          ),
      );

      _drawCenteredText(
        canvas,
        '★',
        Offset.zero,
        radius * 0.48,
        bold: true,
        color:
            const Color(
          0xFFFFF4FF,
        ),
      );
    }

    // ============================================================
    // STONE
    // ============================================================

    if (type ==
        BubbleType.stone) {
      canvas.drawCircle(
        Offset.zero,
        radius * 0.82,
        Paint()
          ..color =
              const Color(
            0xFF555B63,
          ).withValues(
            alpha:
                0.85 * opacity,
          ),
      );

      final Paint crack =
          Paint()
            ..style =
                PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color =
                Colors.white.withValues(
              alpha:
                  0.35 * opacity,
            );

      final Path p1 =
          Path();

      p1.moveTo(
        -radius * 0.40,
        -radius * 0.10,
      );

      p1.lineTo(
        -radius * 0.08,
        radius * 0.05,
      );

      p1.lineTo(
        -radius * 0.25,
        radius * 0.40,
      );

      canvas.drawPath(
        p1,
        crack,
      );

      final Path p2 =
          Path();

      p2.moveTo(
        radius * 0.18,
        -radius * 0.50,
      );

      p2.lineTo(
        radius * 0.04,
        -radius * 0.12,
      );

      p2.lineTo(
        radius * 0.38,
        radius * 0.12,
      );

      canvas.drawPath(
        p2,
        crack,
      );
    }

    canvas.restore();
  }

  // ==============================================================
  // AIM LINE
  // ==============================================================

  void _drawAimLine(
    Canvas canvas,
    Size size,
  ) {
    if (trajectory.points.isEmpty) {
      return;
    }

    // ------------------------------------------------------------
    // Soft trajectory glow
    // ------------------------------------------------------------

    final Paint glow =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap =
              StrokeCap.round
          ..color =
              Colors.white.withValues(
            alpha: 0.08,
          );

    final Path glowPath =
        Path();

    bool first = true;

    for (final Offset point
        in trajectory.points) {
      if (first) {
        glowPath.moveTo(
          point.dx,
          point.dy,
        );

        first = false;
      } else {
        glowPath.lineTo(
          point.dx,
          point.dy,
        );
      }
    }

    canvas.drawPath(
      glowPath,
      glow,
    );

    // ------------------------------------------------------------
    // Dots
    // ------------------------------------------------------------

    for (int i = 0;
        i <
            trajectory.points
                .length;
        i += 4) {
      final Offset point =
          trajectory.points[i];

      final double pulse =
          0.70 +
              sin(
                    animationTime *
                        2 +
                        i * 0.12,
                  ) *
                  0.15;

      canvas.drawCircle(
        point,
        2.3,
        Paint()
          ..color =
              Colors.white.withValues(
            alpha:
                pulse,
          ),
      );
    }

    // ------------------------------------------------------------
    // Aim arrow at end
    // ------------------------------------------------------------

    if (trajectory.points
        .length >= 3) {
      final Offset a =
          trajectory.points[
              trajectory.points.length -
                  1];

      final Offset b =
          trajectory.points[
              trajectory.points.length -
                  3];

      final double angle =
          atan2(
        a.dy - b.dy,
        a.dx - b.dx,
      );

      final Path arrow =
          Path();

      arrow.moveTo(
        a.dx,
        a.dy,
      );

      arrow.lineTo(
        a.dx -
            cos(angle - 0.55) *
                10,
        a.dy -
            sin(angle - 0.55) *
                10,
      );

      arrow.lineTo(
        a.dx -
            cos(angle + 0.55) *
                10,
        a.dy -
            sin(angle + 0.55) *
                10,
      );

      arrow.close();

      canvas.drawPath(
        arrow,
        Paint()
          ..color =
              Colors.white.withValues(
            alpha: 0.85,
          ),
      );
    }
  }

  // ==============================================================
  // PARTICLES
  // ==============================================================

  void _drawParticles(
    Canvas canvas,
  ) {
    for (final GameParticle particle
        in particles) {
      canvas.drawCircle(
        Offset(
          particle.x,
          particle.y,
        ),
        particle.size,
        Paint()
          ..color =
              particle.color
                  .withValues(
            alpha:
                particle.life
                    .clamp(
                      0.0,
                      1.0,
                    )
                    .toDouble(),
          ),
      );
    }
  }

  // ==============================================================
  // SCORE POPUPS
  // ==============================================================

  void _drawScorePopups(
    Canvas canvas,
  ) {
    for (final ScorePopup popup
        in scorePopups) {
      _drawCenteredText(
        canvas,
        popup.text,
        Offset(
          popup.x,
          popup.y,
        ),
        16,
        bold: true,
        color:
            Colors.white.withValues(
          alpha:
              popup.life
                  .clamp(
                    0.0,
                    1.0,
                  )
                  .toDouble(),
        ),
      );
    }
  }

  // ==============================================================
  // TOP HUD
  // ==============================================================

  void _drawTopHud(
    Canvas canvas,
    Size size,
  ) {
    // ------------------------------------------------------------
    // Top background
    // ------------------------------------------------------------

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        62,
      ),
      Paint()
        ..color =
            const Color(
          0xFF05658A,
        ).withValues(
          alpha: 0.86,
        ),
    );

    // ------------------------------------------------------------
    // Home
    // ------------------------------------------------------------

    canvas.drawCircle(
      const Offset(27, 31),
      19,
      Paint()
        ..color =
            Colors.white.withValues(
          alpha: 0.18,
        ),
    );

    _drawHomeIcon(
      canvas,
      const Offset(27, 31),
    );

    // ------------------------------------------------------------
    // Coin card
    // ------------------------------------------------------------

    _drawCard(
      canvas,
      const Rect.fromLTWH(
        54,
        11,
        86,
        36,
      ),
      radius: 20,
      opacity: 0.18,
    );

    canvas.drawCircle(
      const Offset(70, 29),
      10,
      Paint()
        ..color =
            const Color(
          0xFFFFD43B,
        ),
    );

    _drawCenteredText(
      canvas,
      '★',
      const Offset(70, 29),
      11,
      bold: true,
      color:
          const Color(
        0xFF9A6900,
      ),
    );

    _drawText(
      canvas,
      '${71 + levelNumber}',
      const Offset(
        84,
        20,
      ),
      15,
      bold: true,
    );

    // ------------------------------------------------------------
    // Progress bar
    // ------------------------------------------------------------

    final double progress =
        movesLeft /
            max(
              1,
              38 -
                  ((levelNumber - 1) ~/
                      2),
            );

    // Keep the progress bar in the same top line while leaving
    // space for Restart and Pause on the right.
    final Rect bar =
        Rect.fromLTWH(
      162,
      27,
      size.width - 280,
      8,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bar,
        const Radius.circular(
          8,
        ),
      ),
      Paint()
        ..color =
            Colors.white.withValues(
          alpha: 0.18,
        ),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bar.left,
          bar.top,
          bar.width *
              progress
                  .clamp(
                    0.0,
                    1.0,
                  )
                  .toDouble(),
          bar.height,
        ),
        const Radius.circular(
          8,
        ),
      ),
      Paint()
        ..shader =
            const LinearGradient(
          colors: [
            Color(0xFFFFE066),
            Color(0xFFFF73C7),
          ],
        ).createShader(
          bar,
        ),
    );

    // ------------------------------------------------------------
    // RESTART
    // ------------------------------------------------------------

    final Offset restartCenter =
        Offset(
      size.width - 72,
      31,
    );

    canvas.drawCircle(
      restartCenter,
      19,
      Paint()
        ..color =
            Colors.white.withValues(
          alpha: 0.18,
        ),
    );

    _drawRestartIcon(
      canvas,
      restartCenter,
    );

    // ------------------------------------------------------------
    // Pause
    // ------------------------------------------------------------

    final Offset pauseCenter =
        Offset(
      size.width - 27,
      31,
    );

    canvas.drawCircle(
      pauseCenter,
      19,
      Paint()
        ..color =
            Colors.white.withValues(
          alpha: 0.18,
        ),
    );

    _drawCenteredText(
      canvas,
      paused ? '▶' : 'Ⅱ',
      pauseCenter,
      18,
      bold: true,
    );
  }

  // ==============================================================
  // HOME ICON
  // ==============================================================

  void _drawHomeIcon(
    Canvas canvas,
    Offset center,
  ) {
    final Paint paint =
        Paint()
          ..color =
              Colors.white
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap =
              StrokeCap.round
          ..strokeJoin =
              StrokeJoin.round;

    final Path path =
        Path();

    path.moveTo(
      center.dx - 9,
      center.dy,
    );

    path.lineTo(
      center.dx,
      center.dy - 8,
    );

    path.lineTo(
      center.dx + 9,
      center.dy,
    );

    path.lineTo(
      center.dx + 7,
      center.dy,
    );

    path.lineTo(
      center.dx + 7,
      center.dy + 8,
    );

    path.lineTo(
      center.dx - 7,
      center.dy + 8,
    );

    path.lineTo(
      center.dx - 7,
      center.dy,
    );

    canvas.drawPath(
      path,
      paint,
    );
  }

  // ==============================================================
  // RESTART ICON
  // ==============================================================

  void _drawRestartIcon(
    Canvas canvas,
    Offset center,
  ) {
    final Paint paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round;

    const double radius = 8;

    final Rect arcRect =
        Rect.fromCircle(
      center: center,
      radius: radius,
    );

    canvas.drawArc(
      arcRect,
      -0.8,
      4.8,
      false,
      paint,
    );

    final Path arrow = Path();

    arrow.moveTo(
      center.dx + 8,
      center.dy - 8,
    );

    arrow.lineTo(
      center.dx + 8,
      center.dy + 1,
    );

    arrow.lineTo(
      center.dx,
      center.dy - 2,
    );

    canvas.drawPath(
      arrow,
      paint,
    );
  }

  // ==============================================================
  // INFO CARDS
  // ==============================================================

  void _drawInfoCards(
    Canvas canvas,
    Size size,
  ) {
    // Compact information cards leave more room for the actual game board.
    const double top = 70;
    const double cardHeight = 44;

    _drawCard(
      canvas,
      const Rect.fromLTWH(8, top, 102, cardHeight),
      radius: 14,
    );
    _drawText(canvas, 'SCORE', const Offset(20, 78), 8,
        bold: true, color: Colors.white60);
    _drawText(canvas, '$score', const Offset(20, 94), 17, bold: true);

    _drawCard(
      canvas,
      Rect.fromLTWH(size.width / 2 - 51, top, 102, cardHeight),
      radius: 14,
    );
    _drawText(canvas, 'MOVES', Offset(size.width / 2 - 37, 78), 8,
        bold: true, color: Colors.white60);
    _drawText(canvas, '$movesLeft', Offset(size.width / 2 - 37, 94), 17,
        bold: true);

    _drawCard(
      canvas,
      Rect.fromLTWH(size.width - 110, top, 102, cardHeight),
      radius: 14,
    );
    _drawText(canvas, 'TARGET', Offset(size.width - 96, 78), 8,
        bold: true, color: Colors.white60);
    _drawText(canvas, '${1000 * levelNumber}', Offset(size.width - 96, 94), 16,
        bold: true);

    // Small star indicator directly under the moves card.
    for (int i = 0; i < 3; i++) {
      _drawStar(
        canvas,
        Offset(size.width / 2 - 18 + i * 18, 124),
        i < min(stars, 3),
      );
    }
  }

  // ==============================================================
  // STAR
  // ==============================================================

  void _drawStar(
    Canvas canvas,
    Offset center,
    bool filled,
  ) {
    final Path path =
        Path();

    for (int i = 0; i < 10; i++) {
      final double angle =
          -pi / 2 +
              i * pi / 5;

      final double radius =
          i.isEven
              ? 9
              : 4;

      final Offset point =
          Offset(
        center.dx +
            cos(angle) *
                radius,
        center.dy +
            sin(angle) *
                radius,
      );

      if (i == 0) {
        path.moveTo(
          point.dx,
          point.dy,
        );
      } else {
        path.lineTo(
          point.dx,
          point.dy,
        );
      }
    }

    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = filled
            ? const Color(
                0xFFFFD84D,
              )
            : Colors.white.withValues(
                alpha: 0.18,
              ),
    );
  }

  // ==============================================================
  // SHOOTER AREA
  // ==============================================================

  void _drawShooter(
    Canvas canvas,
    Size size,
  ) {
    final double shooterX =
        size.width / 2;

    final double shooterY =
        size.height - 137;

    // ------------------------------------------------------------
    // Bottom panel
    // ------------------------------------------------------------

    final Rect panel =
        Rect.fromLTWH(
      0,
      size.height - 91,
      size.width,
      91,
    );

    canvas.drawRect(
      panel,
      Paint()
        ..shader =
            const LinearGradient(
          begin:
              Alignment.topCenter,
          end:
              Alignment.bottomCenter,
          colors: [
            Color(0xFF19A6D4),
            Color(0xFF087AA9),
          ],
        ).createShader(
          panel,
        ),
    );

    // ------------------------------------------------------------
    // Shooter glow
    // ------------------------------------------------------------

    canvas.drawCircle(
      Offset(
        shooterX,
        shooterY + 20,
      ),
      47,
      Paint()
        ..color =
            Colors.white.withValues(
          alpha: 0.08,
        ),
    );

    // ------------------------------------------------------------
    // Cannon
    // ------------------------------------------------------------

    final Rect cannon =
        Rect.fromCenter(
      center: Offset(
        shooterX,
        shooterY + 25,
      ),
      width: 108,
      height: 40,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cannon,
        const Radius.circular(
          22,
        ),
      ),
      Paint()
        ..shader =
            const LinearGradient(
          colors: [
            Color(0xFF5147FF),
            Color(0xFFB05BFF),
          ],
        ).createShader(
          cannon,
        ),
    );

    // ------------------------------------------------------------
    // Current bubble
    // ------------------------------------------------------------

    if (!flyingBubbleVisible) {
      _drawBubble(
        canvas,
        Offset(
          shooterX,
          shooterY,
        ),
        selectedPower ==
                PowerMode.bomb
            ? BubbleType.bomb
            : selectedPower ==
                    PowerMode.rainbow
                ? BubbleType.rainbow
                : currentBubble,
        25,
      );
    }

    // ------------------------------------------------------------
    // Next bubble
    // ------------------------------------------------------------

    _drawCenteredText(
      canvas,
      'NEXT',
      Offset(
        shooterX + 62,
        shooterY - 1,
      ),
      8,
      bold: true,
      color: Colors.white60,
    );

    _drawBubble(
      canvas,
      Offset(
        shooterX + 62,
        shooterY + 20,
      ),
      nextBubble,
      13,
    );

    // ------------------------------------------------------------
    // Moves bubble
    // ------------------------------------------------------------

    _drawCard(
      canvas,
      Rect.fromCenter(
        center: Offset(
          shooterX - 60,
          shooterY + 30,
        ),
        width: 42,
        height: 28,
      ),
      radius: 14,
      opacity: 0.22,
    );

    _drawCenteredText(
      canvas,
      '$movesLeft',
      Offset(
        shooterX - 60,
        shooterY + 30,
      ),
      12,
      bold: true,
    );
  }

  // ==============================================================
  // POWER UP BUTTONS
  // ==============================================================

  void _drawPowerUps(
    Canvas canvas,
    Size size,
  ) {
    final double y =
        size.height - 47;

    final double center =
        size.width / 2;

    _drawPowerButton(
      canvas,
      Offset(
        center - 120,
        y,
      ),
      PowerMode.bomb,
      bombCount,
    );

    _drawPowerButton(
      canvas,
      Offset(
        center - 40,
        y,
      ),
      PowerMode.lightning,
      lightningCount,
    );

    _drawPowerButton(
      canvas,
      Offset(
        center + 40,
        y,
      ),
      PowerMode.rainbow,
      rainbowCount,
    );

    _drawPowerButton(
      canvas,
      Offset(
        center + 120,
        y,
      ),
      PowerMode.rocket,
      rocketCount,
    );
  }

  // ==============================================================
  // POWER BUTTON
  // ==============================================================

  void _drawPowerButton(
    Canvas canvas,
    Offset center,
    PowerMode mode,
    int count,
  ) {
    final bool selected =
        selectedPower == mode;

    canvas.drawCircle(
      center,
      25,
      Paint()
        ..color = selected
            ? Colors.white.withValues(
                alpha: 0.35,
              )
            : Colors.black.withValues(
                alpha: 0.24,
              ),
    );

    canvas.drawCircle(
      center,
      22,
      Paint()
        ..shader =
            RadialGradient(
          colors: [
            mode ==
                    PowerMode.bomb
                ? const Color(
                    0xFF40485A,
                  )
                : mode ==
                        PowerMode.lightning
                    ? const Color(
                        0xFF168CFF,
                      )
                    : mode ==
                            PowerMode.rainbow
                        ? const Color(
                            0xFFFF45C8,
                          )
                        : const Color(
                            0xFFFF4B45,
                          ),
            Colors.black
                .withValues(
              alpha: 0.35,
            ),
          ],
        ).createShader(
          Rect.fromCircle(
            center: center,
            radius: 22,
          ),
        ),
    );

    if (mode ==
        PowerMode.bomb) {
      _drawBombIcon(
        canvas,
        center,
      );
    } else if (mode ==
        PowerMode.lightning) {
      _drawLightningIcon(
        canvas,
        center,
      );
    } else if (mode ==
        PowerMode.rainbow) {
      _drawRainbowIcon(
        canvas,
        center,
      );
    } else {
      _drawRocketIcon(
        canvas,
        center,
      );
    }

    // Count bubble

    canvas.drawCircle(
      Offset(
        center.dx + 17,
        center.dy + 16,
      ),
      9,
      Paint()
        ..color =
            const Color(
          0xFF07567B,
        ),
    );

    _drawCenteredText(
      canvas,
      '$count',
      Offset(
        center.dx + 17,
        center.dy + 16,
      ),
      8,
      bold: true,
    );
  }

  // ==============================================================
  // BOMB ICON
  // ==============================================================

  void _drawBombIcon(
    Canvas canvas,
    Offset center,
  ) {
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color =
            const Color(
          0xFF1C2230,
        ),
    );

    final Paint fuse =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 2
          ..color =
              const Color(
            0xFFFFD34A,
          );

    final Path path =
        Path();

    path.moveTo(
      center.dx + 3,
      center.dy - 8,
    );

    path.quadraticBezierTo(
      center.dx + 12,
      center.dy - 14,
      center.dx + 8,
      center.dy - 18,
    );

    canvas.drawPath(
      path,
      fuse,
    );
  }

  // ==============================================================
  // LIGHTNING ICON
  // ==============================================================

  void _drawLightningIcon(
    Canvas canvas,
    Offset center,
  ) {
    final Path path =
        Path();

    path.moveTo(
      center.dx + 2,
      center.dy - 12,
    );

    path.lineTo(
      center.dx - 7,
      center.dy + 1,
    );

    path.lineTo(
      center.dx - 1,
      center.dy + 1,
    );

    path.lineTo(
      center.dx - 4,
      center.dy + 12,
    );

    path.lineTo(
      center.dx + 8,
      center.dy - 4,
    );

    path.lineTo(
      center.dx + 2,
      center.dy - 4,
    );

    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color =
            const Color(
          0xFFBDF5FF,
        ),
    );
  }

  // ==============================================================
  // RAINBOW ICON
  // ==============================================================

  void _drawRainbowIcon(
    Canvas canvas,
    Offset center,
  ) {
    final Paint paint =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 3;

    const List<Color>
        colors = [
      Color(0xFFFF3B5C),
      Color(0xFFFFC928),
      Color(0xFF20D68B),
      Color(0xFF2684FF),
      Color(0xFFB84DFF),
    ];

    for (int i = 0;
        i < colors.length;
        i++) {
      paint.color =
          colors[i];

      canvas.drawArc(
        Rect.fromCenter(
          center: center,
          width:
              18 - i * 2.2,
          height:
              18 - i * 2.2,
        ),
        pi,
        pi,
        false,
        paint,
      );
    }
  }

  // ==============================================================
  // ROCKET ICON
  // ==============================================================

  void _drawRocketIcon(
    Canvas canvas,
    Offset center,
  ) {
    final Path rocket =
        Path();

    rocket.moveTo(
      center.dx,
      center.dy - 12,
    );

    rocket.quadraticBezierTo(
      center.dx + 9,
      center.dy - 5,
      center.dx + 5,
      center.dy + 7,
    );

    rocket.lineTo(
      center.dx,
      center.dy + 12,
    );

    rocket.lineTo(
      center.dx - 5,
      center.dy + 7,
    );

    rocket.quadraticBezierTo(
      center.dx - 9,
      center.dy - 5,
      center.dx,
      center.dy - 12,
    );

    rocket.close();

    canvas.drawPath(
      rocket,
      Paint()
        ..color =
            const Color(
          0xFFFFE6E6,
        ),
    );

    canvas.drawCircle(
      Offset(
        center.dx,
        center.dy - 3,
      ),
      2.5,
      Paint()
        ..color =
            const Color(
          0xFF4A75FF,
        ),
    );

    canvas.drawLine(
      Offset(
        center.dx - 3,
        center.dy + 10,
      ),
      Offset(
        center.dx - 6,
        center.dy + 15,
      ),
      Paint()
        ..strokeWidth = 2
        ..color =
            const Color(
          0xFFFFC52F,
        ),
    );

    canvas.drawLine(
      Offset(
        center.dx + 3,
        center.dy + 10,
      ),
      Offset(
        center.dx + 6,
        center.dy + 15,
      ),
      Paint()
        ..strokeWidth = 2
        ..color =
            const Color(
          0xFFFFC52F,
        ),
    );
  }

  // ==============================================================
  // MESSAGE
  // ==============================================================

  void _drawMessage(
    Canvas canvas,
    Size size,
  ) {
    if (message.isEmpty) {
      return;
    }

    final double alpha =
    messageLife
        .clamp(
          0.0,
          1.0,
        )
        .toDouble();

    final Rect rect =
        Rect.fromCenter(
      center: Offset(
        size.width / 2,
        185,
      ),
      width:
          min(
            size.width - 80,
            300,
          ),
      height: 38,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(
          19,
        ),
      ),
      Paint()
        ..color =
            const Color(
          0xFF1A0F49,
        ).withValues(
          alpha:
              0.75 * alpha,
        ),
    );

    _drawCenteredText(
      canvas,
      message,
      rect.center,
      14,
      bold: true,
      color:
          const Color(
        0xFFFFE66D,
      ).withValues(
        alpha: alpha,
      ),
    );
  }

  // ==============================================================
  // PAUSED
  // ==============================================================

  void _drawPaused(
    Canvas canvas,
    Size size,
  ) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color =
            Colors.black.withValues(
          alpha: 0.64,
        ),
    );

    final Rect panel =
        Rect.fromCenter(
      center: Offset(
        size.width / 2,
        size.height / 2,
      ),
      width: 270,
      height: 210,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        panel,
        const Radius.circular(
          30,
        ),
      ),
      Paint()
        ..shader =
            const LinearGradient(
          colors: [
            Color(0xFF37206E),
            Color(0xFF15113D),
          ],
        ).createShader(
          panel,
        ),
    );

    _drawCenteredText(
      canvas,
      'Ⅱ',
      Offset(
        panel.center.dx,
        panel.center.dy - 57,
      ),
      45,
      bold: true,
    );

    _drawCenteredText(
      canvas,
      'GAME PAUSED',
      Offset(
        panel.center.dx,
        panel.center.dy,
      ),
      24,
      bold: true,
    );

    final Rect continueRect = Rect.fromCenter(
      center: Offset(panel.center.dx, panel.center.dy + 55),
      width: 210,
      height: 48,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        continueRect,
        const Radius.circular(24),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFFD75A),
            Color(0xFFFF8A3D),
          ],
        ).createShader(continueRect),
    );

    _drawCenteredText(
      canvas,
      '▶  CONTINUE',
      continueRect.center,
      14,
      bold: true,
      color: const Color(0xFF24123E),
    );
  }

  // ==============================================================
  // PAINT
  // ==============================================================

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    canvas.save();

    if (shake > 0) {
      final double sx =
          sin(animationTime * 12) *
              shake;

      final double sy =
          cos(animationTime * 10) *
              shake;

      canvas.translate(
        sx,
        sy,
      );
    }

    // ============================================================
    // BACKGROUND
    // ============================================================

    final List<Color> bg =
        _backgroundColors();

    final Paint background =
        Paint()
          ..shader =
              const LinearGradient(
            begin:
                Alignment.topCenter,
            end:
                Alignment.bottomCenter,
            colors: [
              Color(0xFF073E5D),
              Color(0xFF11AFA4),
            ],
          ).createShader(
            Offset.zero & size,
          );

    // Use theme colors over the fixed shader for consistency.
    background.shader =
        LinearGradient(
      begin:
          Alignment.topCenter,
      end:
          Alignment.bottomCenter,
      colors: bg,
    ).createShader(
      Offset.zero & size,
    );

    canvas.drawRect(
      Offset.zero & size,
      background,
    );

    // ============================================================
    // BACKGROUND LIGHT
    // ============================================================

    canvas.drawCircle(
      Offset(
        size.width * 0.50,
        size.height * 0.48,
      ),
      size.width * 0.62,
      Paint()
        ..shader =
            RadialGradient(
          colors: [
            Colors.white.withValues(
              alpha: 0.13,
            ),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(
              size.width * 0.50,
              size.height * 0.48,
            ),
            radius:
                size.width * 0.62,
          ),
        ),
    );

    // ============================================================
    // DECORATIVE BUBBLES / STARS
    // ============================================================

    for (int i = 0;
        i < 24;
        i++) {
      final double px =
          (i * 67.0 +
                  sin(
                        animationTime +
                            i,
                      ) *
                      15) %
              size.width;

      final double py =
          82 +
              ((i * 61.0) %
                  max(
                    100,
                    size.height - 200,
                  ));

      canvas.drawCircle(
        Offset(
          px,
          py,
        ),
        1.8,
        Paint()
          ..color =
              Colors.white.withValues(
            alpha: 0.12,
          ),
      );
    }

    // ============================================================
    // HUD
    // ============================================================

    _drawTopHud(
      canvas,
      size,
    );

    _drawInfoCards(
      canvas,
      size,
    );

    // ============================================================
    // BOARD LIMIT LINE
    // ============================================================

    final double dangerY =
        size.height - 185;

    final Paint danger =
        Paint()
          ..color =
              const Color(
            0xFFFF4D6D,
          ).withValues(
            alpha: 0.12,
          )
          ..strokeWidth = 2;

    canvas.drawLine(
      Offset(
        8,
        dangerY,
      ),
      Offset(
        size.width - 8,
        dangerY,
      ),
      danger,
    );

    // ============================================================
    // AIM
    // ============================================================

    if (!paused &&
        !gameFinished &&
        !flyingBubbleVisible) {
      _drawAimLine(
        canvas,
        size,
      );
    }

    // ============================================================
    // BUBBLES
    // ============================================================

    final double radius =
        min(
      23.0,
      max(
        7.5,
        (size.width - 16) / (24 * 2 + 1),
      ),
    );

    for (final GameBubble bubble
        in bubbles) {
      _drawBubble(
        canvas,
        Offset(
          bubble.x,
          bubble.y,
        ),
        bubble.type,
        radius,
        scale:
            bubble.scale,
        opacity:
            bubble.opacity,
        rotation:
            bubble.rotation,
      );
    }

    // ============================================================
    // FLYING BUBBLE
    // ============================================================

    if (flyingBubbleVisible) {
      _drawBubble(
        canvas,
        Offset(
          flyingX,
          flyingY,
        ),
        flyingType,
        18.5,
      );
    }

    // ============================================================
    // PARTICLES
    // ============================================================

    _drawParticles(
      canvas,
    );

    _drawScorePopups(
      canvas,
    );

    // ============================================================
    // MESSAGE
    // ============================================================

    _drawMessage(
      canvas,
      size,
    );

    // ============================================================
    // SHOOTER
    // ============================================================

    _drawShooter(
      canvas,
      size,
    );

    // ============================================================
    // POWER UPS
    // ============================================================

    _drawPowerUps(
      canvas,
      size,
    );

    // ============================================================
    // PAUSE
    // ============================================================

    if (paused) {
      _drawPaused(
        canvas,
        size,
      );
    }

    canvas.restore();
  }
  @override
  bool shouldRepaint(
    covariant BubbleGamePainter
        oldDelegate,
  ) {
    return true;
  }
}