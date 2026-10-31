import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? playerId;
  final bool viewOnly;

  const ProfileScreen({
    super.key,
    this.playerId,
    this.viewOnly = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String baseUrl = 'http://localhost:5000';

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();

  // Password controllers
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _editing = false;

  int _selectedAvatar = 0;

  int _currentLevel = 1;
  int _currentScore = 0;
  int _highestScore = 0;
  int _totalStars = 0;
  int _gamesWon = 0;
  int _gamesLost = 0;

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

    _editing =
        widget.playerId != null &&
        widget.playerId!.isNotEmpty;

    if (_editing) {
      _loadPlayer();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD PLAYER
  // ============================================================

  Future<void> _loadPlayer() async {
    final prefs = await SharedPreferences.getInstance();

    final id =
        widget.playerId ??
        prefs.getString('playerId');

    if (id == null || id.isEmpty) {
      await _loadLocalPlayer();
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/api/players/$id',
            ),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true &&
            data['player'] != null) {
          final player =
              Map<String, dynamic>.from(
            data['player'],
          );

          await _applyPlayerData(player);

          return;
        }
      }

      await _loadLocalPlayer();
    } catch (e) {
      debugPrint(
        'Profile loading error: $e',
      );

      await _loadLocalPlayer();
    }
  }

  Future<void> _loadLocalPlayer() async {
    final prefs =
        await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _nameController.text =
          prefs.getString('playerName') ?? '';

      _emailController.text =
          prefs.getString('playerEmail') ?? '';

      _ageController.text =
          (prefs.getInt('playerAge') ?? 0).toString();

      _selectedAvatar =
          prefs.getInt('avatarIndex') ?? 0;

      _currentLevel =
          prefs.getInt('currentLevel') ?? 1;

      _currentScore =
          prefs.getInt('currentScore') ?? 0;

      _highestScore =
          prefs.getInt('highestScore') ?? 0;

      _totalStars =
          prefs.getInt('totalStars') ?? 0;

      _gamesWon =
          prefs.getInt('gamesWon') ?? 0;

      _gamesLost =
          prefs.getInt('gamesLost') ?? 0;
    });
  }

  Future<void> _applyPlayerData(
    Map<String, dynamic> player,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final name =
        player['name']?.toString() ?? '';

    final email =
        player['email']?.toString() ?? '';

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

    final won = _readInt(
      player['gamesWon'],
      0,
    );

    final lost = _readInt(
      player['gamesLost'],
      0,
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
      won,
    );

    await prefs.setInt(
      'gamesLost',
      lost,
    );

    if (!mounted) return;

    setState(() {
      _nameController.text = name;
      _emailController.text = email;

      _ageController.text =
          age == 0 ? '' : age.toString();

      _selectedAvatar = avatar.clamp(
        0,
        _avatars.length - 1,
      );

      _currentLevel = level;
      _currentScore = score;
      _highestScore = highest;
      _totalStars = stars;
      _gamesWon = won;
      _gamesLost = lost;
    });
  }

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
  // CREATE PROFILE
  // ============================================================

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Extra password validation for safety.
    final password =
        _passwordController.text;

    final confirmPassword =
        _confirmController.text;

    if (password.isEmpty) {
      _showMessage(
        'Password is required.',
        true,
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password must be at least 6 characters.',
        true,
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage(
        'Passwords do not match.',
        true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(
              '$baseUrl/api/players/register',
            ),
            headers: const {
              'Content-Type':
                  'application/json',
            },
            body: jsonEncode({
              'name':
                  _nameController.text.trim(),

              'email':
                  _emailController.text
                      .trim()
                      .toLowerCase(),

              'age':
                  int.parse(
                _ageController.text.trim(),
              ),

              'password':
                  _passwordController.text,

              'avatarIndex':
                  _selectedAvatar,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      final data = jsonDecode(
        response.body,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        if (data['player'] == null) {
          _showMessage(
            'Profile created but player data was not returned.',
            true,
          );
          return;
        }

        final player =
            Map<String, dynamic>.from(
          data['player'],
        );

        final id =
            player['id']?.toString() ??
            player['_id']?.toString() ??
            '';

        if (id.isEmpty) {
          _showMessage(
            'Profile created but player ID was not found.',
            true,
          );
          return;
        }

        final prefs =
            await SharedPreferences.getInstance();

        await prefs.setString(
          'playerId',
          id,
        );

        await prefs.setString(
          'playerName',
          player['name']?.toString() ??
              _nameController.text.trim(),
        );

        await prefs.setString(
          'playerEmail',
          player['email']?.toString() ??
              _emailController.text
                  .trim()
                  .toLowerCase(),
        );

        await prefs.setInt(
          'playerAge',
          _readInt(
            player['age'],
            int.parse(
              _ageController.text.trim(),
            ),
          ),
        );

        await prefs.setInt(
          'avatarIndex',
          _readInt(
            player['avatarIndex'],
            _selectedAvatar,
          ),
        );

        await prefs.setInt(
          'currentLevel',
          _readInt(
            player['currentLevel'],
            1,
          ),
        );

        await prefs.setInt(
          'currentScore',
          _readInt(
            player['currentScore'],
            0,
          ),
        );

        await prefs.setInt(
          'highestScore',
          _readInt(
            player['highestScore'],
            0,
          ),
        );

        await prefs.setInt(
          'totalStars',
          _readInt(
            player['totalStars'],
            0,
          ),
        );

        await prefs.setInt(
          'gamesWon',
          _readInt(
            player['gamesWon'],
            0,
          ),
        );

        await prefs.setInt(
          'gamesLost',
          _readInt(
            player['gamesLost'],
            0,
          ),
        );

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              playerId: id,
              playerName:
                  player['name']?.toString() ??
                      _nameController.text.trim(),
              playerEmail:
                  player['email']?.toString() ??
                      _emailController.text
                          .trim()
                          .toLowerCase(),
              currentLevel:
                  _readInt(
                player['currentLevel'],
                1,
              ),
              currentScore:
                  _readInt(
                player['currentScore'],
                0,
              ),
              highestScore:
                  _readInt(
                player['highestScore'],
                0,
              ),
              totalStars:
                  _readInt(
                player['totalStars'],
                0,
              ),
            ),
          ),
          (route) => false,
        );

        return;
      }

      _showMessage(
        data['message']?.toString() ??
            'Unable to create profile.',
        true,
      );
    } catch (e) {
      debugPrint(
        'Create profile error: $e',
      );

      _showMessage(
        'Cannot connect to server.\n'
        'Make sure server.js is running on port 5000.',
        true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // UPDATE PROFILE
  // ============================================================

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    final id =
        widget.playerId ??
        prefs.getString('playerId');

    if (id == null || id.isEmpty) {
      _showMessage(
        'Player ID not found.',
        true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final body =
          <String, dynamic>{
        'name':
            _nameController.text.trim(),

        'email':
            _emailController.text
                .trim()
                .toLowerCase(),

        'age':
            int.parse(
          _ageController.text.trim(),
        ),

        'avatarIndex':
            _selectedAvatar,
      };

      if (_passwordController.text.isNotEmpty) {
        body['password'] =
            _passwordController.text;
      }

      final response = await http
          .put(
            Uri.parse(
              '$baseUrl/api/players/$id',
            ),
            headers: const {
              'Content-Type':
                  'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      final data = jsonDecode(
        response.body,
      );

      if (response.statusCode == 200 &&
          data['player'] != null) {
        final player =
            Map<String, dynamic>.from(
          data['player'],
        );

        await _applyPlayerData(
          player,
        );

        _passwordController.clear();
        _confirmController.clear();

        if (!mounted) return;

        setState(() {
          _editing =
              widget.viewOnly
                  ? false
                  : true;
        });

        _showMessage(
          'Profile updated successfully! 🎉',
          false,
        );

        return;
      }

      _showMessage(
        data['message']?.toString() ??
            'Unable to update profile.',
        true,
      );
    } catch (e) {
      debugPrint(
        'Update profile error: $e',
      );

      _showMessage(
        'Cannot connect to server.',
        true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
    bool error,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              error
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
  Widget build(BuildContext context) {
    final isCreate = !_editing;

    final canEdit =
        !widget.viewOnly || _editing;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F1FC),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF8F1FC),
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            if (widget.viewOnly) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const LoginScreen(),
                ),
              );
            }
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),

        title: Text(
          isCreate
              ? 'CREATE PROFILE'
              : 'MY PROFILE',
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),

        centerTitle: true,

        actions: [
          if (widget.viewOnly &&
              !_editing)
            IconButton(
              tooltip:
                  'Edit Profile',
              onPressed: () {
                setState(() {
                  _editing = true;
                });
              },
              icon: const Icon(
                Icons.edit_rounded,
              ),
            ),
        ],
      ),

      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            5,
            20,
            35,
          ),

          child: Form(
            key: _formKey,

            child: Column(
              children: [
                _avatarPicker(),

                const SizedBox(
                  height: 22,
                ),

                if (_editing)
                  _progressSummary(),

                const SizedBox(
                  height: 20,
                ),

                _field(
                  controller:
                      _nameController,
                  label:
                      'Player Name',
                  icon:
                      Icons.person_rounded,
                  enabled:
                      !_loading &&
                          canEdit,
                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter player name';
                    }

                    if (value
                            .trim()
                            .length <
                        2) {
                      return 'Name must contain at least 2 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 15,
                ),

                _field(
                  controller:
                      _emailController,
                  label:
                      'Email Address',
                  icon:
                      Icons.email_rounded,
                  enabled:
                      !_loading &&
                          canEdit,
                  keyboardType:
                      TextInputType.emailAddress,
                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter email address';
                    }

                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(
                      value.trim(),
                    )) {
                      return 'Enter a valid email address';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 15,
                ),

                _field(
                  controller:
                      _ageController,
                  label: 'Age',
                  icon:
                      Icons.cake_rounded,
                  enabled:
                      !_loading &&
                          canEdit,
                  keyboardType:
                      TextInputType.number,
                  validator:
                      (value) {
                    final age =
                        int.tryParse(
                      value?.trim() ??
                          '',
                    );

                    if (age == null) {
                      return 'Enter valid age';
                    }

                    if (age < 5 ||
                        age > 100) {
                      return 'Age must be between 5 and 100';
                    }

                    return null;
                  },
                ),

                // ==================================================
                // PASSWORD FOR CREATE PROFILE
                // ==================================================

                if (isCreate) ...[
                  const SizedBox(
                    height: 15,
                  ),

                  _field(
                    controller:
                        _passwordController,
                    label:
                        'Password',
                    icon:
                        Icons.lock_rounded,
                    enabled:
                        !_loading,
                    obscureText:
                        true,
                    validator:
                        (value) {
                      if (value ==
                              null ||
                          value
                              .trim()
                              .isEmpty) {
                        return 'Password is required';
                      }

                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  _field(
                    controller:
                        _confirmController,
                    label:
                        'Confirm Password',
                    icon:
                        Icons.lock_outline_rounded,
                    enabled:
                        !_loading,
                    obscureText:
                        true,
                    validator:
                        (value) {
                      if (value ==
                              null ||
                          value
                              .trim()
                              .isEmpty) {
                        return 'Confirm password';
                      }

                      if (value !=
                          _passwordController
                              .text) {
                        return 'Passwords do not match';
                      }

                      return null;
                    },
                  ),
                ],

                // ==================================================
                // PASSWORD FOR EDIT PROFILE
                // ==================================================

                if (_editing &&
                    !widget.viewOnly) ...[
                  const SizedBox(
                    height: 15,
                  ),

                  _field(
                    controller:
                        _passwordController,
                    label:
                        'New Password',
                    icon:
                        Icons.lock_rounded,
                    enabled:
                        !_loading,
                    obscureText:
                        true,
                    validator:
                        (value) {
                      if (value ==
                          null) {
                        return null;
                      }

                      if (value
                              .isNotEmpty &&
                          value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  _field(
                    controller:
                        _confirmController,
                    label:
                        'Confirm New Password',
                    icon:
                        Icons.lock_outline_rounded,
                    enabled:
                        !_loading,
                    obscureText:
                        true,
                    validator:
                        (value) {
                      if (_passwordController
                          .text
                          .isEmpty) {
                        return null;
                      }

                      if (value ==
                              null ||
                          value.isEmpty) {
                        return 'Confirm password';
                      }

                      if (value !=
                          _passwordController
                              .text) {
                        return 'Passwords do not match';
                      }

                      return null;
                    },
                  ),
                ],

                const SizedBox(
                  height: 25,
                ),

                if (canEdit)
                  Container(
                    width:
                        double.infinity,
                    height: 56,

                    decoration:
                        BoxDecoration(
                      gradient:
                          const LinearGradient(
                        colors: [
                          Color(
                              0xFF6A3DB8),
                          Color(
                              0xFF9A5BC7),
                          Color(
                              0xFFDD5FA6),
                        ],
                      ),

                      borderRadius:
                          BorderRadius
                              .circular(
                        28,
                      ),
                    ),

                    child:
                        ElevatedButton
                            .icon(
                      onPressed:
                          _loading
                              ? null
                              : _editing
                                  ? _updateProfile
                                  : _createProfile,

                      icon:
                          _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : Icon(
                                  _editing
                                      ? Icons
                                          .save_rounded
                                      : Icons
                                          .person_add_rounded,
                                ),

                      label: Text(
                        _editing
                            ? 'SAVE CHANGES'
                            : 'CREATE PROFILE',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),

                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            Colors
                                .transparent,
                        foregroundColor:
                            Colors
                                .white,
                        shadowColor:
                            Colors
                                .transparent,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            28,
                          ),
                        ),
                      ),
                    ),
                  ),

                if (isCreate) ...[
                  const SizedBox(
                    height: 15,
                  ),

                  TextButton.icon(
                    onPressed:
                        _loading
                            ? null
                            : () {
                                Navigator
                                    .pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) =>
                                            const LoginScreen(),
                                  ),
                                );
                              },
                    icon: const Icon(
                      Icons
                          .login_rounded,
                    ),
                    label:
                        const Text(
                      'Already have a profile? LOGIN',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _avatarPicker() {
    final safeIndex =
        (_selectedAvatar >= 0 &&
                _selectedAvatar <
                    _avatars.length)
            ? _selectedAvatar
            : 0;

    final canChoose =
        !widget.viewOnly ||
            _editing;

    return Column(
      children: [
        Container(
          width: 135,
          height: 135,

          decoration:
              const BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFFF7043),
                Color(0xFFFF4FA3),
              ],
            ),
          ),

          padding:
              const EdgeInsets.all(5),

          child: Container(
            decoration:
                const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),

            child: Center(
              child: Text(
                _avatars[safeIndex],
                style:
                    const TextStyle(
                  fontSize: 68,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        Text(
          widget.viewOnly
              ? 'YOUR PLAYER'
              : 'Choose your player',
          style:
              const TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        SizedBox(
          height: 70,

          child:
              ListView.separated(
            scrollDirection:
                Axis.horizontal,

            itemCount:
                _avatars.length,

            separatorBuilder:
                (context, index) =>
                    const SizedBox(
              width: 8,
            ),

            itemBuilder:
                (context, index) {
              final selected =
                  index ==
                      _selectedAvatar;

              return GestureDetector(
                onTap:
                    canChoose
                        ? () {
                            setState(() {
                              _selectedAvatar =
                                  index;
                            });
                          }
                        : null,

                child: AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 200,
                  ),

                  width: 64,

                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,

                    gradient: selected
                        ? const LinearGradient(
                            colors: [
                              Color(
                                  0xFFFFD54F),
                              Color(
                                  0xFFFF8A65),
                            ],
                          )
                        : null,

                    color: selected
                        ? null
                        : Colors.white,

                    border:
                        Border.all(
                      color: selected
                          ? const Color(
                              0xFF6A3DB8)
                          : Colors
                              .grey
                              .shade300,
                      width:
                          selected
                              ? 3
                              : 1,
                    ),

                    boxShadow:
                        selected
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(
                                    0xFF6A3DB8,
                                  ).withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius:
                                      7,
                                ),
                              ]
                            : null,
                  ),

                  child: Center(
                    child: Text(
                      _avatars[index],
                      style:
                          const TextStyle(
                        fontSize: 31,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROGRESS SUMMARY
  // ============================================================

  Widget _progressSummary() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(18),

      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFFF0E5FF),
            Color(0xFFFFEDF7),
          ],
        ),

        borderRadius:
            BorderRadius.circular(22),

        border: Border.all(
          color:
              const Color(0xFFE0CFF2),
        ),
      ),

      child: Column(
        children: [
          const Text(
            'GAME STATISTICS',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: .6,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              Expanded(
                child: _stat(
                  Icons.flag_rounded,
                  'LEVEL',
                  '$_currentLevel',
                ),
              ),

              Expanded(
                child: _stat(
                  Icons.stars_rounded,
                  'STARS',
                  '$_totalStars',
                ),
              ),

              Expanded(
                child: _stat(
                  Icons.scoreboard_rounded,
                  'SCORE',
                  '$_currentScore',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              Expanded(
                child: _stat(
                  Icons.emoji_events_rounded,
                  'BEST',
                  '$_highestScore',
                ),
              ),

              Expanded(
                child: _stat(
                  Icons.celebration_rounded,
                  'WON',
                  '$_gamesWon',
                ),
              ),

              Expanded(
                child: _stat(
                  Icons.close_rounded,
                  'LOST',
                  '$_gamesLost',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData icon,
    String title,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 25,
          color:
              const Color(0xFF7040B7),
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          value,
          style:
              const TextStyle(
            fontSize: 21,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        Text(
          title,
          style: TextStyle(
            color:
                Colors.grey.shade600,
            fontSize: 10,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FORM FIELD
  // ============================================================

  Widget _field({
    required TextEditingController
        controller,
    required String label,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)?
        validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscureText,

      decoration:
          InputDecoration(
        labelText: label,

        prefixIcon: Icon(
          icon,
          color:
              const Color(0xFF7652A5),
        ),

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
            16,
          ),
          borderSide:
              BorderSide.none,
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              BorderSide(
            color:
                const Color(
              0xFFE1D5E8,
            ),
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(0xFF7652A5),
            width: 2,
          ),
        ),
      ),

      validator: validator,
    );
  }
}