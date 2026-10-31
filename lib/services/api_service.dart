import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Chrome / Flutter Web
  static const String baseUrl = 'http://localhost:5000/api';

  // ============================================================
  // CREATE PLAYER
  // ============================================================

  static Future<Map<String, dynamic>> createPlayer({
    required String name,
    required String email,
    required int age,
    String profileImage = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/players'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'age': age,
        'profileImage': profileImage,
        'currentLevel': 1,
        'currentScore': 0,
        'highestScore': 0,
        'totalStars': 0,
        'totalGamesPlayed': 0,
        'gamesWon': 0,
        'gamesLost': 0,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 201) {
      throw Exception(
        data['message'] ?? 'Failed to create player',
      );
    }

    return data;
  }

  // ============================================================
  // GET PLAYER
  // ============================================================

  static Future<Map<String, dynamic>> getPlayer(
    String id,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/players/$id'),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'Failed to load player',
      );
    }

    return Map<String, dynamic>.from(
      data['player'] ?? data,
    );
  }

  // ============================================================
  // UPDATE PLAYER PROFILE
  // ============================================================

  static Future<Map<String, dynamic>> updatePlayer({
    required String id,
    String? name,
    String? email,
    int? age,
    String? profileImage,
  }) async {
    final Map<String, dynamic> body = {};

    if (name != null) {
      body['name'] = name;
    }

    if (email != null) {
      body['email'] = email;
    }

    if (age != null) {
      body['age'] = age;
    }

    if (profileImage != null) {
      body['profileImage'] = profileImage;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/players/$id'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'Failed to update player',
      );
    }

    return Map<String, dynamic>.from(
      data['player'] ?? data,
    );
  }

  // ============================================================
  // UPDATE GAME PROGRESS
  // ============================================================

  static Future<Map<String, dynamic>> updateGameProgress({
    required String id,
    required int currentLevel,
    required int currentScore,
    required int totalStars,
    bool gameWon = false,
    bool gameLost = false,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/players/$id/progress'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'currentLevel': currentLevel,
        'currentScore': currentScore,
        'totalStars': totalStars,
        'gameWon': gameWon,
        'gameLost': gameLost,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'Failed to update game progress',
      );
    }

    return Map<String, dynamic>.from(
      data['player'] ?? data,
    );
  }

  // ============================================================
  // SAVE SCORE
  // ============================================================

  static Future<Map<String, dynamic>> saveScore({
    required String playerName,
    required int levelNumber,
    required int score,
    required int stars,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scores'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'playerName': playerName,
        'levelNumber': levelNumber,
        'score': score,
        'stars': stars,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 201) {
      throw Exception(
        data['message'] ?? 'Failed to save score',
      );
    }

    return data;
  }

  // ============================================================
  // GET LEVELS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getLevels() async {
    final response = await http.get(
      Uri.parse('$baseUrl/levels'),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'Failed to load levels',
      );
    }

    final List levels = data['levels'] ?? [];

    return levels
        .map(
          (e) => Map<String, dynamic>.from(e),
        )
        .toList();
  }

  // ============================================================
  // GET LEADERBOARD
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      getLeaderboard() async {
    final response = await http.get(
      Uri.parse('$baseUrl/scores/leaderboard'),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'Failed to load leaderboard',
      );
    }

    final List leaderboard =
        data['leaderboard'] ?? [];

    return leaderboard
        .map(
          (e) => Map<String, dynamic>.from(e),
        )
        .toList();
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  static Future<Map<String, dynamic>>
      getSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/settings'),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'Failed to load settings',
      );
    }

    return Map<String, dynamic>.from(
      data['settings'] ?? data,
    );
  }

  static Future<Map<String, dynamic>>
      updateSettings({
    bool? music,
    bool? soundEffects,
    bool? vibration,
    bool? notifications,
  }) async {
    final Map<String, dynamic> body = {};

    if (music != null) {
      body['music'] = music;
    }

    if (soundEffects != null) {
      body['soundEffects'] = soundEffects;
    }

    if (vibration != null) {
      body['vibration'] = vibration;
    }

    if (notifications != null) {
      body['notifications'] = notifications;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/settings'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'Failed to update settings',
      );
    }

    return Map<String, dynamic>.from(
      data['settings'] ?? data,
    );
  }

  // ============================================================
  // JSON HELPER
  // ============================================================

  static Map<String, dynamic> _decode(
    http.Response response,
  ) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'message': response.body,
      };
    } catch (_) {
      return {
        'message': response.body.isEmpty
            ? 'Unknown server error'
            : response.body,
      };
    }
  }
}
