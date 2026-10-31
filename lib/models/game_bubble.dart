enum BubbleType {
  red,
  blue,
  green,
  yellow,
  purple,
  orange,
  bomb,
  rainbow,
  stone,
}

class GameBubble {
  int row;
  int column;

  BubbleType type;

  double x;
  double y;

  double rotation;
  double scale;
  double opacity;
  double velocityY;

  bool removing;
  bool falling;

  GameBubble({
    required this.row,
    required this.column,
    required this.type,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.scale = 1,
    this.opacity = 1,
    this.velocityY = 0,
    this.removing = false,
    this.falling = false,
  });
}