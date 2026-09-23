import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../model/nokia_key.dart';
import 'dtmf.dart';
import 'tones.dart';

/// 按键音与音符的合成引擎。
///
/// 核心设计：**按键瞬间不做任何 PCM 计算**。所有音频在启动时或首次使用时
/// 合成好、常驻内存，按下时只剩一次 `play()`。这是整个「手感」的地基——
/// 如果每次按键都现算双音，延迟就压不住，按键音会明显慢半拍。
class NokiaAudio {
  NokiaAudio._();
  static final NokiaAudio instance = NokiaAudio._();

  static const _sampleRate = 44100;

  final _dtmf = <NokiaKey, AudioSource>{};

  /// 音符缓冲按 `音高:时长` 缓存。时值不同就是不同的缓冲，
  /// 因为淡出包络跟着时长缩放（见 [buildNoteTone]）。
  final _notes = <String, AudioSource>{};

  /// 当前正在响的音符，用来实现单音播放。
  SoundHandle? _currentNote;

  bool _ready = false;

  bool get isReady => _ready;

  /// 启动时只预载 12 个按键音——它们必须零延迟。
  ///
  /// 音符不在这里预载：`loadMem` 每次调用都会 `compute()` 起一个 isolate，
  /// 几十个音符会把启动拖到几秒。编辑器对首个音符的延迟不敏感，改为按需加载。
  Future<void> init() async {
    if (_ready) return;

    // bufferSize 直接决定音频延迟。默认 2048 太大，按键会明显拖后。
    // 512 是延迟与欠载的折中；若真机出现爆音，回调到 1024。
    await SoLoud.instance.init(
      sampleRate: _sampleRate,
      bufferSize: 512,
      channels: Channels.mono,
    );

    for (final key in dtmfKeys) {
      _dtmf[key] = await SoLoud.instance.loadMem(
        'dtmf_${key.name}.wav',
        buildDtmfWav(key, sampleRate: _sampleRate),
      );
    }

    _ready = true;
  }

  /// 按键音。软键 / 导航键 / 通话键本来就不发声，静默返回。
  void playKey(NokiaKey key) {
    final source = _dtmf[key];
    if (source != null) unawaited(SoLoud.instance.play(source));
  }

  /// 弹一个音。[durationMs] 决定缓冲长度。
  ///
  /// 引擎没起来就静默跳过。音频不该是逻辑的前置条件——测试环境里没有原生库，
  /// 真机上音频也可能初始化失败（main 里是吞掉异常照常启动的），
  /// 那种情况下按键仍然要能走完状态机，不能崩。
  Future<void> playNote(int midi, {required int durationMs}) async {
    if (!_ready) return;
    _playMonophonic(await _noteSource(midi, durationMs));
  }

  /// 播放整段旋律之前，把用到的缓冲一次备齐。
  ///
  /// 不预热的话，播到某个没缓存过的时值会当场 `loadMem`（起 isolate），
  /// 旋律中间会明显卡一下。
  Future<void> prepareNotes(
    Iterable<({int midi, int durationMs})> notes,
  ) async {
    if (!_ready) return;
    for (final note in notes) {
      await _noteSource(note.midi, note.durationMs);
    }
  }

  /// 掐掉当前正在响的音。
  ///
  /// 诺基亚是单音的，同时响两个音会糊成一片；而且旋律播放被打断时，
  /// 不掐掉的话旧音会拖在新音后面。
  void stopCurrent() {
    final handle = _currentNote;
    _currentNote = null;
    if (handle == null) return;
    // 这个 handle 可能已经播完了，停一个已结束的音会报错，吞掉即可。
    unawaited(SoLoud.instance.stop(handle).catchError((_) {}));
  }

  Future<AudioSource> _noteSource(int midi, int durationMs) async {
    final key = '$midi:$durationMs';
    final cached = _notes[key];
    if (cached != null) return cached;

    final source = await SoLoud.instance.loadMem(
      'note_${midi}_$durationMs.wav',
      buildNoteWav(midi, sampleRate: _sampleRate, ms: durationMs.toDouble()),
    );
    _notes[key] = source;
    return source;
  }

  void _playMonophonic(AudioSource source) {
    stopCurrent();
    unawaited(
      SoLoud.instance.play(source).then((handle) => _currentNote = handle),
    );
  }

  Future<void> dispose() async {
    for (final source in _dtmf.values) {
      await SoLoud.instance.disposeSource(source);
    }
    for (final source in _notes.values) {
      await SoLoud.instance.disposeSource(source);
    }
    _dtmf.clear();
    _notes.clear();
    _currentNote = null;
    SoLoud.instance.deinit();
    _ready = false;
  }
}
