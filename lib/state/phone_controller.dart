import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
import '../audio/nokia_tune.dart';
import '../contacts/contacts_source.dart';
import '../model/navi.dart';
import '../model/nokia_key.dart';
import '../model/note_token.dart';
import '../theme/nokia_metrics.dart';
import '../utils/lcd_text.dart';
import 'phone_state.dart';
import 'ringtone_composer.dart';
import 't9_input.dart';

/// 界面状态机。
///
/// 用一个**栈**建模诺基亚的层级导航：入栈 = 进入下一层，右软键出栈 = 返回。
/// 栈空时就是待机层，此时右软键不再返回——这是诺基亚真实的行为。
class PhoneController extends ChangeNotifier {
  PhoneController({
    this.t9CommitDelay = const Duration(milliseconds: 900),
    this.callTickInterval = const Duration(seconds: 1),
    this.callConnectDelay = const Duration(seconds: 4),
    this.ringbackInterval = const Duration(seconds: 3),
    ContactsSource? contactsSource,
  }) : contactsSource = contactsSource ?? const EmptyContactsSource();

  /// 连按同一个键多久算一个字母结束，超过就落定。真机约 1 秒。
  final Duration t9CommitDelay;

  /// 通话计时的刷新间隔。做成参数是为了测试能用很短的一档，
  /// 不必为了验证计时器真的等满一秒。
  final Duration callTickInterval;

  /// 拨出后多久「接通」。同样是为了测试不用真等四秒。
  final Duration callConnectDelay;

  /// 拨号时铃回音的间隔。
  final Duration ringbackInterval;

  /// 通讯录数据源。默认是空实现——真机的那个要过系统权限与平台通道，
  /// 不该在测试里被碰到，由 main 注入。
  final ContactsSource contactsSource;

  /// 号码最多个位数，和真机一样有上限，免得一直按把屏幕撑爆。
  static const maxDialLength = 20;

  /// 编辑器里一个全音符多长。
  ///
  /// 诺基亚铃声约 b=180，即四分音符 333ms；这里取 1440ms（四分 360ms），
  /// 稍慢一点更好听，也还在原来的味道里。
  static const wholeNoteMs = 1440;

  /// 导航栈。开屏就是参考图拍的那屏：一条新短信通知。
  /// 注意它必须是**压在待机之上**的一层，而不是待机本身——否则按返回时
  /// 栈已空，就退不回待机画面了。
  final _stack = <PhoneUiState>[const SmsNotification()];

  /// 栈空时显示的屏，也就是待机画面。
  PhoneUiState _root = const Standby();

  final _input = T9Input();
  final _composer = RingtoneComposer();

  bool _hasUnread = true;
  Timer? _t9Timer;
  Timer? _callTimer;
  Timer? _connectTimer;
  Timer? _ringbackTimer;
  int _callSeconds = 0;
  String _version = '';

  /// 播放代次。每次开始或打断播放都自增，正在跑的那轮循环发现代次变了就退出。
  /// 这比维护一个「停止标志」可靠——连续快速点播放不会留下两个循环在跑。
  int _playToken = 0;
  bool _playing = false;

  PhoneUiState get state => _stack.isEmpty ? _root : _stack.last;

  bool get hasUnread => _hasUnread;

  T9Input get input => _input;

  RingtoneComposer get composer => _composer;

  bool get isPlaying => _playing;

  int get callSeconds => _callSeconds;

  /// 版本号，显示在占位屏上当构建标记。由 main 从 package_info 读进来，
  /// 不在这里写死，免得和 pubspec 各存一份而走样。
  String get version => _version;

  set version(String value) {
    if (value == _version) return;
    _version = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _t9Timer?.cancel();
    _callTimer?.cancel();
    _connectTimer?.cancel();
    _ringbackTimer?.cancel();
    _playToken++;
    super.dispose();
  }

  // ---- 栈操作 ----

  void _push(PhoneUiState next) {
    _stack.add(next);
    notifyListeners();
  }

  void _pop() {
    if (_stack.isEmpty) return;
    _stopPlayback();
    _stack.removeLast();
    notifyListeners();
  }

  void _replaceTop(PhoneUiState next) {
    if (_stack.isEmpty) {
      _root = next;
    } else {
      _stack[_stack.length - 1] = next;
    }
    notifyListeners();
  }

