/// 把正文按 LCD 的宽度折行。
///
/// 缝纫像素字体是**比例字体**：一个汉字约占一个字宽，ASCII 约半个。
/// 按字符数平均折行会让中英混排的段落长短不一，所以这里按「字宽」估算。
library;

/// 一个字宽（em）能放几个字符。
typedef EmWidth = double;

/// 判断字符占几个字宽。
///
/// 只覆盖常见范围：CJK 汉字、假名、谚文、全角标点算 1 个字宽，
/// 其余（拉丁字母、数字、半角标点）算 0.5。
EmWidth emWidthOf(String char) {
  final code = char.runes.first;
  if (code >= 0x1100 && code <= 0x115F) return 1.0; // 谚文字母
  if (code >= 0x2E80 && code <= 0x303E) return 1.0; // CJK 部首、标点
  if (code >= 0x3041 && code <= 0x33FF) return 1.0; // 假名、CJK 兼容
  if (code >= 0x3400 && code <= 0x4DBF) return 1.0; // CJK 扩展 A
  if (code >= 0x4E00 && code <= 0x9FFF) return 1.0; // CJK 基本区
  if (code >= 0xA000 && code <= 0xA4CF) return 1.0; // 彝文
  if (code >= 0xAC00 && code <= 0xD7A3) return 1.0; // 谚文音节
  if (code >= 0xF900 && code <= 0xFAFF) return 1.0; // CJK 兼容表意
  if (code >= 0xFE30 && code <= 0xFE6F) return 1.0; // CJK 兼容形式
  if (code >= 0xFF00 && code <= 0xFF60) return 1.0; // 全角形式
  if (code >= 0xFFE0 && code <= 0xFFE6) return 1.0; // 全角符号
  return 0.5;
}

/// 按 [columns] 个字宽折行。结果至少有一行（空文本给一个空串），
/// 这样光标永远有地方待。
///
/// 断行时**优先在空格处断**——否则英文单词会被劈成两半。中文没有空格，
/// 逐字断行本来就是对的，所以两种情况都照顾到了。
List<String> wrapForLcd(String text, {required double columns}) {
  if (text.isEmpty) return [''];

  final lines = <String>[];
  var current = '';
  var width = 0.0;
  var lastSpace = -1; // current 里最后一个空格的下标

  for (final char in text.split('')) {
    final w = emWidthOf(char);

    if (width + w > columns && current.isNotEmpty) {
      if (lastSpace > 0) {
        lines.add(current.substring(0, lastSpace));
        current = current.substring(lastSpace + 1);
        width = _widthOf(current);
      } else {
        lines.add(current);
        current = '';
        width = 0;
      }
      lastSpace = -1;
    }

    current += char;
    width += w;
    if (char == ' ') lastSpace = current.length - 1;
  }

  if (current.isNotEmpty) lines.add(current);
  return lines;
}

/// 按 [columns] 个字宽折一串**记号**，保证不把记号拆开。
///
/// 编辑器的正文是 `83 82 4#4` 这样的记号序列。按字符折行会把 `87` 拆成
/// `8` 和 `7` 落在两行——那看着就是两个音符，意思全变了。
List<String> wrapTokensForLcd(
  List<String> tokens, {
  required double columns,
}) {
  if (tokens.isEmpty) return [''];

  const spaceWidth = 0.5;
  final lines = <String>[];
  var current = '';
  var width = 0.0;

  for (final token in tokens) {
    final tokenWidth = _widthOf(token);
    final needed = current.isEmpty ? tokenWidth : tokenWidth + spaceWidth;

    if (width + needed > columns && current.isNotEmpty) {
      lines.add(current);
      current = token;
      width = tokenWidth;
    } else {
      current = current.isEmpty ? token : '$current $token';
      width += needed;
    }
  }

  if (current.isNotEmpty) lines.add(current);
  return lines;
}

double _widthOf(String text) =>
    text.split('').fold(0.0, (sum, char) => sum + emWidthOf(char));
