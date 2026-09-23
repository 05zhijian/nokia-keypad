import 'dart:typed_data';

/// 把 16 位单声道 PCM 采样包装成一份完整的内存 WAV 文件。
///
/// flutter_soloud 的 `loadMem` 接受「手工生成的 WAV 字节序列」，但它不会替我们
/// 猜裸 PCM 的采样率与位深，所以这里补上 44 字节的标准 PCM 头。
Uint8List encodeWav(
  Int16List samples, {
  int sampleRate = 44100,
  int channels = 1,
}) {
  const bitsPerSample = 16;
  const bytesPerSample = bitsPerSample ~/ 8;
  final dataSize = samples.length * bytesPerSample;
  final out = ByteData(44 + dataSize);

  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  out.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');

  ascii(12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // fmt chunk 长度
  out.setUint16(20, 1, Endian.little); // 1 = 未压缩 PCM
  out.setUint16(22, channels, Endian.little);
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  out.setUint16(32, channels * bytesPerSample, Endian.little); // blockAlign
  out.setUint16(34, bitsPerSample, Endian.little);

  ascii(36, 'data');
  out.setUint32(40, dataSize, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    out.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  return out.buffer.asUint8List();
}

/// 给一段采样套上淡入淡出包络，消掉起止处的爆音（click）。
///
/// 直接切断正弦波会在波形上留一个阶跃，听起来是「啪」的一声——
/// 这是仿真按键音最容易露馅的地方。
void applyEnvelope(
  Int16List samples, {
  int sampleRate = 44100,
  double attackMs = 3,
  double releaseMs = 12,
}) {
  final attack = (sampleRate * attackMs / 1000).round();
  final release = (sampleRate * releaseMs / 1000).round();
  final n = samples.length;

  for (var i = 0; i < n; i++) {
    var env = 1.0;
    if (i < attack) {
      env = i / attack;
    }
    final fromEnd = n - 1 - i;
    if (fromEnd < release) {
      final r = fromEnd / release;
      if (r < env) env = r;
    }
    samples[i] = (samples[i] * env).round();
  }
}
