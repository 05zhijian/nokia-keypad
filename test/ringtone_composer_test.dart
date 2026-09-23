import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/model/note_token.dart';
import 'package:nokia/state/ringtone_composer.dart';

void main() {
  late RingtoneComposer composer;

  setUp(() => composer = RingtoneComposer());

  test('初始是空的，用默认时值与八度', () {
    expect(composer.isEmpty, isTrue);
    expect(composer.duration, defaultComposerDuration);
    expect(composer.octave, defaultComposerOctave);
    expect(composer.sharp, isFalse);
  });

  group('落音符', () {
    test('按音高键会带上当前设置', () {
      composer.duration = 8;
      composer.octave = 6;
      composer.sharp = true;

      final note = composer.pressPitch(3);
      expect(note.duration, 8);
      expect(note.octave, 6);
      expect(note.sharp, isTrue);
      expect(composer.notes, [note]);
    });

    test('休止符不带升号', () {
      composer.sharp = true;
      final rest = composer.pressRest();
      expect(rest.isRest, isTrue);
      expect(rest.sharp, isFalse);
    });
  });

  group('时值调整', () {
    test('8 缩短一档', () {
      composer.duration = 4;
      composer.shorten();
      expect(composer.duration, 8);
    });

    test('9 加长一档', () {
      composer.duration = 8;
      composer.lengthen();
      expect(composer.duration, 4);
    });

    test('缩短到三十二分就停住', () {
      composer.duration = 32;
      composer.shorten();
      expect(composer.duration, 32);
    });

    test('加长到全音符就停住', () {
      composer.duration = 1;
      composer.lengthen();
      expect(composer.duration, 1);
    });
  });

  group('八度', () {
    test('循环切换，到顶绕回', () {
      composer.octave = composerOctaves.last;
      composer.cycleOctave();
      expect(composer.octave, composerOctaves.first);
    });

    test('每一档都落在可选范围内', () {
      for (var i = 0; i < composerOctaves.length * 2; i++) {
        composer.cycleOctave();
        expect(composerOctaves, contains(composer.octave));
      }
    });
  });

  test('# 切换升号', () {
    composer.toggleSharp();
    expect(composer.sharp, isTrue);
    composer.toggleSharp();
    expect(composer.sharp, isFalse);
  });

  group('退格与清空', () {
    test('退格只退一个音', () {
      composer.pressPitch(1);
      composer.pressPitch(2);
      composer.backspace();
      expect(composer.notes, hasLength(1));
      expect(composer.notes.single.pitch, 1);
    });

    test('空的时候退格不报错', () {
      composer.backspace();
      expect(composer.isEmpty, isTrue);
    });

    test('clear 连设置一起复位', () {
      composer.duration = 16;
      composer.octave = 6;
      composer.sharp = true;
      composer.pressPitch(1);

      composer.clear();
      expect(composer.isEmpty, isTrue);
      expect(composer.duration, defaultComposerDuration);
      expect(composer.octave, defaultComposerOctave);
      expect(composer.sharp, isFalse);
    });

    test('load 会替换整段并复位设置', () {
      composer.pressPitch(1);
      composer.load(const [
        NoteToken(duration: 8, pitch: 3, octave: 6),
        NoteToken(duration: 4, pitch: 2, octave: 5),
      ]);
      expect(composer.notes, hasLength(2));
      expect(composer.notes.first.pitch, 3);
    });
  });

  group('屏幕写法', () {
    test('待落下的音符只写时值与升号', () {
      composer.duration = 8;
      expect(composer.pendingLabel, '8');
      composer.toggleSharp();
      expect(composer.pendingLabel, '8#');
    });

    test('序列末尾始终带着待落下的那个', () {
      composer.duration = 4;
      composer.pressPitch(1);
      composer.pressPitch(2);
      expect(composer.displayTokens(), ['41', '42', '4']);
    });
  });
}
