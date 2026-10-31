import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LeaderboardScreen
    extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
  });

  @override
  State<LeaderboardScreen>
      createState() =>
          _LeaderboardScreenState();
}

class _LeaderboardScreenState
    extends State<LeaderboardScreen> {
  static const String baseUrl =
      'http://localhost:5000';

  bool loading = true;

  List<dynamic> scores = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final response =
          await http.get(
        Uri.parse(
          '$baseUrl/api/scores',
        ),
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body);

        if (data['success'] == true) {
          setState(() {
            scores =
                data['scores'] ?? [];
            loading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint(
        'Leaderboard error: $e',
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F1FC),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF8F1FC),
        elevation: 0,
        title: const Text(
          'LEADERBOARD',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    Color(0xFF6A3DB8),
              ),
            )
          : scores.isEmpty
              ? const Center(
                  child: Text(
                    'No scores yet.\nComplete a level to appear here!',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh:
                      _loadLeaderboard,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    itemCount:
                        scores.length,
                    itemBuilder:
                        (context, index) {
                      final score =
                          scores[index];

                      final rank =
                          index + 1;

                      final name =
                          score['playerName']
                                  ?.toString() ??
                              'Player';

                      final points =
                          score['score']
                                  ?.toString() ??
                              '0';

                      final level =
                          score['levelNumber']
                                  ?.toString() ??
                              '1';

                      final stars =
                          score['stars']
                                  ?.toString() ??
                              '0';

                      return Container(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 12,
                        ),

                        padding:
                            const EdgeInsets
                                .all(16),

                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFFE0D4E8,
                            ),
                          ),
                        ),

                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration:
                                  BoxDecoration(
                                shape:
                                    BoxShape.circle,
                                color:
                                    rank <= 3
                                        ? const Color(
                                            0xFFFFD54F,
                                          )
                                        : const Color(
                                            0xFFEDE3F2,
                                          ),
                              ),
                              child: Center(
                                child: Text(
                                  '$rank',
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 14,
                            ),

                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    name,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.w800,
                                      fontSize:
                                          16,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    'Level $level',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .end,
                              children: [
                                Text(
                                  points,
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 16,
                                      color:
                                          Color(
                                        0xFFFFB300,
                                      ),
                                    ),
                                    Text(
                                      stars,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}