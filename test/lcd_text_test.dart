import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/audio/nokia_tune.dart';
import 'package:nokia/theme/nokia_metrics.dart';
import 'package:nokia/utils/lcd_text.dart';

void main() {
  group('emWidthOf', () {
    test('汉字、全角标点占一个字宽', () {
      expect(emWidthOf('无'), 1.0);
      expect(emWidthOf('，'), 1.0);
      expect(emWidthOf('。'), 1.0);
    });

    test('拉丁字母、数字、半角标点占半个字宽', () {
      expect(emWidthOf('a'), 0.5);
      expect(emWidthOf('Z'), 0.5);
      expect(emWidthOf('7'), 0.5);
      expect(emWidthOf(' '), 0.5);
    });
  });

  group('wrapForLcd', () {
    test('空文本给一个空行，好让光标有地方待', () {
      expect(wrapForLcd('', columns: 7), ['']);
    });

    test('放得下就不折', () {
      expect(wrapForLcd('abc', columns: 7), ['abc']);
    });

    test('中文按字宽折行', () {
      // 每行 3 个字宽 → 每行 3 个汉字
      expect(wrapForLcd('无内鬼抓紧上车', columns: 3), [
        '无内鬼',
        '抓紧上',
        '车',
      ]);
    });

    test('同样列数下，一行能放下的 ASCII 字符数是汉字的两倍', () {
      final cjk = wrapForLcd('无内鬼', columns: 3);
      final latin = wrapForLcd('abcdef', columns: 3);
      expect(cjk, ['无内鬼']);
      expect(latin, ['abcdef']);
    });

    test('中英混排按字宽算，不会一边长一边短', () {
      // '无内鬼' = 3 字宽，'ab' = 1 字宽，合计 4 > 3，所以要折
      expect(wrapForLcd('无内鬼ab', columns: 3), ['无内鬼', 'ab']);
    });

    test('单个字符超宽时独占一行，不会死循环', () {
      expect(wrapForLcd('无', columns: 0.1), ['无']);
    });

    test('折行不丢字符', () {
      const text = '无内鬼，抓紧上车。今晚八点，老地方见。';
      final lines = wrapForLcd(text, columns: 7);
      expect(lines.join(), text);
    });

    test('英文优先在空格处断，不把单词劈开', () {
      // 每行 5 个字宽 → 每行能放 10 个 ASCII 字符
      final lines = wrapForLcd('hello world foo', columns: 5);
      expect(lines, ['hello', 'world foo']);
    });

    test('中文没有空格，仍然逐字断', () {
      expect(wrapForLcd('无内鬼抓紧', columns: 2), ['无内', '鬼抓', '紧']);
    });

    test('没有空格的超长串按字符硬断，不会死循环', () {
      // columns: 1 是 1 个字宽；ASCII 占半个字宽，所以每行放得下 2 个字符。
      expect(wrapForLcd('abcdefghij', columns: 1),
          ['ab', 'cd', 'ef', 'gh', 'ij']);
    });
  });

  group('wrapTokensForLcd', () {
    test('空序列给一个空行', () {
      expect(wrapTokensForLcd([], columns: 7), ['']);
    });

    test('记号绝不被拆开', () {
      // 每个记号占 1 个字宽，加空格 0.5；每行 3 个字宽 → 每行两个记号
      final lines = wrapTokensForLcd(['83', '82', '4#4', '4#5'], columns: 3);
      for (final line in lines) {
        for (final token in line.split(' ')) {
          expect(['83', '82', '4#4', '4#5'], contains(token),
              reason: '记号被拆开了：$line');
        }
      }
    });

    test('不丢记号', () {
      final tokens = ['83', '82', '4#4', '4#5', '8#1', '87', '42', '43'];
      final lines = wrapTokensForLcd(tokens, columns: 3);
      expect(lines.join(' ').split(' '), tokens);
    });

    test('单个记号超宽时独占一行', () {
      expect(wrapTokensForLcd(['166#6'], columns: 1), ['166#6']);
    });

    test('诺基亚铃声的记号序列折行后仍可完整还原', () {
      final tokens = [for (final note in nokiaTune()) note.label, '4'];
      final lines = wrapTokensForLcd(tokens, columns: lcdColumns);
      expect(lines.join(' ').split(' '), tokens);
    });
  });
}