  /// 直接回待机。
  void _reset() {
    _t9Timer?.cancel();
    _callTimer?.cancel();
    _callTimer = null;
    _callSeconds = 0;
    _stopPlayback();
    _stack.clear();
    notifyListeners();
  }

  // ---- 输入 ----

  /// 左软键。语义随屏幕变化，由 [content] 给出的标签决定。
  void softLeft() {
    switch (state) {
      case SmsNotification():
        // 读了就不再是未读，待机画面的信封随之熄灭。
        // 用「替换」而不是「入栈」：通知被正文顶掉，从正文返回时直接落到待机。
        _hasUnread = false;
        _replaceTop(const SmsView());

      case Standby():
        _push(const MenuOpen(items: rootMenu));

      case Compose():
        _send();

      case ComposerOpen():
        if (_playing) {
          _stopPlayback();
        } else {
          unawaited(_playSequence(_composer.notes));
        }

      case IncomingCall():
        answerCall();

      case DialerOpen():
        placeCall();

      case ContactsOpen(:final status, :final names, :final selected):
        // 只有真读到人才能发起假来电——加载中、被拒授权、通讯录为空时，
        // 左软键是无动作的（屏幕上也不会显示「假来电」这个标签）。
        if (status == ContactsStatus.ready && names.isNotEmpty) {
          startFakeCall(callerName: names[selected]);
        }

      case MenuOpen(:final items, :final selected):
        _activate(items[selected]);

      case SmsView():
      case MessageSent():
      case InCall():
      // 呼叫中左软键没有动作——这一屏只能挂断。
      case Calling():
      case CallEnded():
      case NotImplemented():
        break;
    }
  }

  /// 右软键。编辑态下它是「清除」，来电时是「拒接」，其余是诺基亚的「返回」。
  void softRight() {
    switch (state) {
      case Compose():
        _input.backspace();
        notifyListeners();

      case ComposerOpen():
        // 编辑态右软键也是「清除」——退掉最后落下的那个音符。
        // 想整段重来就一路退，或从菜单重进「自己编」。
        _stopPlayback();
        _composer.backspace();
        notifyListeners();

      case IncomingCall():
        rejectCall();

      case InCall():
      case Calling():
        endCall();

      case DialerOpen(:final number):
        // 拨号盘的右软键是「清除」。号码已经空了就当「返回」用，
        // 否则用户会卡在一个空拨号盘里出不去（红键虽然也能退，但不够直觉）。
        if (number.isEmpty) {
          _pop();
        } else {
          _replaceTop(
            DialerOpen(number: number.substring(0, number.length - 1)),
          );
          notifyListeners();
        }

      case MessageSent():
      case CallEnded():
        _reset();

      case Standby():
        // 待机画面的右软键是「电话簿」。
        unawaited(openContacts());

      case SmsNotification():
      case SmsView():
      case MenuOpen():
      case ContactsOpen():
      case NotImplemented():
        _pop();
    }
  }

  /// 挂断键（红）。
  ///
  /// 诺基亚上它也兼作「退出」，任何时候按都能回到待机——这是编辑态唯一的出路
  /// （右软键被「清除」占用了）。但在来电/通话时它的语义是「拒接」/「挂断」。
  void hangUp() {
    switch (state) {
      case IncomingCall():
        rejectCall();
      case InCall():
      case Calling():
        endCall();
      case CallEnded():
        _reset();
      default:
        _reset();
    }
  }

  void navi(NaviDirection direction) {
    switch (state) {
      case SmsNotification():
        if (direction == NaviDirection.select) softLeft();

      case Standby():
        if (direction == NaviDirection.select) {
          _push(const MenuOpen(items: rootMenu));
        }

      case SmsView(:final scroll):
        switch (direction) {
          case NaviDirection.up || NaviDirection.left:
            _replaceTop(SmsView(scroll: _clampScroll(scroll - 1)));
          case NaviDirection.down || NaviDirection.right:
            _replaceTop(SmsView(scroll: _clampScroll(scroll + 1)));
          case NaviDirection.select:
            break;
        }

      case MenuOpen(:final items, :final selected):
        switch (direction) {
          case NaviDirection.up:
            _replaceTop(MenuOpen(
              items: items,
              selected: _wrap(selected - 1, items.length),
            ));
          case NaviDirection.down:
            _replaceTop(MenuOpen(
              items: items,
              selected: _wrap(selected + 1, items.length),
            ));
          case NaviDirection.select || NaviDirection.left:
            _activate(items[selected]);
          case NaviDirection.right:
            _pop();
        }

      case Compose():
        // 把连按中的字母落定，然后才换字。
        _input.commitPending();
        notifyListeners();

      case ComposerOpen():
        // 导航键当播放/停止用，和左软键一致。
        softLeft();

      case ContactsOpen(:final status, :final names, :final selected):
        switch (direction) {
          case NaviDirection.up:
            _replaceTop(_contactsAt(status, names, selected - 1));
          case NaviDirection.down:
            _replaceTop(_contactsAt(status, names, selected + 1));
          case NaviDirection.select || NaviDirection.left:
            softLeft();
          case NaviDirection.right:
            _pop();
        }

      case DialerOpen():
        // 导航中键等同「呼叫」。
        if (direction == NaviDirection.select) placeCall();

      case MessageSent():
      case IncomingCall():
      case InCall():
      case Calling():
      case CallEnded():
      case NotImplemented():
        break;
    }
  }

