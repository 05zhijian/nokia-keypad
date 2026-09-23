import '../model/nokia_key.dart';

/// 多按输入（multi-tap）的字母表。
///
/// 键面字母之后还挂着数字本身——真机上「2」连按四次出的是 `2`，
/// 不是又绕回 `a`。`0` 的第一次是空格，`*` 是诺基亚那几个特殊符号。
const t9Letters = <NokiaKey, String>{
  NokiaKey.k1: '.,?!1',
  NokiaKey.k2: 'abc2',
  NokiaKey.k3: 'def3',
  NokiaKey.k4: 'ghi4',
  NokiaKey.k5: 'jkl5',
  NokiaKey.k6: 'mno6',
  NokiaKey.k7: 'pqrs7',
  NokiaKey.k8: 'tuv8',
  NokiaKey.k9: 'wxyz9',
  NokiaKey.k0: ' 0',
  NokiaKey.star: '*+pw',
};

/// 多按输入的状态机。
///
/// 按 `2` 一次是 a，两次是 b，三次是 c，四次是 2；换键或超时则把当前字母
/// 落到正文里。`#` 切换大小写。
///
/// 这里**刻意不含计时器**——超时提交由持有者调用 [commitPending] 触发。
/// 逻辑层保持是纯的，测试不用伪造时钟也能同时覆盖「换键提交」和「超时提交」
/// 两条路径；计时器归 UI 层管，那是它的职责。
class T9Input {
  String _committed = '';

  /// 正在连按的键；为 null 表示没有待提交的字母。
  NokiaKey? _pendingKey;
  int _cycle = 0;
  bool _upperCase = false;

  /// 已经敲定的正文。
  String get text => _committed;

  bool get isUpperCase => _upperCase;

  /// 连按中、还没落定的那个字母。
  String get pendingLetter {
    final key = _pendingKey;
    if (key == null) return '';
    final letters = t9Letters[key];
    if (letters == null) return '';
    final letter = letters[_cycle % letters.length];
    return _applyCase(letter);
  }

  /// 屏幕上应当显示的完整文本（已敲定 + 待提交）。
  String get display => _committed + pendingLetter;

  bool get isEmpty => display.isEmpty;

  /// 按下一个字母键。软键、通话键会走 [t9Letters] 查不到而静默忽略。
  void press(NokiaKey key) {
    // `#` 在诺基亚上就是大小写开关，不产出字符。
    if (key == NokiaKey.hash) {
      commitPending();
      _upperCase = !_upperCase;
      return;
    }

    final letters = t9Letters[key];
    if (letters == null) return;

    if (key == _pendingKey) {
      // 连按同一个键：循环到下一个字母。
      _cycle++;
    } else {
      // 换了键：先把上一个字母落定，再开始新的。
      commitPending();
      _pendingKey = key;
      _cycle = 0;
    }
  }

  /// 提交待定字母。连按超时或换键时调用。
  void commitPending() {
    final letter = pendingLetter;
    if (letter.isEmpty) return;
    _committed += letter;
    _pendingKey = null;
    _cycle = 0;
  }

  /// 退格。有连按中的字母就先退它，跟真机一致。
  void backspace() {
    if (_pendingKey != null) {
      if (_cycle > 0) {
        _cycle--;
      } else {
        _pendingKey = null;
      }
      return;
    }
    if (_committed.isEmpty) return;
    _committed = _committed.substring(0, _committed.length - 1);
  }

  void clear() {
    _committed = '';
    _pendingKey = null;
    _cycle = 0;
  }

  String _applyCase(String letter) =>
      _upperCase ? letter.toUpperCase() : letter;
}
