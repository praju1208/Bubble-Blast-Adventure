import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'game_screen.dart';
import 'help_screen.dart';
import 'leaderboard_screen.dart';
import 'level_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? playerId;
  final String? playerName;
  final String? playerEmail;
  final int? currentLevel;
  final int? currentScore;
  final int? highestScore;
  final int? totalStars;

  const HomeScreen({
    super.key,
    this.playerId,
    this.playerName,
    this.playerEmail,
    this.currentLevel,
    this.currentScore,
    this.highestScore,
    this.totalStars,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String baseUrl = 'http://localhost:5000';

  bool _loading = true;

  String _playerId = '';
  String _name = 'Player';
  String _email = '';

  int _avatarIndex = 0;

  int _currentLevel = 1;
  int _currentScore = 0;
  int _highestScore = 0;
  int _totalStars = 0;
  int _gamesWon = 0;

  final List<String> _avatars = [
    '🧑‍🚀',
    '👩‍🚀',
    '🧙‍♂️',
    '🧙‍♀️',
    '🦸‍♂️',
    '🦸‍♀️',
    '🧛‍♂️',
    '🧛‍♀️',
    '🥷',
    '👨‍🎨',
    '👩‍🎨',
    '🤖',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlayer();
  }

  // ============================================================
  // PLAYER LOADING
  // ============================================================

  Future<void> _loadPlayer() async {
    final prefs = await SharedPreferences.getInstance();

    String? storedId = prefs.getString('playerId');

    if ((storedId == null || storedId.isEmpty) &&
        widget.playerId != null &&
        widget.playerId!.isNotEmpty) {
      await _saveInitialPlayerData();
      storedId = widget.playerId;
    }

    if (storedId == null || storedId.isEmpty) {
      await _loadLocalData();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/players/$storedId'),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['player'] != null) {
          await _setPlayerData(
            Map<String, dynamic>.from(
              data['player'],
            ),
          );
        } else {
          await _loadLocalData();
        }
      } else {
        await _loadLocalData();
      }
    } catch (e) {
      debugPrint('Player loading error: $e');
      await _loadLocalData();
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  // ============================================================
  // SAVE INITIAL PLAYER DATA
  // ============================================================

  Future<void> _saveInitialPlayerData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'playerId',
      widget.playerId ?? '',
    );

    await prefs.setString(
      'playerName',
      widget.playerName ?? 'Player',
    );

    await prefs.setString(
      'playerEmail',
      widget.playerEmail ?? '',
    );

    await prefs.setInt(
      'currentLevel',
      widget.currentLevel ?? 1,
    );

    await prefs.setInt(
      'currentScore',
      widget.currentScore ?? 0,
    );

    await prefs.setInt(
      'highestScore',
      widget.highestScore ?? 0,
    );

    await prefs.setInt(
      'totalStars',
      widget.totalStars ?? 0,
    );

    await prefs.setInt(
      'gamesWon',
      0,
    );

    await prefs.setString(
      'completedLevelStars',
      jsonEncode(<String, int>{}),
    );

    await prefs.setInt(
      'avatarIndex',
      0,
    );
  }

  // ============================================================
  // COMPLETED LEVEL PROGRESS
  // ============================================================

  Future<Map<int, int>> _readCompletedLevelStars() async {
    final prefs = await SharedPreferences.getInstance();

    final String? raw = prefs.getString(
      'completedLevelStars',
    );

    final Map<int, int> result = <int, int>{};

    if (raw == null || raw.isEmpty) {
      return result;
    }

    try {
      final dynamic decoded = jsonDecode(raw);

      if (decoded is Map) {
        decoded.forEach(
          (dynamic key, dynamic value) {
            final int? level = int.tryParse(
              key.toString(),
            );

            if (level != null && value is num) {
              result[level] = value.toInt().clamp(1, 3);
            }
          },
        );
      }
    } catch (_) {
      // Ignore invalid old progress data.
    }

    return result;
  }

  int _starsFromCompletedLevels(
    Map<int, int> levels,
  ) {
    return levels.values.fold(
      0,
      (sum, value) => sum + value,
    );
  }

  // ============================================================
  // LOAD LOCAL DATA
  // ============================================================

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    final Map<int, int> completedLevels =
        await _readCompletedLevelStars();

    final int localLevel =
        prefs.getInt('currentLevel') ??
            widget.currentLevel ??
            1;

    final int localStars = completedLevels.isNotEmpty
        ? _starsFromCompletedLevels(
            completedLevels,
          )
        : min(
            prefs.getInt('totalStars') ??
                widget.totalStars ??
                0,
            max(
              0,
              localLevel - 1,
            ) *
                3,
          );

    final int localWins = completedLevels.isNotEmpty
        ? completedLevels.length
        : min(
            prefs.getInt('gamesWon') ?? 0,
            max(
              0,
              localLevel - 1,
            ),
          );

    if (!mounted) return;

    setState(() {
      _playerId =
          prefs.getString('playerId') ??
              widget.playerId ??
              '';

      _name =
          prefs.getString('playerName') ??
              widget.playerName ??
              'Player';

      _email =
          prefs.getString('playerEmail') ??
              widget.playerEmail ??
              '';

      _avatarIndex =
          prefs.getInt('avatarIndex') ?? 0;

      _currentLevel =
          prefs.getInt('currentLevel') ??
              widget.currentLevel ??
              1;

      _currentScore =
          prefs.getInt('currentScore') ??
              widget.currentScore ??
              0;

      _highestScore =
          prefs.getInt('highestScore') ??
              widget.highestScore ??
              0;

      _totalStars = localStars;

      _gamesWon = localWins;
    });
  }

  // ============================================================
  // SET PLAYER DATA FROM SERVER
  // ============================================================

  Future<void> _setPlayerData(
    Map<String, dynamic> player,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final id =
        player['id']?.toString() ??
            player['_id']?.toString() ??
            '';

    final name =
        player['name']?.toString() ??
            'Player';

    final email =
        player['email']?.toString() ??
            '';

    final avatar = _readInt(
      player['avatarIndex'],
      0,
    );

    final level = _readInt(
      player['currentLevel'],
      1,
    );

    final score = _readInt(
      player['currentScore'],
      0,
    );

    final highest = _readInt(
      player['highestScore'],
      0,
    );

    final stars = _readInt(
      player['totalStars'],
      0,
    );

    final won = _readInt(
      player['gamesWon'],
      0,
    );

    final Map<int, int> completedLevels =
        await _readCompletedLevelStars();

    final int normalizedStars =
        completedLevels.isNotEmpty
            ? _starsFromCompletedLevels(
                completedLevels,
              )
            : min(
                stars,
                max(
                  0,
                  level - 1,
                ) *
                    3,
              );

    final int normalizedWins =
        completedLevels.isNotEmpty
            ? completedLevels.length
            : min(
                won,
                max(
                  0,
                  level - 1,
                ),
              );

    await prefs.setString(
      'playerId',
      id,
    );

    await prefs.setString(
      'playerName',
      name,
    );

    await prefs.setString(
      'playerEmail',
      email,
    );

    await prefs.setInt(
      'playerAge',
      _readInt(
        player['age'],
        0,
      ),
    );

    await prefs.setInt(
      'avatarIndex',
      avatar,
    );

    await prefs.setInt(
      'currentLevel',
      level,
    );

    await prefs.setInt(
      'currentScore',
      score,
    );

    await prefs.setInt(
      'highestScore',
      highest,
    );

    await prefs.setInt(
      'totalStars',
      normalizedStars,
    );

    await prefs.setInt(
      'gamesWon',
      normalizedWins,
    );

    if (!mounted) return;

    setState(() {
      _playerId = id;
      _name = name;
      _email = email;

      _avatarIndex = avatar;

      _currentLevel = level;
      _currentScore = score;
      _highestScore = highest;
      _totalStars = normalizedStars;
      _gamesWon = normalizedWins;
    });
  }

  // ============================================================
  // INTEGER HELPER
  // ============================================================

  int _readInt(
    dynamic value,
    int fallback,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  // ============================================================
  // REFRESH PLAYER
  // ============================================================

  Future<void> _refresh() async {
    if (_playerId.isEmpty) {
      await _loadLocalData();
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/api/players/$_playerId',
            ),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(
          response.body,
        );

        if (data['success'] == true &&
            data['player'] != null) {
          await _setPlayerData(
            Map<String, dynamic>.from(
              data['player'],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
      await _loadLocalData();
    }
  }

  // ============================================================
  // OPEN GAME
  // ============================================================

  void _openGame() {
    if (_playerId.isEmpty) {
      _showMessage(
        'Please login first.',
        true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          playerId: _playerId,
          playerName: _name,
          levelNumber: _currentLevel,
        ),
      ),
    ).then((_) {
      _refresh();
    });
  }

  // ============================================================
  // OPEN LEVELS
  // ============================================================

  void _openLevels() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LevelScreen(
          playerId: _playerId,
          playerName: _name,
          currentLevel: _currentLevel,
        ),
      ),
    ).then((_) {
      _refresh();
    });
  }

  // ============================================================
  // OPEN PROFILE
  // ============================================================

  void _openProfile() {
    if (_playerId.isEmpty) {
      _showMessage(
        'Profile not found. Please login again.',
        true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          playerId: _playerId,
          viewOnly: true,
        ),
      ),
    ).then((_) {
      _refresh();
    });
  }

  // ============================================================
  // OPEN LEADERBOARD
  // ============================================================

  void _openLeaderboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LeaderboardScreen(),
      ),
    );
  }

  // ============================================================
  // OPEN HELP
  // ============================================================

  void _openHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const HelpScreen(),
      ),
    );
  }

  // ============================================================
  // LOG OUT
  // ============================================================

  Future<void> _logout() async {
    final prefs =
        await SharedPreferences.getInstance();

    // Remove player login information.
    await prefs.remove('playerId');
    await prefs.remove('playerName');
    await prefs.remove('playerEmail');
    await prefs.remove('playerAge');
    await prefs.remove('avatarIndex');
    await prefs.remove('currentLevel');
    await prefs.remove('currentScore');
    await prefs.remove('highestScore');
    await prefs.remove('totalStars');
    await prefs.remove('gamesWon');
    await prefs.remove('completedLevelStars');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // DRAWER
  // ============================================================

  Widget _buildDrawer() {
    final safeAvatar =
        (_avatarIndex >= 0 &&
                _avatarIndex <
                    _avatars.length)
            ? _avatars[_avatarIndex]
            : _avatars[0];

    return Drawer(
      width: 315,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF160B46),
              Color(0xFF352080),
              Color(0xFF7026A8),
              Color(0xFFB52C91),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ------------------------------------------------
              // DRAWER HEADER
              // ------------------------------------------------

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  22,
                  15,
                  18,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.white54,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(
                              alpha: .20,
                            ),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          safeAvatar,
                          style:
                              const TextStyle(
                            fontSize: 37,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 13,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BUBBLE BLAST',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            _name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            'Level $_currentLevel • $_currentScore pts',
                            style:
                                const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                height: 1,
                margin:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                color: Colors.white24,
              ),

              const SizedBox(
                height: 10,
              ),

              // ------------------------------------------------
              // DRAWER ITEMS
              // ------------------------------------------------

              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  children: [
                    // HOME
                    _drawerItem(
                      Icons.home_rounded,
                      'Home',
                      true,
                      () {
                        Navigator.pop(
                          context,
                        );
                      },
                    ),

                    // PLAY GAME
                    _drawerItem(
                      Icons
                          .play_circle_fill_rounded,
                      'Play Game',
                      false,
                      () {
                        Navigator.pop(
                          context,
                        );
                        _openGame();
                      },
                    ),

                    // LEVELS
                    _drawerItem(
                      Icons.grid_view_rounded,
                      'Levels',
                      false,
                      () {
                        Navigator.pop(
                          context,
                        );
                        _openLevels();
                      },
                    ),

                    // MY PROFILE
                    _drawerItem(
                      Icons.person_rounded,
                      'My Profile',
                      false,
                      () {
                        Navigator.pop(
                          context,
                        );
                        _openProfile();
                      },
                    ),

                    // LEADERBOARD
                    _drawerItem(
                      Icons
                          .emoji_events_rounded,
                      'Leaderboard',
                      false,
                      () {
                        Navigator.pop(
                          context,
                        );
                        _openLeaderboard();
                      },
                    ),

                    // HOW TO PLAY
                    _drawerItem(
                      Icons.help_rounded,
                      'How To Play',
                      false,
                      () {
                        Navigator.pop(
                          context,
                        );
                        _openHelp();
                      },
                    ),

                    // DIVIDER
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      child: Divider(
                        color: Colors.white24,
                      ),
                    ),

                    // LOG OUT
                    _drawerItem(
                      Icons.logout_rounded,
                      'Log Out',
                      false,
                      () {
                        Navigator.pop(
                          context,
                        );
                        _logout();
                      },
                    ),
                  ],
                ),
              ),

              // ------------------------------------------------
              // DRAWER FOOTER
              // ------------------------------------------------

              Padding(
                padding:
                    const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text(
                      '🫧  Keep Popping!  🫧',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      'Best Score: $_highestScore',
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DRAWER ITEM
  // ============================================================

  Widget _drawerItem(
    IconData icon,
    String title,
    bool selected,
    VoidCallback onTap,
  ) {
    return Container(
      margin:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(
                alpha: .20,
              )
            : Colors.transparent,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
        leading: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: selected
                  ? .22
                  : .10,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: selected
                ? FontWeight.w900
                : FontWeight.w600,
          ),
        ),
        trailing: selected
            ? const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 14,
              )
            : null,
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
    bool error,
  ) {
    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? Colors.red.shade700
              : Colors.green.shade700,
          behavior:
              SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Scaffold(
        backgroundColor:
            Color(0xFF130D3B),
        body: Center(
          child:
              CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return Scaffold(
      drawer: _buildDrawer(),

      backgroundColor:
          const Color(0xFFEEF2FF),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.transparent,
        foregroundColor: Colors.white,

        leading: Builder(
          builder: (context) {
            return IconButton(
              tooltip: 'Game Menu',
              icon: const Icon(
                Icons.menu_rounded,
                size: 31,
              ),
              onPressed: () {
                Scaffold.of(
                  context,
                ).openDrawer();
              },
            );
          },
        ),

        flexibleSpace: Container(
          decoration:
              const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF25115F),
                Color(0xFF57239A),
                Color(0xFF9A318D),
              ],
            ),
          ),
        ),

        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'BUBBLE BLAST',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            Text(
              'ADVENTURE',
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
                letterSpacing: 2,
                color:
                    Colors.white70,
              ),
            ),
          ],
        ),

        actions: [
          // SCORE
          Container(
            margin:
                const EdgeInsets.only(
              right: 5,
              top: 9,
              bottom: 9,
            ),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
            ),
            decoration:
                BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: .12,
              ),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 19,
                ),
                const SizedBox(
                  width: 3,
                ),
                Text(
                  '$_totalStars',
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,
            icon: const Icon(
              Icons.person_rounded,
            ),
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: RefreshIndicator(
        color:
            const Color(0xFF6A35C5),
        onRefresh: _refresh,
        child:
            SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHero(),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  20,
                  18,
                  35,
                ),
                child: Column(
                  children: [
                    _buildProgressCard(),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildContinueButton(),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildGameStats(),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildQuickInfo(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHero() {
    final safeAvatar =
        (_avatarIndex >= 0 &&
                _avatarIndex <
                    _avatars.length)
            ? _avatars[_avatarIndex]
            : _avatars[0];

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        20,
        28,
        20,
        30,
      ),
      decoration:
          const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF25115F),
            Color(0xFF4C2092),
            Color(0xFF8C318F),
          ],
        ),
        borderRadius:
            BorderRadius.only(
          bottomLeft:
              Radius.circular(40),
          bottomRight:
              Radius.circular(40),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: 10,
            child: _bubbleDecoration(
              80,
              Colors.white.withValues(
                alpha: .08,
              ),
            ),
          ),

          Positioned(
            bottom: 10,
            left: -20,
            child: _bubbleDecoration(
              70,
              Colors.white.withValues(
                alpha: .06,
              ),
            ),
          ),

          Positioned(
            top: 100,
            left: 20,
            child: _bubbleDecoration(
              30,
              Colors.white.withValues(
                alpha: .08,
              ),
            ),
          ),

          Column(
            children: [
              // BUBBLES
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  _smallBubble('🔵'),
                  const SizedBox(
                    width: 8,
                  ),
                  _smallBubble('🟣'),
                  const SizedBox(
                    width: 8,
                  ),
                  _smallBubble('🟢'),
                  const SizedBox(
                    width: 8,
                  ),
                  _smallBubble('🟡'),
                  const SizedBox(
                    width: 8,
                  ),
                  _smallBubble('🔴'),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              // AVATAR
              Container(
                width: 112,
                height: 112,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.white70,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(
                        alpha: .22,
                      ),
                      blurRadius: 20,
                      offset:
                          const Offset(
                        0,
                        8,
                      ),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    safeAvatar,
                    style:
                        const TextStyle(
                      fontSize: 60,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              Text(
                'Welcome, $_name!',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                _email.isEmpty
                    ? 'Ready for your next adventure?'
                    : _email,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // MISSION
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white.withValues(
                    alpha: .13,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                  border: Border.all(
                    color: Colors.white24,
                  ),
                ),
                child: Text(
                  '🎯  Current Mission  •  Level $_currentLevel',
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DECORATIVE BUBBLE
  // ============================================================

  Widget _bubbleDecoration(
    double size,
    Color color,
  ) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  // ============================================================
  // SMALL BUBBLE
  // ============================================================

  Widget _smallBubble(
    String emoji,
  ) {
    return Container(
      width: 35,
      height: 35,
      decoration:
          BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: .12,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          emoji,
          style:
              const TextStyle(
            fontSize: 21,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROGRESS CARD
  // ============================================================

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF46327E)
                    .withValues(
              alpha: .12,
            ),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .auto_awesome_rounded,
                color:
                    Color(0xFF7B42D4),
              ),
              SizedBox(
                width: 8,
              ),
              Text(
                'YOUR PROGRESS',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Row(
            children: [
              Expanded(
                child: _progressItem(
                  Icons.flag_rounded,
                  '$_currentLevel',
                  'Level',
                ),
              ),
              Expanded(
                child: _progressItem(
                  Icons.star_rounded,
                  '$_totalStars',
                  'Stars',
                ),
              ),
              Expanded(
                child: _progressItem(
                  Icons
                      .bubble_chart_rounded,
                  '$_currentScore',
                  'Score',
                ),
              ),
              Expanded(
                child: _progressItem(
                  Icons
                      .emoji_events_rounded,
                  '$_highestScore',
                  'Best',
                ),
              ),
              Expanded(
                child: _progressItem(
                  Icons
                      .celebration_rounded,
                  '$_gamesWon',
                  'Won',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS ITEM
  // ============================================================

  Widget _progressItem(
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration:
              const BoxDecoration(
            color: Color(0xFFF0E9FF),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color:
                const Color(0xFF7138C5),
            size: 23,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),

        Text(
          label,
          style: TextStyle(
            color:
                Colors.grey.shade500,
            fontSize: 10,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CONTINUE BUTTON
  // ============================================================

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 66,
      child: DecoratedBox(
        decoration:
            BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              Color(0xFF6736C5),
              Color(0xFF8D43C9),
              Color(0xFFE04B9D),
            ],
          ),
          borderRadius:
              BorderRadius.circular(33),
          boxShadow: [
            BoxShadow(
              color:
                  const Color(0xFF7439C7)
                      .withValues(
                alpha: .30,
              ),
              blurRadius: 15,
              offset:
                  const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _openGame,
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                Colors.transparent,
            foregroundColor:
                Colors.white,
            shadowColor:
                Colors.transparent,
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                33,
              ),
            ),
          ),
          icon: const Icon(
            Icons.play_arrow_rounded,
            size: 34,
          ),
          label: Text(
            'CONTINUE LEVEL $_currentLevel',
            style:
                const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GAME STATISTICS
  // ============================================================

  Widget _buildGameStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            Icons.score_rounded,
            '$_currentScore',
            'Current Score',
            const [
              Color(0xFF4B7BEC),
              Color(0xFF6C5CE7),
            ],
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: _statCard(
            Icons.emoji_events_rounded,
            '$_highestScore',
            'Best Score',
            const [
              Color(0xFFFF8A00),
              Color(0xFFFFC107),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard(
    IconData icon,
    String value,
    String title,
    List<Color> colors,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                colors.last.withValues(
              alpha: .22,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: .20,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 23,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    value,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK INFO
  // ============================================================

  Widget _buildQuickInfo() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFFEDE7FF),
            Color(0xFFFDE8F6),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              const Color(0xFFE0D2F7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration:
                const BoxDecoration(
              gradient:
                  LinearGradient(
                colors: [
                  Color(0xFF6A35C5),
                  Color(0xFFE04B9D),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '🫧',
                style:
                    TextStyle(
                  fontSize: 28,
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to blast bubbles?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                SizedBox(
                  height: 4,
                ),

                Text(
                  'Open ☰ to access Levels, Profile, Leaderboard and more.',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}