  /// 数字键。在编辑态、铃声编辑器、来电里语义不同。
  void digit(NokiaKey key) {
    switch (state) {
      case Compose():
        _input.press(key);
        _restartCommitTimer();
        notifyListeners();

      case ComposerOpen():
        _composerKey(key);

      case DialerOpen(:final number):
        final char = _dialChar(key);
        // 号码有长度上限，和真机一样——一直按下去不该把屏幕撑爆。
        if (char == null || number.length >= maxDialLength) break;
        _replaceTop(DialerOpen(number: number + char));
        notifyListeners();

      case SmsNotification():
      case Standby():
      case SmsView():
      case MenuOpen():
      case MessageSent():
      case NotImplemented():
      case IncomingCall():
      case InCall():
      case Calling():
      case ContactsOpen():
        // 通话中按数字键也有 DTMF 音——那是按键本身发的，见 NokiaKeyButton，
        // 不需要这里再做什么，但也不该改变屏幕。
        break;

      case CallEnded():
        break;
    }
  }

  // ---- 通讯录与假来电 ----

  /// 打开通讯录：先亮「读取中」，读完再换成列表或错误提示。
  ///
  /// 异步放在这里而不是 UI 层：读通讯录要过权限弹窗，可能几秒才回来，
  /// 期间界面得先有东西显示。
  Future<void> openContacts() async {
    _push(const ContactsOpen());
    final result = await contactsSource.load();
    // 读的过程中用户可能已经退出去了，这时不要再改屏幕。
    if (state is! ContactsOpen) return;
    _replaceTop(ContactsOpen(status: result.status, names: result.names));
  }

  /// 触发一通假来电，来电屏显示 [callerName]。
  void startFakeCall({required String callerName}) {
    _callSeconds = 0;
    _push(IncomingCall(callerName: callerName));
    unawaited(_playSequence(nokiaTune(), loop: true));
  }

  /// 接听（绿键 / 左软键）。铃音停，开始计时。
  void answerCall() {
    if (state is! IncomingCall) return;
    _stopPlayback();
    _beginCall();
  }

  /// 拒接（红键 / 右软键）。铃音停，直接回待机。
  void rejectCall() {
    if (state is! IncomingCall) return;
    _reset();
  }

  /// 挂断（红键 / 右软键）。通话中停表并显示时长；呼叫中则是取消呼叫。
  void endCall() {
    switch (state) {
      case InCall():
        _callTimer?.cancel();
        _callTimer = null;
        _stopPlayback();
        _replaceTop(CallEnded(seconds: _callSeconds));
        _callSeconds = 0;

      case Calling():
        _stopRingback();
        _connectTimer?.cancel();
        _reset();

      default:
        break;
    }
  }

  /// 接通：从这一刻起开始计时。来电接听和拨出接通走的是同一条路。
  void _beginCall() {
    _callSeconds = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(callTickInterval, (_) {
      if (state is! InCall) return;
      _callSeconds++;
      _replaceTop(InCall(seconds: _callSeconds));
    });
    _replaceTop(const InCall());
  }

  // ---- 模拟拨号 ----

  /// 绿键。来电时是接听，待机时打开拨号盘，拨号盘里是拨出。
  void greenKey() {
    switch (state) {
      case IncomingCall():
        answerCall();
      case DialerOpen():
        placeCall();
      case Standby():
        openDialer();
      default:
        // 其余屏幕（菜单、编辑、通话中……）绿键没有动作。
        break;
    }
  }

  void openDialer() => _push(const DialerOpen());

