import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/audio/dtmf.dart';
import 'package:nokia/audio/tones.dart';
import 'package:nokia/audio/wav.dart';
import 'package:nokia/model/nokia_key.dart';

/// 音频合成层的测试。
///
/// 这一层能在没有声卡、没有手机的环境下完整验证——WAV 头、频率表、包络都是
/// 纯计算。真机上手感对不对测不了，但「有没有合成出正确的东西」可以。
void main() {
  group('encodeWav', () {
    test('写出正确的 RIFF/WAVE 头，总长度与采样数对得上', () {
      final samples = Int16List.fromList([0, 1000, -1000, 32767, -32768]);
      final bytes = encodeWav(samples);

      expect(bytes.length, 44 + samples.length * 2);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    });

    test('采样以小端 16 位写入，能原样读回（含负数与极值）', () {
      final samples = Int16List.fromList([1234, -4321, 32767, -32768]);
      final bytes = encodeWav(samples);
      final view = ByteData.sublistView(bytes, 44);

      expect(view.getInt16(0, Endian.little), 1234);
      expect(view.getInt16(2, Endian.little), -4321);
      expect(view.getInt16(4, Endian.little), 32767);
      expect(view.getInt16(6, Endian.little), -32768);
    });

    test('两处长度字段自洽：RIFF = 36 + 数据长度', () {
      final bytes = encodeWav(Int16List(10));
      final view = ByteData.sublistView(bytes);

      expect(view.getUint32(4, Endian.little), 36 + 20);
      expect(view.getUint32(40, Endian.little), 20);
    });
  });

  group('DTMF 按键音', () {
    test('十二个键都能合成出非静音的波形', () {
      for (final key in dtmfKeys) {
        final tone = buildDtmfTone(key);
        expect(tone, isNotEmpty, reason: '$key 没有生成采样');

        final peak = tone.fold<int>(0, (m, s) => s.abs() > m ? s.abs() : m);
        expect(peak, greaterThan(1000), reason: '$key 几乎是静音');
      }
    });

    test('时长贴近设定的 55ms', () {
      final tone = buildDtmfTone(NokiaKey.k5, sampleRate: 44100);
      final ms = tone.length / 44100 * 1000;
      expect(ms, closeTo(dtmfDurationMs, 1.0));
    });

    test('不同按键的波形确实不同，说明频率表没写重', () {
      final a = buildDtmfTone(NokiaKey.k1);
      final b = buildDtmfTone(NokiaKey.k2);

      expect(a.length, b.length);
      var differs = false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) {
          differs = true;
          break;
        }
      }
      expect(differs, isTrue, reason: 'k1 与 k2 生成了完全相同的波形');
    });

    test('软键不属于 DTMF 键，应当报错而不是静默出音', () {
      expect(() => buildDtmfTone(NokiaKey.softLeft), throwsArgumentError);
    });

    test('包络把首尾压到接近零——这是消掉起止爆音的关键', () {
      final tone = buildDtmfTone(NokiaKey.k5);
      expect(tone.first.abs(), lessThan(300));
      expect(tone.last.abs(), lessThan(300));
    });
  });

  group('音符', () {
    test('A4（音号 69）等于 440Hz', () {
      expect(midiToFreq(69), closeTo(440, 0.001));
    });

    test('相差一个八度，频率正好翻倍/减半', () {
      expect(midiToFreq(81), closeTo(880, 0.01));
      expect(midiToFreq(57), closeTo(220, 0.01));
    });

    test('编辑器音域的两端都能正常合成', () {
      for (final midi in [composerLowMidi, composerHighMidi]) {
        final tone = buildNoteTone(midi);
        expect(tone, isNotEmpty);
        expect(tone.first.abs(), lessThan(300));
        expect(tone.last.abs(), lessThan(300));
      }
    });
  });
}
