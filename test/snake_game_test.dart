import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/game/snake_game.dart';

/// 贪吃蛇的规则测试。
///
/// 这一层是**纯逻辑**：不碰计时器、不碰渲染、不依赖真机，所以能把规则
/// 一条条穷尽验证。尤其是「头钻进原来尾巴那一格算不算死」这种容易判错的
/// 细节——判错了玩家会觉得「明明没撞上」。
void main() {
  /// 造一个可控的对局：食物放到角落，免得随便一走就吃到。
  SnakeGame makeGame({int columns = 10, int rows = 8}) {
    final game = SnakeGame(
      columns: columns,
      rows: rows,
      random: math.Random(1),
    );
    game.food = Cell(columns - 1, rows - 1);
    return game;
  }

  group('初始状态', () {
    test('三节、朝右、零分、没结束', () {
      final game = makeGame();
      expect(game.snake, hasLength(3));
      expect(game.direction, Direction.right);
      expect(game.score, 0);
      expect(game.gameOver, isFalse);
    });

    test('头在最前面', () {
      final game = makeGame();
      expect(game.head, game.snake.first);
      // 头在右、尾在左
      expect(game.snake.first.x, greaterThan(game.snake.last.x));
    });

    test('开局不会一走出来就撞墙', () {
      final game = makeGame(columns: 4, rows: 4);
      game.step();
      expect(game.gameOver, isFalse);
    });
  });

  group('走一步', () {
    test('朝当前方向前进一格', () {
      final game = makeGame();
      final before = game.head;
      game.step();
      expect(game.head, Cell(before.x + 1, before.y));
    });

    test('没吃到食物时长度不变，尾巴跟着挪', () {
      final game = makeGame();
      final tailBefore = game.snake.last;
      game.step();
      expect(game.snake, hasLength(3));
      expect(game.snake.contains(tailBefore), isFalse, reason: '尾巴该挪走了');
    });

    test('吃到食物会变长、加一分', () {
      final game = makeGame();
      game.food = Cell(game.head.x + 1, game.head.y);

      game.step();

      expect(game.snake, hasLength(4));
      expect(game.score, 1);
    });

    test('吃完之后会重新生成食物，而且不落在蛇身上', () {
      final game = makeGame();
      game.food = Cell(game.head.x + 1, game.head.y);
      game.step();

      expect(game.snake.contains(game.food), isFalse);
    });
  });

  group('死亡', () {
    test('撞到墙就结束', () {
      final game = makeGame(columns: 5, rows: 5);
      // 蛇在 x=0..2，朝右。走三步就该出界。
      for (var i = 0; i < 3; i++) {
        game.step();
      }
      expect(game.gameOver, isTrue);
    });

    test('咬到自己的身体就结束', () {
      final game = makeGame();
      game.snake = [
        const Cell(5, 5),
        const Cell(4, 5),
        const Cell(4, 6),
        const Cell(5, 6),
        const Cell(6, 6),
      ];
      game.direction = Direction.down; // 下一步走到 (5,6)，身体中段

      game.step();

      expect(game.gameOver, isTrue);
    });

    test('头钻进原来尾巴那一格**不算死**', () {
      // 这条规则很容易判错：没吃到食物时尾巴会同时挪走，
      // 所以那一格在头到达时已经空出来了。真机就是这么算的。
      final game = makeGame();
      game.snake = [
        const Cell(5, 5),
        const Cell(4, 5),
        const Cell(4, 6),
        const Cell(5, 6), // 尾巴
      ];
      game.direction = Direction.down;

      game.step();

      expect(game.gameOver, isFalse, reason: '尾巴同时会挪走，不该判死');
      expect(game.head, const Cell(5, 6));
    });

    test('结束之后 step 不再改变任何东西', () {
      final game = makeGame(columns: 5, rows: 5);
      for (var i = 0; i < 3; i++) {
        game.step();
      }
      expect(game.gameOver, isTrue);

      final frozen = List<Cell>.from(game.snake);
      game.step();
      expect(game.snake, frozen);
    });

    test('结束之后 turn 也不再生效', () {
      final game = makeGame(columns: 5, rows: 5);
      for (var i = 0; i < 3; i++) {
        game.step();
      }
      game.turn(Direction.up);
      expect(game.direction, Direction.right);
    });
  });

  group('转向', () {
    test('不能 180° 掉头', () {
      final game = makeGame();
      expect(game.direction, Direction.right);
      game.turn(Direction.left);
      expect(game.direction, Direction.right, reason: '掉头会直接咬到自己');
    });

    test('垂直方向可以转', () {
      final game = makeGame();
      game.turn(Direction.up);
      expect(game.direction, Direction.up);
    });

    test('转完之后那个方向就成了新的「当前方向」', () {
      final game = makeGame();
      game.turn(Direction.up);
      game.turn(Direction.down); // 相对新方向是掉头
      expect(game.direction, Direction.up);
    });
  });

  group('节拍', () {
    test('分数越高走得越快', () {
      final game = makeGame();
      final slow = game.tick;
      game.score = 10;
      expect(game.tick, lessThan(slow));
    });

    test('但有下限，不会快到看不清', () {
      final game = makeGame();
      game.score = 1000;
      expect(game.tick.inMilliseconds, 90);
    });
  });

  group('点阵', () {
    test('蛇身和食物都被点亮', () {
      final game = makeGame(columns: 5, rows: 4);
      game.food = const Cell(4, 3);

      final grid = game.toGrid();

      expect(grid.columns, 5);
      expect(grid.rows, 4);
      for (final part in game.snake) {
        expect(grid.at(part.x, part.y), isTrue);
      }
      expect(grid.at(4, 3), isTrue, reason: '食物也要亮');
    });

    test('空的地方不亮', () {
      final game = makeGame(columns: 5, rows: 4);
      game.food = const Cell(4, 3);
      final grid = game.toGrid();
      expect(grid.at(0, 0), isFalse);
    });
  });

  test('reset 之后回到初始状态', () {
    final game = makeGame();
    game.food = Cell(game.head.x + 1, game.head.y);
    game.step();
    game.score = 5;

    game.reset();

    expect(game.snake, hasLength(3));
    expect(game.score, 0);
    expect(game.gameOver, isFalse);
    expect(game.direction, Direction.right);
  });
}