  /// 拨出。号码为空时不动作。
  void placeCall() {
    final current = state;
    if (current is! DialerOpen || current.number.isEmpty) return;

    _replaceTop(Calling(number: current.number));
    _startRingback();

    _connectTimer?.cancel();
    _connectTimer = Timer(callConnectDelay, () {
      // 等的过程中用户可能已经挂断了。
      if (state is! Calling) return;
      _stopRingback();
      _beginCall();
    });
  }

  /// 铃回音：拨出后听到的「嘟——嘟——」。
  ///
  /// A4（440Hz）、三秒一响，和真机的铃回音一致。没有它的话「呼叫中」这屏
  /// 是死寂的，完全不像在打电话。
  void _startRingback() {
    _stopRingback();
    _playRingbackTone();
    _ringbackTimer =
        Timer.periodic(ringbackInterval, (_) => _playRingbackTone());
  }

  void _playRingbackTone() {
    unawaited(NokiaAudio.instance.playNote(
      _ringbackMidi,
      durationMs: _ringbackToneMs,
    ));
  }

  void _stopRingback() {
    _ringbackTimer?.cancel();
    _ringbackTimer = null;
    NokiaAudio.instance.stopCurrent();
  }

  static const _ringbackMidi = 69; // A4 = 440Hz
  static const _ringbackToneMs = 1000;

  // ---- 铃声编辑器 ----

  void _composerKey(NokiaKey key) {
    // 任何编辑动作都先掐掉正在播的旋律——边改边响会乱。
    _stopPlayback();

    switch (key) {
      case NokiaKey.k1:
      case NokiaKey.k2:
      case NokiaKey.k3:
      case NokiaKey.k4:
      case NokiaKey.k5:
      case NokiaKey.k6:
      case NokiaKey.k7:
        final note = _composer.pressPitch(_pitchOf(key));
        final midi = note.midi;
        if (midi != null) {
          unawaited(NokiaAudio.instance.playNote(
            midi,
            durationMs: note.durationMs(wholeNoteMs),
          ));
        }

      case NokiaKey.k0:
        _composer.pressRest();

      case NokiaKey.k8:
        _composer.shorten();

      case NokiaKey.k9:
        _composer.lengthen();

      case NokiaKey.star:
        _composer.cycleOctave();

      case NokiaKey.hash:
        _composer.toggleSharp();

      default:
        break;
    }
    notifyListeners();
  }

  /// 数字键 1-7 对应 C D E F G A B。
  int _pitchOf(NokiaKey key) => switch (key) {
        NokiaKey.k1 => 1,
        NokiaKey.k2 => 2,
        NokiaKey.k3 => 3,
        NokiaKey.k4 => 4,
        NokiaKey.k5 => 5,
        NokiaKey.k6 => 6,
        _ => 7,
      };

  /// 拨号盘上的字符。`*` 和 `#` 在真实号码里是合法的，所以也算。
  String? _dialChar(NokiaKey key) => switch (key) {
        NokiaKey.k0 => '0',
        NokiaKey.k1 => '1',
        NokiaKey.k2 => '2',
        NokiaKey.k3 => '3',
        NokiaKey.k4 => '4',
        NokiaKey.k5 => '5',
        NokiaKey.k6 => '6',
        NokiaKey.k7 => '7',
        NokiaKey.k8 => '8',
        NokiaKey.k9 => '9',
        NokiaKey.star => '*',
        NokiaKey.hash => '#',
        _ => null,
      };

  // ---- 旋律播放 ----

  /// 播一段旋律。
  ///
  /// [loop] 为真时循环播放（来电铃音）。打断靠 [_playToken]：每次开始播放都
  /// 自增代次，正在跑的那轮发现代次变了就退出，连续快速触发不会留下两个循环。
  Future<void> _playSequence(
    List<NoteToken> notes, {
    bool loop = false,
  }) async {
    if (notes.isEmpty) return;

    _stopPlayback();
    final token = ++_playToken;
    _setPlaying(true);

    final schedule = [
      for (final note in notes)
        if (note.midi != null)
          (midi: note.midi!, durationMs: note.durationMs(wholeNoteMs)),
    ];

    // 先把缓冲备齐，否则播到没缓存过的时值会当场合成，旋律中间卡一下。
    // 引擎没起来时这两步都是空操作，定时循环照跑——状态机不依赖音频。
    await NokiaAudio.instance.prepareNotes(schedule);
    if (_playToken != token) return;

    do {
      for (final note in notes) {
        if (_playToken != token) return;
        final midi = note.midi;
        if (midi != null) {
          unawaited(NokiaAudio.instance.playNote(
            midi,
            durationMs: note.durationMs(wholeNoteMs),
          ));
        }
        await Future<void>.delayed(
          Duration(milliseconds: note.durationMs(wholeNoteMs)),
        );
      }
    } while (loop && _playToken == token);

    if (_playToken != token) return;
    _setPlaying(false);
  }

