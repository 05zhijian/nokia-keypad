import 'dart:math' as math;
import 'dart:typed_data';

import 'wav.dart';

/// 十二平均律：MIDI 音号 → 频率（A4 = 音号 69 = 440Hz）。
double midiToFreq(int midi) =>
    440.0 * math.pow(2, (midi - 69) / 12).toDouble();

/// 铃声编辑器要用的音域：C4(60) 到 B6(95)，共三个八度。
/// 诺基亚 Composer 的音域大致就是这些，再多也没人弹得到。
const composerLowMidi = 60;
const composerHighMidi = 95;

/// 单个音符的默认时长。编辑器里用 8 / 9 键改时值。
const noteDurationMs = 300.0;

Int16List buildNoteTone(
  int midi, {
  int sampleRate = 44100,
  double ms = noteDurationMs,
}) {
  final freq = midiToFreq(midi);
  final n = (sampleRate * ms / 1000).round();
  final out = Int16List(n);

  // 诺基亚的单音是方波底子的，但纯方波太刺耳。这里用正弦保证可听性，
  // 后面若要更还原，把波形换成方波即可（见 README 的调音说明）。
  const amp = 0.42;

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    out[i] = (math.sin(2 * math.pi * freq * t) * amp * 32767).round();
  }

  // 淡出跟着时长缩放。固定的 60ms 淡出会把一个 180ms 的八分音符吃掉三分之一，
  // 听起来像被吞了尾巴。
  final releaseMs = math.min(60.0, ms * 0.25);
  applyEnvelope(out, sampleRate: sampleRate, attackMs: 5, releaseMs: releaseMs);
  return out;
}

Uint8List buildNoteWav(
  int midi, {
  int sampleRate = 44100,
  double ms = noteDurationMs,
}) =>
    encodeWav(
      buildNoteTone(midi, sampleRate: sampleRate, ms: ms),
      sampleRate: sampleRate,
    );
