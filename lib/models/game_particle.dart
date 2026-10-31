import 'package:flutter/material.dart';

class GameParticle {
  double x;
  double y;

  double vx;
  double vy;

  double size;
  double life;

  Color color;

  GameParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.color,
  });
}