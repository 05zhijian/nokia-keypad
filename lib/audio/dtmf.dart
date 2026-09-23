import 'dart:math' as math;
import 'dart:typed_data';

import '../model/nokia_key.dart';
import 'wav.dart';

/// DTMF 双音频率表（ITU-T Q.23 / E.161）。
///
/// 每个按键音 = 一个行频 + 一个列频的正弦叠加。这正是老式电话拨号音的机制，
/// 也是诺基亚按键音听起来「对」的原因——随便放一个单频 beep 会立刻出戏。
const _rowFreq = <NokiaKey, double>{
  NokiaKey.k1: 697, NokiaKey.k2: 697, NokiaKey.k3: 697,
  NokiaKey.k4: 770, NokiaKey.k5: 770, NokiaKey.k6: 770,
  NokiaKey.k7: 852, NokiaKey.k8: 852, NokiaKey.k9: 852,
  NokiaKey.star: 941, NokiaKey.k0: 941, NokiaKey.hash: 941,
};

const _colFreq = <NokiaKey, double>{
  NokiaKey.k1: 1209, NokiaKey.k4: 1209, NokiaKey.k7: 1209, NokiaKey.star: 1209,
  NokiaKey.k2: 1336, NokiaKey.k5: 1336, NokiaKey.k8: 1336, NokiaKey.k0: 1336,
  NokiaKey.k3: 1477, NokiaKey.k6: 1477, NokiaKey.k9: 1477, NokiaKey.hash: 1477,
};

/// 按键音时长。太长会拖泥带水，太短听不出音高，50ms 附近最像。
const dtmfDurationMs = 55.0;

Int16List buildDtmfTone(
  NokiaKey key, {
  int sampleRate = 44100,
  double ms = dtmfDurationMs,
}) {
  final row = _rowFreq[key];
  final col = _colFreq[key];
  if (row == null || col == null) {
    throw ArgumentError('$key 不是 DTMF 按键');
  }

  final n = (sampleRate * ms / 1000).round();
  final out = Int16List(n);

  // 两个正弦叠加后峰值会到 2.0，各给 0.38 留出余量避免削顶失真。
  const amp = 0.38;

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final s = math.sin(2 * math.pi * row * t) + math.sin(2 * math.pi * col * t);
    out[i] = (s * amp * 32767).round();
  }

  applyEnvelope(out, sampleRate: sampleRate, attackMs: 3, releaseMs: 10);
  return out;
}

Uint8List buildDtmfWav(NokiaKey key, {int sampleRate = 44100}) => encodeWav(
      buildDtmfTone(key, sampleRate: sampleRate),
      sampleRate: sampleRate,
    );