  void _stopPlayback() {
    _playToken++;
    NokiaAudio.instance.stopCurrent();
    if (_playing) _setPlaying(false);
  }

  void _setPlaying(bool value) {
    _playing = value;
    if (state is ComposerOpen) {
      _replaceTop(ComposerOpen(playing: value));
    } else {
      notifyListeners();
    }
  }

  // ---- 内部 ----

  /// 连按超时后把待定字母落定。
  ///
  /// 计时器放在这一层而不是 [T9Input] 里：T9Input 保持是纯的，
  /// 测试可以直接调 `commitPending()` 模拟超时，不用伪造时钟。
  void _restartCommitTimer() {
    _t9Timer?.cancel();
    _t9Timer = Timer(t9CommitDelay, () {
      _input.commitPending();
      notifyListeners();
    });
  }

  void _send() {
    _input.commitPending();
    _t9Timer?.cancel();
    _push(const MessageSent());
  }

  void _activate(MenuNode node) {
    switch (node) {
      case SubMenuNode(:final children):
        _push(MenuOpen(items: children));
      case ActionNode(:final action, :final label):
        switch (action) {
          case MenuAction.compose:
            _input.clear();
            _push(const Compose());

          case MenuAction.inbox:
            _push(const SmsView());

          case MenuAction.nokiaTune:
            _composer.load(nokiaTune());
            _push(const ComposerOpen());

          case MenuAction.blankRingtone:
            _composer.clear();
            _push(const ComposerOpen());

          case MenuAction.fakeCall:
            // 不直接来电话，先让人选——整蛊时通常就是想指定某个人，
            // 随机来一个反而不好用。
            unawaited(openContacts());

          case MenuAction.callLog:
          case MenuAction.settings:
            _push(NotImplemented(label));
        }
    }
  }

  int _wrap(int index, int length) => (index % length + length) % length;

  /// 通讯录里移动选中项。**用夹取而不是循环**——通讯录几百条，
  /// 从 A 按一下上键跳到 Z 会很恼人（主菜单那种短列表才适合循环）。
  ContactsOpen _contactsAt(
    ContactsStatus status,
    List<String> names,
    int index,
  ) =>
      ContactsOpen(
        status: status,
        names: names,
        selected: names.isEmpty ? 0 : index.clamp(0, names.length - 1),
      );

  int _clampScroll(int value) => value.clamp(0, inboxBody.length - 1);

  /// `mm:ss`。通话计时和通话结束都用它。
  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  /// 编辑器的正文行。超屏时编辑看结尾（刚敲的在最后），播放看开头（旋律从头走）。
  ///
  /// 用 [wrapTokensForLcd] 而不是按字符折行：记号必须整体换行，
  /// 否则 `87` 会被拆成 `8` 和 `7` 落在两行，看着像两个音符。
  List<String> _composerLines() {
    final lines = wrapTokensForLcd(
      _composer.displayTokens(),
      columns: lcdColumns,
    );
    if (lines.length <= maxLcdLines) return lines;
    return _playing
        ? lines.take(maxLcdLines).toList()
        : lines.sublist(lines.length - maxLcdLines);
  }

  // ---- 状态 → 屏幕内容 ----

  /// 通讯录屏的内容。
  ///
  /// 通讯录可能几百条，一屏只放得下 [maxLcdLines] 行，所以要开一个
  /// 以选中项为中心的窗口，并把选中项换算成窗口内的行号。
  LcdContent _contactsContent(
    ContactsStatus status,
    List<String> names,
    int selected,
  ) {
    switch (status) {
      case ContactsStatus.loading:
        return const LcdContent(lines: ['读取通讯录…'], softRight: '返回');

      case ContactsStatus.denied:
        return const LcdContent(
          lines: ['未授权通讯录', '', '需在系统设置里', '允许读取联系人'],
          softRight: '返回',
        );

      case ContactsStatus.failed:
        return const LcdContent(lines: ['读取通讯录失败'], softRight: '返回');

      case ContactsStatus.ready:
        if (names.isEmpty) {
          return const LcdContent(lines: ['通讯录为空'], softRight: '返回');
        }

        if (names.length <= maxLcdLines) {
          return LcdContent(
            lines: names,
            highlightedLine: selected,
            softLeft: '假来电',
            softRight: '返回',
          );
        }

        final start = (selected - maxLcdLines ~/ 2)
            .clamp(0, names.length - maxLcdLines);
        return LcdContent(
          lines: names.sublist(start, start + maxLcdLines),
          highlightedLine: selected - start,
          softLeft: '假来电',
          softRight: '返回',
        );
    }
  }

