
import 'package:flutter/material.dart';

import 'game_screen.dart';

class LevelScreen extends StatelessWidget {
  final String playerId;
  final String playerName;
  final int currentLevel;

  const LevelScreen({
    super.key,
    required this.playerId,
    required this.playerName,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    const int totalLevels = 20;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1FC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F1FC),
        elevation: 0,
        title: const Text(
          'LEVELS',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: GridView.builder(
        padding: const EdgeInsets.all(20),

        itemCount: totalLevels,

        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.1,
        ),

        itemBuilder: (context, index) {
          final int level = index + 1;

          final bool unlocked =
              level <= currentLevel;

          return InkWell(
            borderRadius: BorderRadius.circular(22),

            onTap: unlocked
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          playerId: playerId,
                          playerName: playerName,
                          levelNumber: level,
                        ),
                      ),
                    );
                  }
                : null,

            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(22),

                color: unlocked
                    ? const Color(0xFFF1E6F8)
                    : Colors.grey.shade200,

                border: Border.all(
                  color: unlocked
                      ? const Color(0xFFCCB4DD)
                      : Colors.grey.shade300,
                ),
              ),

              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [
                  Icon(
                    unlocked
                        ? Icons.bubble_chart
                        : Icons.lock,
                    size: 42,
                    color: unlocked
                        ? const Color(0xFF6A3DB8)
                        : Colors.grey,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'LEVEL $level',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: unlocked
                          ? const Color(0xFF513A69)
                          : Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    unlocked ? 'PLAY' : 'LOCKED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: unlocked
                          ? const Color(0xFF8A64AD)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
