import '../model/note_token.dart';

/// 铃声编辑器的编辑状态。
///
/// 按键语义照搬诺基亚 Composer：`1`-`7` 落音符，`8` 缩短、`9` 加长，
/// `*` 换八度，`#` 升半音，`0` 是休止。时值与八度是「当前设置」，
/// 作用于**下一个**落下的音符。
class RingtoneComposer {
  final notes = <NoteToken>[];

  int duration = defaultComposerDuration;
  int octave = defaultComposerOctave;
  bool sharp = false;

  /// 正在编辑、还没落下的那个音符的写法（如 `8#`）。
  ///
  /// 诺基亚的音符是逐字符敲出来的，屏幕上总会带着这么个半成品——
  /// 它同时也是「当前设置」的可视化，省掉单独一行状态。
  String get pendingLabel => '$duration${sharp ? '#' : ''}';

  bool get isEmpty => notes.isEmpty;

  /// 落下一个音高键（1-7）。返回刚落下的音符，供边按边响。
  NoteToken pressPitch(int pitch) {
    final note = NoteToken(
      duration: duration,
      pitch: pitch,
      octave: octave,
      sharp: sharp,
    );
    notes.add(note);
    return note;
  }

  /// 落下休止符。
  NoteToken pressRest() {
    final note = NoteToken(
      duration: duration,
      pitch: 0,
      octave: octave,
    );
    notes.add(note);
    return note;
  }

  void shorten() {
    final index = composerDurations.indexOf(duration);
    if (index >= 0 && index < composerDurations.length - 1) {
      duration = composerDurations[index + 1];
    }
  }

  void lengthen() {
    final index = composerDurations.indexOf(duration);
    if (index > 0) duration = composerDurations[index - 1];
  }

  void cycleOctave() {
    final index = composerOctaves.indexOf(octave);
    octave = composerOctaves[(index + 1) % composerOctaves.length];
  }

  void toggleSharp() => sharp = !sharp;

  void backspace() {
    if (notes.isNotEmpty) notes.removeLast();
  }

  void clear() {
    notes.clear();
    duration = defaultComposerDuration;
    octave = defaultComposerOctave;
    sharp = false;
  }

  /// 载入一段预置旋律（如诺基亚铃声）。
  void load(Iterable<NoteToken> preset) {
    clear();
    notes.addAll(preset);
  }

  /// 屏幕上的写法序列，末尾带上半成品。
  List<String> displayTokens() => [
        for (final note in notes) note.label,
        pendingLabel,
      ];
}
