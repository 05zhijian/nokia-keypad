/// 音高 1-7 相对 C 的半音偏移。
const _pitchSemitones = <int, int>{1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11};

/// 铃声编辑器默认的时值（四分音符）与八度。
const defaultComposerDuration = 4;
const defaultComposerOctave = 5;

/// 可选时值：全音符、二分、四分、八分、十六分、三十二分。
const composerDurations = <int>[1, 2, 4, 8, 16, 32];

/// 可用八度。上界要和音频层的音符表对得上（C4-B6）。
const composerOctaves = <int>[4, 5, 6];

/// 铃声编辑器里的一个音符。
///
/// 记谱沿用诺基亚 Composer 的写法 `{时值}{#}{音}`，例如 `8#6`；
/// 八度在真机上是隐含状态，这里显式记下来（`@5`），否则没法回放。
class NoteToken {
  const NoteToken({
    required this.duration,
    required this.pitch,
    required this.octave,
    this.sharp = false,
  });

  /// 时值分母：1 全音符、2 二分、4 四分、8 八分、16 十六分、32 三十二分。
  final int duration;

  /// 音高：1-7 = C D E F G A B；0 = 休止。
  final int pitch;

  /// 八度。C4 是中央 C。
  final int octave;

  /// 升半音。真机上 E(3) 和 B(7) 不能升——它们升上去就是 F 和 C，
  /// 该直接换音名，所以这里不做限制，由使用者负责。
  final bool sharp;

  bool get isRest => pitch == 0;

  /// 屏幕上的写法，例如 `8#6`。
  String get label => '$duration${sharp ? '#' : ''}$pitch';

  /// 带八度的完整记谱，例如 `8#6@5`。
  String get notation => '$label@$octave';

  /// MIDI 音号。休止符没有音高。
  int? get midi {
    if (isRest) return null;
    final semitone = _pitchSemitones[pitch];
    if (semitone == null) return null;
    return (octave + 1) * 12 + semitone + (sharp ? 1 : 0);
  }

  /// 在以 [wholeNoteMs] 为全音符基准时的持续时长。
  int durationMs(int wholeNoteMs) => wholeNoteMs ~/ duration;

  @override
  String toString() => notation;

  @override
  bool operator ==(Object other) =>
      other is NoteToken &&
      other.duration == duration &&
      other.pitch == pitch &&
      other.octave == octave &&
      other.sharp == sharp;

  @override
  int get hashCode => Object.hash(duration, pitch, octave, sharp);
}

/// 解析一条 Composer 记谱。
///
/// 格式 `{时值}[#]{音}[@八度]`。时值是多位数（1/2/4/8/16/32）而音高恒为一位
/// （0-7），所以从后往前拆不会歧义：`166@5` 是「时值 16、音 6」，
/// `16@5` 是「时值 1、音 6」——和真机的写法一致。
NoteToken parseNoteToken(String notation) {
  var body = notation;
  var octave = defaultComposerOctave;

  final at = body.indexOf('@');
  if (at >= 0) {
    octave = int.parse(body.substring(at + 1));
    body = body.substring(0, at);
  }

  final sharp = body.contains('#');
  body = body.replaceAll('#', '');

  if (body.isEmpty) {
    throw FormatException('记谱缺少音高与时值：$notation');
  }

  final pitch = int.parse(body.substring(body.length - 1));
  final durationText = body.substring(0, body.length - 1);
  final duration =
      durationText.isEmpty ? defaultComposerDuration : int.parse(durationText);

  return NoteToken(
    duration: duration,
    pitch: pitch,
    octave: octave,
    sharp: sharp,
  );
}
