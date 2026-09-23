import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/audio/nokia_tune.dart';

/// 预置旋律的测试。
///
/// 这一段值得单独钉住：「一按就听出来是诺基亚」全押在它上面，
/// 而它又是手写的记谱——改错一个字符不会报错，只会变得不像。
/// 音高走向经两个独立来源核对过，这里把它固化成断言。
void main() {
  test('记谱全部能解析', () {
    expect(() => nokiaTune(), returnsNormally);
    expect(nokiaTune(), hasLength(nokiaTuneNotation.length));
  });

  test('音高走向是核实过的那一条：E D F# G# / C# B D E / B A C# E / A', () {
    final tune = nokiaTune();

    // 音级：1=C 2=D 3=E 4=F 5=G 6=A 7=B
    expect([for (final n in tune) n.pitch], [3, 2, 4, 5, 1, 7, 2, 3, 7, 6, 1, 3, 6]);

    // 该升的只有 F# G# C# C#
    expect(
      [for (final n in tune) n.sharp],
      [false, false, true, true, true, false, false, false, false, false, true, false, false],
    );
  });

  test('时值序列：八分八分四分四分，重复三遍，最后一个二分', () {
    expect(
      [for (final n in nokiaTune()) n.duration],
      [8, 8, 4, 4, 8, 8, 4, 4, 8, 8, 4, 4, 2],
    );
  });

  test('起音是 E6、收尾落在 A5', () {
    final tune = nokiaTune();
    expect(tune.first.midi, 88, reason: 'E6 = MIDI 88');
    expect(tune.last.midi, 81, reason: 'A5 = MIDI 81');
  });

  test('全部音高都落在音频层的音符表范围内（C4-B6，即 MIDI 60-95）', () {
    for (final note in nokiaTune()) {
      final midi = note.midi;
      expect(midi, isNotNull, reason: '${note.notation} 没有音高');
      expect(midi, inInclusiveRange(60, 95), reason: '${note.notation} 超出音符表');
    }
  });

  test('每个音的时长都是正数，播放循环不会卡死', () {
    for (final note in nokiaTune()) {
      expect(note.durationMs(1440), greaterThan(0));
    }
  });
}
