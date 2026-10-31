import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({
    super.key,
  });

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
          'HOW TO PLAY',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body: ListView(
        padding:
            const EdgeInsets.all(20),

        children: [
          _helpCard(
            Icons.play_circle,
            '1. Start the Game',
            'Choose a level and press Play Game to start.',
          ),

          _helpCard(
            Icons.bubble_chart,
            '2. Blast Bubbles',
            'Match and blast bubbles to earn points.',
          ),

          _helpCard(
            Icons.flag,
            '3. Complete the Level',
            'Finish the level objective before you lose.',
          ),

          _helpCard(
            Icons.star,
            '4. Earn Stars',
            'Stars are awarded only when the level is successfully completed.',
          ),

          _helpCard(
            Icons.cancel,
            '5. Failed Level',
            'If you fail the level, you receive 0 stars for that attempt.',
          ),

          _helpCard(
            Icons.lock_open,
            '6. Unlock Levels',
            'Completing levels allows you to progress to the next level.',
          ),

          _helpCard(
            Icons.emoji_events,
            '7. Leaderboard',
            'Your completed-level scores can appear on the leaderboard.',
          ),
        ],
      ),
    );
  }

  Widget _helpCard(
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border:
            Border.all(
          color:
              const Color(0xFFE0D4E8),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                const BoxDecoration(
              shape: BoxShape.circle,
              color:
                  Color(0xFFEDE2F5),
            ),
            child: Icon(
              icon,
              color:
                  const Color(0xFF6A3DB8),
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  description,
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    height: 1.4,
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