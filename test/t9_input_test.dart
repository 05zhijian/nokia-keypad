import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/model/nokia_key.dart';
import 'package:nokia/state/t9_input.dart';

/// 多按输入的纯逻辑测试。
///
/// 这一层没有计时器（超时由持有者调 `commitPending()` 触发），所以两条路径
/// ——换键提交、超时提交——都能直接测，不用伪造时钟。
void main() {
  late T9Input t9;

  setUp(() => t9 = T9Input());

  group('单次按键', () {
    test('按一下 2 出 a', () {
      t9.press(NokiaKey.k2);
      expect(t9.pendingLetter, 'a');
      expect(t9.display, 'a');
      expect(t9.text, '', reason: '还没提交，正文应当还是空的');
    });

    test('0 的第一下是空格', () {
      t9.press(NokiaKey.k0);
      t9.commitPending();
      expect(t9.text, ' ');
    });

    test('软键不产出字符', () {
      t9.press(NokiaKey.softLeft);
      t9.press(NokiaKey.call);
      expect(t9.display, '');
    });
  });

  group('连按循环', () {
    test('连按 2 依次是 a b c 2，第五下绕回 a', () {
      const expected = ['a', 'b', 'c', '2', 'a'];
      for (var i = 0; i < expected.length; i++) {
        t9.press(NokiaKey.k2);
        expect(t9.pendingLetter, expected[i], reason: '第 ${i + 1} 下');
      }
    });

    test('7 键有四个字母，第四下出字母、第五下才出数字', () {
      for (final letter in ['p', 'q', 'r', 's', '7']) {
        t9.press(NokiaKey.k7);
        expect(t9.pendingLetter, letter);
      }
    });

    test('连按过程中正文里始终只有一个字符', () {
      t9.press(NokiaKey.k2);
      t9.press(NokiaKey.k2);
      t9.press(NokiaKey.k2);
      expect(t9.display, 'c');
        });
  });

  group('提交', () {
    test('换键会先把上一个字母落定', () {
      t9.press(NokiaKey.k2); // a（待定）
      t9.press(NokiaKey.k2); // b（待定）
      t9.press(NokiaKey.k5); // 换键：b 落定，j 待定

      expect(t9.text, 'b');
      expect(t9.pendingLetter, 'j');
      expect(t9.display, 'bj');
    });

    test('commitPending 把待定字母落进正文', () {
      t9.press(NokiaKey.k4);
      t9.commitPending();
      expect(t9.text, 'g');
      expect(t9.pendingLetter, '');
      expect(t9.display, 'g');
    });

    test('没有待定字母时 commitPending 是空操作', () {
      t9.commitPending();
      expect(t9.text, '');
    });

    test('换键与超时走的是同一条提交路径', () {
      // 换键提交
      t9.press(NokiaKey.k2);
      t9.press(NokiaKey.k3);
      final bySwitch = t9.text;

      // 超时提交
      final other = T9Input();
      other.press(NokiaKey.k2);
      other.commitPending();
      expect(other.text, bySwitch);
    });
  });

  group('大小写', () {
    test('# 切换大小写，并且不产出字符', () {
      expect(t9.isUpperCase, isFalse);
      t9.press(NokiaKey.hash);
      expect(t9.isUpperCase, isTrue);
      expect(t9.display, '');
    });

    test('切成大写后按出的字母是大写', () {
      t9.press(NokiaKey.hash);
      t9.press(NokiaKey.k2);
      t9.commitPending();
      expect(t9.text, 'A');
    });

    test('# 会先把待定字母按当前大小写落定', () {
      t9.press(NokiaKey.k2); // a（待定，小写）
      t9.press(NokiaKey.hash);
      expect(t9.text, 'a', reason: '落定时应当还是小写');
      expect(t9.isUpperCase, isTrue);
    });
  });

  group('退格', () {
    test('先退待定字母，再退正文', () {
      t9.press(NokiaKey.k2);
      t9.commitPending(); // 正文 "a"
      t9.press(NokiaKey.k5); // j 待定

      t9.backspace(); // 退掉待定的 j
      expect(t9.pendingLetter, '');
      expect(t9.text, 'a');

      t9.backspace(); // 再退正文
      expect(t9.text, '');
    });

    test('连按中退格是回退一次连按，不是整段删掉', () {
      t9.press(NokiaKey.k2); // a
      t9.press(NokiaKey.k2); // b
      t9.press(NokiaKey.k2); // c
      expect(t9.pendingLetter, 'c');

      t9.backspace();
      expect(t9.pendingLetter, 'b');
      t9.backspace();
      expect(t9.pendingLetter, 'a');
      t9.backspace();
      expect(t9.pendingLetter, '', reason: '退到第一下就该整个消掉');
    });

    test('空正文退格不报错', () {
      t9.backspace();
      expect(t9.display, '');
    });
  });

  test('clear 清空正文与待定状态', () {
    t9.press(NokiaKey.k2);
    t9.commitPending();
    t9.press(NokiaKey.k5);
    t9.clear();
    expect(t9.display, '');
    expect(t9.pendingLetter, '');
  });
}
