import 'dart:math' as math;

import '../state/phone_state.dart';

/// 四个方向。
enum Direction { up, down, left, right }

/// 网格上的一个格子。
class Cell {
  const Cell(this.x, this.y);

  final int x;
  final int y;

  Cell movedBy(Direction d) => switch (d) {
        Direction.up => Cell(x, y - 1),
        Direction.down => Cell(x, y + 1),
        Direction.left => Cell(x - 1, y),
        Direction.right => Cell(x + 1, y),
      };

  @override
  bool operator ==(Object other) =>
      other is Cell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

/// 贪吃蛇。
///
/// **纯逻辑**：不碰计时器、不碰渲染。控制器负责按节拍调 [step]，
/// 于是游戏规则可以完全脱离真机和时钟来测试——撞墙、咬到自己、
/// 吃到食物变长、不能掉头，这些都是能穷尽验证的。
class SnakeGame {
  SnakeGame({
    this.columns = 18,
    this.rows = 14,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    reset();
  }

  final int columns;
  final int rows;
  final math.Random _random;

  /// 蛇身，**头在最前面**。
  late List<Cell> snake;
  late Cell food;
  late Direction direction;
  late int score;
  late bool gameOver;

  Cell get head => snake.first;

  /// 每走一格的间隔。吃得越多走得越快——真机也是这样。
  Duration get tick {
    final ms = (260 - score * 10).clamp(90, 260);
    return Duration(milliseconds: ms);
  }

  void reset() {
    final midY = rows ~/ 2;
    // 头在右、尾在左，朝右走——留出反应时间，不会一开局就撞墙。
    snake = [Cell(2, midY), Cell(1, midY), Cell(0, midY)];
    direction = Direction.right;
    score = 0;
    gameOver = false;
    _spawnFood();
  }

  /// 走一格。
  void step() {
    if (gameOver) return;

    final next = head.movedBy(direction);

    // 撞墙
    if (next.x < 0 || next.x >= columns || next.y < 0 || next.y >= rows) {
      gameOver = true;
      return;
    }

    final ate = next == food;
    // 咬到自己。注意：**没吃到食物时尾巴会挪走**，所以头钻进原来尾巴那一格
    // 是合法的——这一点和真机的规则一致，判错会让玩家觉得「明明没撞上」。
    final body = ate ? snake : snake.sublist(0, snake.length - 1);
    if (body.contains(next)) {
      gameOver = true;
      return;
    }

    snake.insert(0, next);
    if (ate) {
      score++;
      _spawnFood();
    } else {
      snake.removeLast();
    }
  }

  /// 转向。**不允许 180° 掉头**，否则一按就咬到自己。
  void turn(Direction next) {
    if (gameOver) return;
    const opposite = {
      Direction.up: Direction.down,
      Direction.down: Direction.up,
      Direction.left: Direction.right,
      Direction.right: Direction.left,
    };
    if (opposite[direction] == next) return;
    direction = next;
  }

  void _spawnFood() {
    final free = <Cell>[
      for (var y = 0; y < rows; y++)
        for (var x = 0; x < columns; x++)
          if (!snake.contains(Cell(x, y))) Cell(x, y),
    ];
    if (free.isEmpty) {
      // 整屏都是蛇——填满了，当作通关结束。
      gameOver = true;
      return;
    }
    food = free[_random.nextInt(free.length)];
  }

  /// 转成屏幕上要点亮的点阵。
  ///
  /// 蛇和食物都是「亮」，不做区分——单色屏上本来就只有一亮一灭两种状态，
  /// 真机也是这么显示的。
  LcdGrid toGrid() {
    final cells = List<bool>.filled(columns * rows, false);
    for (final part in snake) {
      cells[part.y * columns + part.x] = true;
    }
    cells[food.y * columns + food.x] = true;
    return LcdGrid(columns: columns, rows: rows, cells: cells);
  }
}
