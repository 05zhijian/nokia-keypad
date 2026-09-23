import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/model/note_token.dart';

void main() {
  group('记谱解析', () {
    test('基本形式：时值 + 音 + 八度', () {
      final note = parseNoteToken('86@5');
      expect(note.duration, 8);
      expect(note.pitch, 6);
      expect(note.octave, 5);
      expect(note.sharp, isFalse);
    });

    test('# 表示升半音', () {
      final note = parseNoteToken('8#6@5');
      expect(note.duration, 8);
      expect(note.pitch, 6);
      expect(note.sharp, isTrue);
    });

    test('省略八度时用默认值', () {
      expect(parseNoteToken('86').octave, defaultComposerOctave);
    });

    test('时值是多位数、音高恒为一位，从后往前拆不会歧义', () {
      // 166 = 时值 16、音 6
      final sixteen = parseNoteToken('166@5');
      expect(sixteen.duration, 16);
      expect(sixteen.pitch, 6);

      // 16 = 时值 1、音 6
      final one = parseNoteToken('16@5');
      expect(one.duration, 1);
      expect(one.pitch, 6);
    });

    test('时值 32 也能解析', () {
      final note = parseNoteToken('327@5');
      expect(note.duration, 32);
      expect(note.pitch, 7);
    });

    test('没有音高就报错，而不是静默出一个怪音符', () {
      expect(() => parseNoteToken('#@5'), throwsFormatException);
    });
  });

  group('写出', () {
    test('label 不带八度，notation 带', () {
      const note = NoteToken(duration: 8, pitch: 6, octave: 5, sharp: true);
      expect(note.label, '8#6');
      expect(note.notation, '8#6@5');
    });

    test('解析与写出能往返', () {
      for (final notation in ['86@5', '8#6@5', '166@4', '26@6', '40@5']) {
        expect(parseNoteToken(notation).notation, notation);
      }
    });

    test('休止符标成 0', () {
      const rest = NoteToken(duration: 4, pitch: 0, octave: 5);
      expect(rest.isRest, isTrue);
      expect(rest.label, '40');
    });
  });

  group('MIDI 音号', () {
    test('C4 是 60（中央 C）', () {
      expect(const NoteToken(duration: 4, pitch: 1, octave: 4).midi, 60);
    });

    test('A4 是 69（440Hz 那个）', () {
      expect(const NoteToken(duration: 4, pitch: 6, octave: 4).midi, 69);
    });

    test('E6 是 88', () {
      expect(const NoteToken(duration: 8, pitch: 3, octave: 6).midi, 88);
    });

    test('升半音就是加一', () {
      const natural = NoteToken(duration: 4, pitch: 1, octave: 4);
      const sharp = NoteToken(duration: 4, pitch: 1, octave: 4, sharp: true);
      expect(sharp.midi! - natural.midi!, 1);
    });

    test('休止符没有音高', () {
      expect(const NoteToken(duration: 4, pitch: 0, octave: 5).midi, isNull);
    });
  });

  group('时长换算', () {
    const whole = 1440;

    test('时值分母越大，音越短', () {
      expect(const NoteToken(duration: 1, pitch: 1, octave: 4).durationMs(whole), 1440);
      expect(const NoteToken(duration: 2, pitch: 1, octave: 4).durationMs(whole), 720);
      expect(const NoteToken(duration: 4, pitch: 1, octave: 4).durationMs(whole), 360);
      expect(const NoteToken(duration: 8, pitch: 1, octave: 4).durationMs(whole), 180);
    });
  });
}
