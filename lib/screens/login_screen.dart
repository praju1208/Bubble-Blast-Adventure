import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ============================================================
  // SERVER
  // ============================================================

  static const String baseUrl = 'http://localhost:5000';

  // ============================================================
  // FORM
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool loading = false;

  bool loadingPlayers = true;

  bool obscure = true;

  String? selectedPlayerId;

  String playerLoadMessage = '';

  // ============================================================
  // EXISTING PLAYERS
  // ============================================================

  List<Map<String, dynamic>> players = [];

  // ============================================================
  // AVATARS
  // ============================================================

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

  // ============================================================
  // COLORS
  // ============================================================

  final List<List<Color>> playerGradients = [
    [
      const Color(0xFF6A3DB8),
      const Color(0xFF9A5BC7),
    ],
    [
      const Color(0xFFFF5F9E),
      const Color(0xFFFF91BE),
    ],
    [
      const Color(0xFF42A5F5),
      const Color(0xFF64B5F6),
    ],
    [
      const Color(0xFFFFA726),
      const Color(0xFFFFC107),
    ],
    [
      const Color(0xFF26A69A),
      const Color(0xFF4DB6AC),
    ],
    [
      const Color(0xFFEF5350),
      const Color(0xFFFF7676),
    ],
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadPlayers();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD EXISTING PLAYERS
  // ============================================================

  Future<void> _loadPlayers() async {
    if (mounted) {
      setState(() {
        loadingPlayers = true;
        playerLoadMessage = '';
      });
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/players'),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      debugPrint(
        'GET /api/players => ${response.statusCode}',
      );

      debugPrint(
        'Players response => ${response.body}',
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> list = [];

        // --------------------------------------------------------
        // Supports:
        //
        // {
        //   "success": true,
        //   "players": [...]
        // }
        //
        // OR
        //
        // [...]
        // --------------------------------------------------------

        if (decoded is Map<String, dynamic>) {
          if (decoded['players'] is List) {
            list = decoded['players'];
          } else if (decoded['data'] is List) {
            list = decoded['data'];
          }
        } else if (decoded is List) {
          list = decoded;
        }

        final loadedPlayers = <Map<String, dynamic>>[];

        for (final item in list) {
          if (item is Map) {
            loadedPlayers.add(
              Map<String, dynamic>.from(item),
            );
          }
        }

        if (!mounted) return;

        setState(() {
          players = loadedPlayers;
          loadingPlayers = false;

          if (players.isEmpty) {
            playerLoadMessage =
                'No players found. Create your first profile!';
          }
        });
      } else {
        if (!mounted) return;

        setState(() {
          loadingPlayers = false;
          playerLoadMessage =
              'Unable to load existing players.';
        });
      }
    } catch (e) {
      debugPrint(
        'Load players error: $e',
      );

      if (!mounted) return;

      setState(() {
        loadingPlayers = false;
        playerLoadMessage =
            'Cannot connect to server.';
      });
    }
  }

  // ============================================================
  // SELECT PLAYER
  // ============================================================

  void _selectPlayer(
    Map<String, dynamic> player,
  ) {
    final email =
        player['email']?.toString() ?? '';

    final id =
        player['id']?.toString() ??
            player['_id']?.toString() ??
            '';

    setState(() {
      selectedPlayerId = id;

      _emailController.text = email;

      _passwordController.clear();
    });

    FocusScope.of(context).unfocus();

    _showMessage(
      'Selected ${player['name']?.toString() ?? 'Player'}',
      false,
    );
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(
              '$baseUrl/api/players/login',
            ),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': _emailController.text
                  .trim()
                  .toLowerCase(),
              'password': _passwordController.text,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      debugPrint(
        'Login response: ${response.statusCode}',
      );

      debugPrint(
        'Login body: ${response.body}',
      );

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (decoded is! Map) {
        _showMessage(
          'Invalid response from server.',
          true,
        );
        return;
      }

      final data =
          Map<String, dynamic>.from(decoded);

      if (response.statusCode == 200 &&
          data['success'] == true &&
          data['player'] != null) {
        final player =
            Map<String, dynamic>.from(
          data['player'],
        );

        await _saveLoggedInPlayer(player);

        if (!mounted) return;

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

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              playerId: id,
              playerName: name,
              playerEmail: email,
              currentLevel: level,
              currentScore: score,
              highestScore: highest,
              totalStars: stars,
            ),
          ),
          (route) => false,
        );

        return;
      }

      _showMessage(
        data['message']?.toString() ??
            'Invalid email or password.',
        true,
      );
    } catch (e) {
      debugPrint(
        'Login error: $e',
      );

      _showMessage(
        'Cannot connect to server.\n'
        'Make sure server.js is running.',
        true,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE LOGGED-IN PLAYER
  // ============================================================

  Future<void> _saveLoggedInPlayer(
    Map<String, dynamic> player,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

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

    final age = _readInt(
      player['age'],
      0,
    );

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

    final gamesWon = _readInt(
      player['gamesWon'],
      0,
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
      age,
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
      stars,
    );

    await prefs.setInt(
      'gamesWon',
      gamesWon,
    );
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
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
    bool error,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor:
              error
                  ? Colors.red.shade700
                  : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F1FC),

      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF6A3DB8),
          onRefresh: _loadPlayers,

          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),

            padding:
                const EdgeInsets.fromLTRB(
              22,
              12,
              22,
              30,
            ),

            child: Form(
              key: _formKey,

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,

                children: [
                  // ==================================================
                  // BACK BUTTON
                  // ==================================================

                  Align(
                    alignment:
                        Alignment.centerLeft,

                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },

                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 30,
                        color:
                            Color(0xFF302936),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ==================================================
                  // LOGO / BUBBLES
                  // ==================================================

                  _buildBubbleLogo(),

                  const SizedBox(height: 12),

                  // ==================================================
                  // TITLE
                  // ==================================================

                  const Text(
                    'WELCOME BACK',
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 30,
                      fontWeight:
                          FontWeight.w900,
                      color:
                          Color(0xFF27212C),
                      letterSpacing: .2,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Login to continue your adventure',
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 15,
                      color:
                          Colors.grey.shade600,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ==================================================
                  // EXISTING PLAYERS
                  // ==================================================

                  _buildExistingPlayers(),

                  const SizedBox(height: 22),

                  // ==================================================
                  // DIVIDER
                  // ==================================================

                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey
                              .withValues(
                            alpha: .25,
                          ),
                        ),
                      ),

                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                        ),

                        child: Text(
                          'OR LOGIN MANUALLY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w800,
                            color: Colors
                                .grey
                                .shade500,
                            letterSpacing:
                                .6,
                          ),
                        ),
                      ),

                      Expanded(
                        child: Divider(
                          color: Colors.grey
                              .withValues(
                            alpha: .25,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // EMAIL
                  // ==================================================

                  _buildTextField(
                    controller:
                        _emailController,

                    label: 'Email Address',

                    hint:
                        'Enter your email',

                    icon:
                        Icons.email_rounded,

                    keyboardType:
                        TextInputType
                            .emailAddress,

                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Enter email address';
                      }

                      if (!value
                          .contains('@')) {
                        return 'Enter a valid email';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // PASSWORD
                  // ==================================================

                  _buildTextField(
                    controller:
                        _passwordController,

                    label: 'Password',

                    hint:
                        'Enter your password',

                    icon:
                        Icons.lock_rounded,

                    obscureText: obscure,

                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          obscure =
                              !obscure;
                        });
                      },

                      icon: Icon(
                        obscure
                            ? Icons
                                .visibility_off_rounded
                            : Icons
                                .visibility_rounded,

                        color:
                            const Color(
                          0xFF514A56,
                        ),
                      ),
                    ),

                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Enter password';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // LOGIN BUTTON
                  // ==================================================

                  _buildLoginButton(),

                  const SizedBox(height: 15),

                  // ==================================================
                  // CREATE PROFILE
                  // ==================================================

                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ProfileScreen(),
                              ),
                            );
                          },

                    child: const Text(
                      'NEW PLAYER? CREATE PROFILE',

                      style: TextStyle(
                        color:
                            Color(0xFF70529A),
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  // ==================================================
                  // FOOTER
                  // ==================================================

                  Text(
                    '🫧  Your adventure is waiting!',
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      color:
                          Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUBBLE LOGO
  // ============================================================

  Widget _buildBubbleLogo() {
    return SizedBox(
      height: 105,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 8,

            child: Center(
              child: Container(
                width: 64,
                height: 64,

                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,

                  gradient:
                      const LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      Color(0xFFB7F0FF),
                      Color(0xFF69D6EF),
                    ],
                  ),

                  border: Border.all(
                    color:
                        const Color(
                      0xFF42BDD9,
                    ),
                    width: 3,
                  ),
                ),

                child: const Align(
                  alignment:
                      Alignment(-.35, -.4),

                  child: Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 66,
            top: 37,

            child: _smallBubble(
              31,
            ),
          ),

          Positioned(
            right: 51,
            top: 66,

            child: _smallBubble(
              37,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBubble(
    double size,
  ) {
    return Container(
      width: size,
      height: size,

      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,

        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFFC5F4FF),
            Color(0xFF70D9EF),
          ],
        ),

        border: Border.all(
          color:
              const Color(
            0xFF42BDD9,
          ),
          width: 2,
        ),
      ),

      child: Center(
        child: Container(
          width: size * .18,
          height: size * .18,

          decoration:
              const BoxDecoration(
            color: Colors.white,
            shape:
                BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXISTING PLAYERS
  // ============================================================

  Widget _buildExistingPlayers() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        16,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: .07,
            ),
            blurRadius: 15,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,

                decoration:
                    BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xFF6A3DB8),
                      Color(0xFFFF6FAE),
                    ],
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),

                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'EXISTING PLAYERS',

                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                        color:
                            Color(0xFF29232D),
                      ),
                    ),

                    SizedBox(height: 2),

                    Text(
                      'Choose your profile to continue',

                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF8B828F),
                      ),
                    ),
                  ],
                ),
              ),

              if (!loadingPlayers &&
                  players.isNotEmpty)
                IconButton(
                  tooltip: 'Refresh players',

                  onPressed:
                      _loadPlayers,

                  icon: const Icon(
                    Icons.refresh_rounded,
                    color:
                        Color(0xFF6A3DB8),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          if (loadingPlayers)
            _buildPlayersLoading()

          else if (players.isEmpty)
            _buildNoPlayers()

          else
            _buildPlayerList(),
        ],
      ),
    );
  }

  // ============================================================
  // PLAYER LOADING
  // ============================================================

  Widget _buildPlayersLoading() {
    return Container(
      height: 125,

      alignment:
          Alignment.center,

      child: const Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            color:
                Color(0xFF6A3DB8),
          ),

          SizedBox(height: 10),

          Text(
            'Loading players...',
            style: TextStyle(
              color:
                  Color(0xFF817885),
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NO PLAYERS
  // ============================================================

  Widget _buildNoPlayers() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF8F1FC),

        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          const Text(
            '🫧',
            style:
                TextStyle(
              fontSize: 36,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            playerLoadMessage.isEmpty
                ? 'No existing players'
                : playerLoadMessage,

            textAlign:
                TextAlign.center,

            style: const TextStyle(
              color:
                  Color(0xFF756B79),
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          TextButton(
            onPressed:
                _loadPlayers,

            child: const Text(
              'REFRESH',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PLAYER LIST
  // ============================================================

  Widget _buildPlayerList() {
    return SizedBox(
      height: 155,

      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,

        physics:
            const BouncingScrollPhysics(),

        itemCount:
            players.length,

        separatorBuilder:
            (_, _) =>
                const SizedBox(
          width: 12,
        ),

        itemBuilder:
            (context, index) {
          return _buildPlayerCard(
            players[index],
            index,
          );
        },
      ),
    );
  }

  // ============================================================
  // PLAYER CARD
  // ============================================================

  Widget _buildPlayerCard(
    Map<String, dynamic> player,
    int index,
  ) {
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

    final avatarIndex =
        _readInt(
      player['avatarIndex'],
      index % _avatars.length,
    );

    final safeAvatarIndex =
        avatarIndex >= 0 &&
                avatarIndex <
                    _avatars.length
            ? avatarIndex
            : 0;

    final avatar =
        _avatars[safeAvatarIndex];

    final selected =
        selectedPlayerId == id &&
            id.isNotEmpty;

    final gradient =
        playerGradients[
            index %
                playerGradients.length];

    return GestureDetector(
      onTap: () {
        _selectPlayer(
          player,
        );
      },

      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 220,
        ),

        width: 145,

        padding:
            const EdgeInsets.all(
          12,
        ),

        decoration:
            BoxDecoration(
          gradient:
              LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors:
                gradient,
          ),

          borderRadius:
              BorderRadius.circular(
            20,
          ),

          border:
              selected
                  ? Border.all(
                      color:
                          Colors.white,
                      width: 3,
                    )
                  : null,

          boxShadow: [
            BoxShadow(
              color:
                  gradient.last
                      .withValues(
                alpha:
                    selected
                        ? .38
                        : .20,
              ),
              blurRadius:
                  selected
                      ? 14
                      : 8,
              offset:
                  const Offset(
                0,
                5,
              ),
            ),
          ],
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center,

          children: [
            // Avatar
            Container(
              width: 58,
              height: 58,

              decoration:
                  BoxDecoration(
                color:
                    Colors.white
                        .withValues(
                  alpha: .95,
                ),

                shape:
                    BoxShape.circle,

                border:
                    Border.all(
                  color:
                      Colors.white
                          .withValues(
                    alpha: .8,
                  ),
                  width: 2,
                ),
              ),

              child: Center(
                child: Text(
                  avatar,
                  style:
                      const TextStyle(
                    fontSize: 32,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            // Name
            Text(
              name,

              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 14,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            // Email
            Text(
              email,

              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    Colors.white
                        .withValues(
                  alpha: .85,
                ),
                fontSize: 9,
                fontWeight:
                    FontWeight.w500,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            if (selected)
              const Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,

                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color:
                        Colors.white,
                    size: 14,
                  ),

                  SizedBox(
                    width: 4,
                  ),

                  Text(
                    'SELECTED',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              )
            else
              Text(
                'TAP TO SELECT',

                style:
                    TextStyle(
                  color:
                      Colors.white
                          .withValues(
                    alpha: .82,
                  ),
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,

      keyboardType:
          keyboardType,

      obscureText:
          obscureText,

      validator:
          validator,

      style:
          const TextStyle(
        color:
            Color(0xFF403945),
        fontSize: 15,
        fontWeight:
            FontWeight.w600,
      ),

      decoration:
          InputDecoration(
        labelText:
            label,

        hintText:
            hint,

        labelStyle:
            const TextStyle(
          color:
              Color(0xFF756D78),
        ),

        hintStyle:
            TextStyle(
          color:
              Colors.grey.shade400,
        ),

        prefixIcon:
            Icon(
          icon,
          color:
              const Color(
            0xFF514A56,
          ),
        ),

        suffixIcon:
            suffixIcon,

        filled: true,

        fillColor:
            Colors.white,

        contentPadding:
            const EdgeInsets
                .symmetric(
          horizontal: 18,
          vertical: 17,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          borderSide:
              BorderSide.none,
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          borderSide:
              BorderSide.none,
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(0xFF8A5CC8),
            width: 2,
          ),
        ),

        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          borderSide:
              const BorderSide(
            color:
                Colors.redAccent,
          ),
        ),

        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          borderSide:
              const BorderSide(
            color:
                Colors.redAccent,
            width: 2,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGIN BUTTON
  // ============================================================

  Widget _buildLoginButton() {
    return Container(
      height: 60,

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.centerLeft,
          end:
              Alignment.centerRight,
          colors: [
            Color(0xFF6A3DB8),
            Color(0xFF8B4DC6),
            Color(0xFFB85BAA),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        boxShadow: [
          BoxShadow(
            color:
                const Color(
              0xFF6A3DB8,
            ).withValues(
              alpha: .25,
            ),
            blurRadius: 12,
            offset:
                const Offset(
              0,
              6,
            ),
          ),
        ],
      ),

      child:
          ElevatedButton.icon(
        onPressed:
            loading
                ? null
                : _login,

        icon:
            loading
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color:
                          Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.login_rounded,
                    size: 23,
                  ),

        label:
            Text(
          loading
              ? 'LOGGING IN...'
              : 'LOGIN',

          style:
              const TextStyle(
            fontSize: 15,
            fontWeight:
                FontWeight.w900,
            letterSpacing: .4,
          ),
        ),

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              Colors.transparent,

          foregroundColor:
              Colors.white,

          disabledBackgroundColor:
              Colors.transparent,

          disabledForegroundColor:
              Colors.white
                  .withValues(
            alpha: .7,
          ),

          shadowColor:
              Colors.transparent,

          elevation: 0,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
        ),
      ),
    );
  }
}