  /// 把当前状态映射成 LCD 上要画的东西。
  LcdContent get content {
    switch (state) {
      case Standby():
        return LcdContent(
          lines: const ['中国移动'],
          softLeft: '功能表',
          // 电话簿要等通讯录，先给个标签让待机画面不缺角。
          softRight: '电话簿',
          showEnvelope: _hasUnread,
        );

      case SmsNotification():
        return const LcdContent(
          lines: ['无内鬼', '抓紧上车', '讯息：'],
          softLeft: '显示',
          softRight: '退出',
          showEnvelope: true,
        );

      case SmsView(:final scroll):
        return LcdContent(
          lines: inboxBody.skip(scroll).take(maxLcdLines).toList(),
          softLeft: scroll > 0 ? '上翻' : '',
          softRight: '返回',
        );

      case MenuOpen(:final items, :final selected):
        return LcdContent(
          lines: [for (final node in items) node.label],
          highlightedLine: selected,
          softLeft: '选择',
          softRight: '退出',
          showEnvelope: _hasUnread,
        );

      case Compose():
        return LcdContent(
          // 末尾的下划线当光标用。待提交的字母已经在 display 里了。
          lines: wrapForLcd('${_input.display}_', columns: lcdColumns)
              .take(maxLcdLines)
              .toList(),
          softLeft: '发送',
          softRight: '清除',
          showEnvelope: _hasUnread,
          capsLabel: _input.isUpperCase ? 'ABC' : 'abc',
        );

      case ComposerOpen(:final playing):
        return LcdContent(
          lines: _composerLines(),
          softLeft: playing ? '停止' : '播放',
          softRight: '清除',
          showEnvelope: _hasUnread,
          // 八度是编辑器里唯一不在正文里体现的状态——正文的每个
          // `8#6` 只写了时值与音高，八度藏在状态栏。
          capsLabel: 'o${_composer.octave}',
        );

      case IncomingCall(:final callerName):
        return LcdContent(
          // 通讯录里的名字可能是「张三（公司）」这种长条，折成最多两行
          // 免得超出屏宽被裁掉。
          lines: [
            '来电',
            '',
            ...wrapForLcd(callerName, columns: lcdColumns).take(2),
          ],
          softLeft: '接听',
          softRight: '拒接',
        );

      case ContactsOpen(:final status, :final names, :final selected):
        return _contactsContent(status, names, selected);

      case InCall(:final seconds):
        return LcdContent(
          lines: ['通话中', '', _formatDuration(seconds)],
          softRight: '挂断',
        );

      case CallEnded(:final seconds):
        return LcdContent(
          lines: ['通话结束', '', _formatDuration(seconds)],
          softRight: '返回',
        );

      case DialerOpen(:final number):
        return LcdContent(
          lines: number.isEmpty
              ? const ['输入号码']
              : wrapForLcd(number, columns: lcdColumns)
                  .take(maxLcdLines)
                  .toList(),
          // 号码为空时没有可拨的东西，左软键就不给动作。
          softLeft: number.isEmpty ? '' : '呼叫',
          softRight: number.isEmpty ? '返回' : '清除',
          showEnvelope: _hasUnread,
        );

      case Calling(:final number):
        return LcdContent(
          lines: [
            '呼叫中',
            '',
            ...wrapForLcd(number, columns: lcdColumns).take(2),
          ],
          softRight: '挂断',
        );

      case MessageSent():
        return LcdContent(
          lines: const ['信息已发送'],
          softRight: '返回',
          showEnvelope: _hasUnread,
        );

      case NotImplemented(:final title):
        return LcdContent(
          lines: [
            title,
            '',
            '尚未实现',
            if (_version.isNotEmpty) 'v$_version',
          ],
          softRight: '返回',
          showEnvelope: _hasUnread,
        );
    }
  }
}
