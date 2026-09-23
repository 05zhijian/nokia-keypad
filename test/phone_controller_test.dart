import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/audio/nokia_tune.dart';
import 'package:nokia/contacts/contacts_source.dart';
import 'package:nokia/model/navi.dart';
import 'package:nokia/model/nokia_key.dart';
import 'package:nokia/model/note_token.dart';
import 'package:nokia/state/phone_controller.dart';
import 'package:nokia/state/phone_state.dart';

/// 界面状态机的测试。
///
/// 这一层是纯逻辑，不碰音频也不碰真机，能完整验证——导航层级走不走得通、
/// 软键语义对不对、未读状态有没有正确清除、T9 的提交时机对不对。
void main() {
  late PhoneController c;

  setUp(() => c = PhoneController());
  tearDown(() => c.dispose());

  /// 退到待机层（开机那屏是短信通知，退一下就是待机）。
  void goStandby() {
    c.softLeft(); // 显示
    c.softRight(); // 返回
  }

  /// 进入主菜单顶层。
  void goRootMenu() {
    goStandby();
    c.softLeft(); // 功能表
  }

  /// 进入「信息」子菜单。
  void goMessagesMenu() {
    goRootMenu();
    c.navi(NaviDirection.select);
  }

  /// 进入「写信息」编辑屏。
  void goCompose() {
    goMessagesMenu();
    c.navi(NaviDirection.select);
  }

  /// 进入「铃声编辑器」子菜单（顶层第 3 项）。
  void goRingtoneMenu() {
    goRootMenu();
    c.navi(NaviDirection.down);
    c.navi(NaviDirection.down);
    c.navi(NaviDirection.select);
  }

  /// 进入预置的诺基亚铃声。
  void goNokiaTune() {
    goRingtoneMenu();
    c.navi(NaviDirection.select);
  }

  /// 进入空白编辑器。
  void goBlankRingtone() {
    goRingtoneMenu();
    c.navi(NaviDirection.down);
    c.navi(NaviDirection.select);
  }

  group('初始状态', () {
    test('开屏停在参考图那一屏：新短信通知', () {
      expect(c.state, isA<SmsNotification>());
      expect(c.content.lines, ['无内鬼', '抓紧上车', '讯息：']);
      expect(c.content.softLeft, '显示');
      expect(c.content.softRight, '退出');
    });

    test('有未读时状态栏亮信封', () {
      expect(c.content.showEnvelope, isTrue);
    });
  });

  group('读短信', () {
    test('左软键「显示」进入正文', () {
      c.softLeft();
      expect(c.state, isA<SmsView>());
    });

    test('读过之后未读清掉', () {
      expect(c.hasUnread, isTrue);
      c.softLeft();
      expect(c.hasUnread, isFalse);
    });

    test('右软键「返回」回到待机，信封随之熄灭', () {
      c.softLeft();
      c.softRight();
      expect(c.state, isA<Standby>());
      expect(c.content.showEnvelope, isFalse);
    });

    test('导航键能往下翻正文，翻到底就停住', () {
      c.softLeft();
      expect(c.content.lines.first, inboxBody.first);

      c.navi(NaviDirection.down);
      expect(c.content.lines.first, inboxBody[1]);

      for (var i = 0; i < 10; i++) {
        c.navi(NaviDirection.down);
      }
      expect(c.content.lines.first, inboxBody.last);
    });
  });

  group('待机与菜单树', () {
    test('待机画面给的是功能表 / 电话簿', () {
      goStandby();
      expect(c.state, isA<Standby>());
      expect(c.content.softLeft, '功能表');
      expect(c.content.softRight, '电话簿');
    });

    test('左软键进主菜单，默认选中第一项', () {
      goRootMenu();
      expect(c.state, isA<MenuOpen>());
      expect(c.content.highlightedLine, 0);
      expect(c.content.lines, ['信息', '通话记录', '铃声编辑器', '设置', '假来电']);
    });

    test('选中「信息」展开子菜单，而不是直接进功能屏', () {
      goMessagesMenu();
      final state = c.state;
      expect(state, isA<MenuOpen>());
      expect(c.content.lines, ['写信息', '收件箱']);
      expect(c.content.highlightedLine, 0);
    });

    test('子菜单右软键退回上一层菜单', () {
      goMessagesMenu();
      c.softRight();
      expect(c.state, isA<MenuOpen>());
      expect(c.content.lines.first, '信息', reason: '应当回到顶层菜单');
    });

    test('导航键上下移动选中项，且首尾循环', () {
      goRootMenu();
      final count = (c.state as MenuOpen).items.length;

      c.navi(NaviDirection.down);
      expect((c.state as MenuOpen).selected, 1);

      c.navi(NaviDirection.up);
      expect((c.state as MenuOpen).selected, 0);

      // 从第一项再往上，应该绕到最后一项
      c.navi(NaviDirection.up);
      expect((c.state as MenuOpen).selected, count - 1);
    });

    test('子菜单的循环只在本级内绕，不会串到顶层', () {
      goMessagesMenu();
      c.navi(NaviDirection.up);
      expect((c.state as MenuOpen).selected, 1, reason: '子菜单只有两项，往上应绕到第 2 项');
      expect(c.content.lines, ['写信息', '收件箱']);
    });

    test('选中未实现的功能进占位屏，并能返回', () {
      goRootMenu();
      c.navi(NaviDirection.down); // 移到「通话记录」
      c.navi(NaviDirection.select);

      expect(c.state, isA<NotImplemented>());
      expect(c.content.lines.first, '通话记录');

      c.softRight();
      expect(c.state, isA<MenuOpen>());
    });

    test('占位屏带上版本号，方便分辨装的是哪个包', () {
      c.version = '1.4.0+4';
      goRootMenu();
      c.navi(NaviDirection.down);
      c.navi(NaviDirection.select);
      expect(c.content.lines, contains('v1.4.0+4'));
    });
  });

  group('写信息与 T9', () {
    test('进入编辑屏，正文为空且默认小写', () {
      goCompose();
      expect(c.state, isA<Compose>());
      expect(c.content.softLeft, '发送');
      expect(c.content.softRight, '清除');
      expect(c.content.capsLabel, 'abc');
    });

    test('按键出字母，换键落定', () {
      goCompose();
      c.digit(NokiaKey.k4); // g
      c.digit(NokiaKey.k4); // h
      c.digit(NokiaKey.k3); // 换键：h 落定，d 待定
      expect(c.input.text, 'h');
      expect(c.input.display, 'hd');
    });

    test('# 切大小写，状态栏提示跟着变', () {
      goCompose();
      expect(c.content.capsLabel, 'abc');
      c.digit(NokiaKey.hash);
      expect(c.content.capsLabel, 'ABC');
    });

    test('右软键在编辑态是「清除」而不是返回', () {
      goCompose();
      c.digit(NokiaKey.k2);
      c.digit(NokiaKey.k3); // a 落定，d 还挂在待定里
      expect(c.input.text, 'a');
      expect(c.input.pendingLetter, 'd');

      c.softRight(); // 第一次退格：退掉待定的 d
      expect(c.state, isA<Compose>(), reason: '不该退回菜单');
      expect(c.input.pendingLetter, '');
      expect(c.input.text, 'a', reason: '落定的正文这一下不该被动');

      c.softRight(); // 第二次退格：才轮到正文里的 a
      expect(c.input.text, '');
    });

    test('左软键「发送」进确认屏', () {
      goCompose();
      c.digit(NokiaKey.k2);
      c.softLeft();
      expect(c.state, isA<MessageSent>());
      expect(c.content.lines, ['信息已发送']);
    });

    test('发送时会把连按中的字母一并落定，不会丢字', () {
      goCompose();
      c.digit(NokiaKey.k2);
      c.digit(NokiaKey.k2); // b 还挂在待定里
      c.softLeft(); // 发送
      expect(c.input.text, 'b', reason: '待定字母必须在发送前落定');
    });

    test('确认屏返回直接回待机', () {
      goCompose();
      c.digit(NokiaKey.k2);
      c.softLeft();
      c.softRight();
      expect(c.state, isA<Standby>());
    });

    test('红键从编辑态直接回待机——编辑态右软键被占用，没它就是死路', () {
      goCompose();
      c.hangUp();
      expect(c.state, isA<Standby>());
    });

    test('数字键在非编辑态不产出任何东西', () {
      c.digit(NokiaKey.k2);
      expect(c.input.display, '');
      expect(c.state, isA<SmsNotification>());
    });

    test('连按超时后字母自动落定', () async {
      final controller = PhoneController(
        t9CommitDelay: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      // 走到编辑屏
      controller.softLeft();
      controller.softRight();
      controller.softLeft();
      controller.navi(NaviDirection.select);
      controller.navi(NaviDirection.select);
      expect(controller.state, isA<Compose>());

      controller.digit(NokiaKey.k5);
      expect(controller.input.text, '', reason: '刚按下还不该落定');

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(controller.input.text, 'j', reason: '超时后应当自动落定');
    });
  });

  group('铃声编辑器', () {
    test('「铃声编辑器」展开成两个子项', () {
      goRingtoneMenu();
      expect(c.state, isA<MenuOpen>());
      expect(c.content.lines, ['诺基亚铃声', '自己编']);
    });

    test('「诺基亚铃声」载入预置旋律并进编辑屏', () {
      goNokiaTune();
      expect(c.state, isA<ComposerOpen>());
      expect(c.composer.notes, hasLength(nokiaTuneNotation.length));
      expect(c.composer.notes.first.notation, '83@6');
    });

    test('「自己编」是空的', () {
      goBlankRingtone();
      expect(c.state, isA<ComposerOpen>());
      expect(c.composer.isEmpty, isTrue);
    });

    test('编辑屏软键是播放 / 清除，状态栏显示八度', () {
      goBlankRingtone();
      expect(c.content.softLeft, '播放');
      expect(c.content.softRight, '清除');
      expect(c.content.capsLabel, 'o$defaultComposerOctave');
    });

    test('按 1 落下 C 音', () {
      goBlankRingtone();
      c.digit(NokiaKey.k1);
      expect(c.composer.notes, hasLength(1));
      expect(c.composer.notes.single.pitch, 1);
      expect(c.composer.notes.single.midi, 72, reason: '默认八度 5，所以是 C5');
    });

    test('8 缩短时值，屏幕上的半成品跟着变', () {
      goBlankRingtone();
      expect(c.composer.pendingLabel, '4');
      c.digit(NokiaKey.k8);
      expect(c.composer.pendingLabel, '8');
    });

    test('# 切升号', () {
      goBlankRingtone();
      c.digit(NokiaKey.hash);
      expect(c.composer.pendingLabel, '4#');
    });

    test('* 换八度，状态栏跟着变', () {
      goBlankRingtone();
      final before = c.composer.octave;
      c.digit(NokiaKey.star);
      expect(c.composer.octave, isNot(before));
      expect(c.content.capsLabel, 'o${c.composer.octave}');
    });

    test('右软键退掉最后一个音', () {
      goBlankRingtone();
      c.digit(NokiaKey.k1);
      c.digit(NokiaKey.k2);
      expect(c.composer.notes, hasLength(2));

      c.softRight();
      expect(c.composer.notes, hasLength(1));
    });

    test('左软键切到停止，再按切回播放', () {
      goNokiaTune();
      expect(c.content.softLeft, '播放');

      c.softLeft();
      expect(c.content.softLeft, '停止');
      expect(c.isPlaying, isTrue);

      c.softLeft();
      expect(c.content.softLeft, '播放');
      expect(c.isPlaying, isFalse);
    });

    test('导航键也能触发播放，和左软键一致', () {
      goNokiaTune();
      c.navi(NaviDirection.select);
      expect(c.isPlaying, isTrue);
    });

    test('编辑动作会打断正在播的旋律', () {
      goNokiaTune();
      c.softLeft();
      expect(c.isPlaying, isTrue);

      c.digit(NokiaKey.k1);
      expect(c.isPlaying, isFalse, reason: '边改边响会乱');
    });

    test('空编辑器按播放是空操作，不该卡在播放态', () {
      goBlankRingtone();
      c.softLeft();
      expect(c.isPlaying, isFalse);
    });

    test('红键从编辑屏回待机', () {
      goNokiaTune();
      c.hangUp();
      expect(c.state, isA<Standby>());
    });

    test('从编辑屏返回菜单也会掐掉正在播的旋律', () {
      goNokiaTune();
      c.softLeft();
      expect(c.isPlaying, isTrue);

      c.navi(NaviDirection.right); // 菜单的返回语义
      expect(c.isPlaying, isFalse);
    });
  });

  group('通讯录与假来电', () {
    /// 从待机右软键（「电话簿」）进通讯录，并等异步加载跑完。
    Future<void> openContacts(PhoneController controller) async {
      controller.softLeft(); // 显示（读完短信通知）
      controller.softRight(); // 返回 → 待机
      controller.softRight(); // 电话簿
      await pumpEventQueue();
    }

    /// 走到「以通讯录里第 [index] 个人来电」。
    Future<void> triggerFakeCall(
      PhoneController controller, {
      int index = 0,
    }) async {
      await openContacts(controller);
      for (var i = 0; i < index; i++) {
        controller.navi(NaviDirection.down);
      }
      controller.softLeft();
    }

    PhoneController withContacts(List<String> names) =>
        PhoneController(contactsSource: _FakeContactsSource(_ready(names)));

    group('列表', () {
      test('从待机右软键进通讯录，读到名字', () async {
        final controller = withContacts(['妈妈', '张伟', '老板']);
        addTearDown(controller.dispose);

        await openContacts(controller);
        expect(controller.state, isA<ContactsOpen>());
        expect(controller.content.lines, ['妈妈', '张伟', '老板']);
        expect(controller.content.highlightedLine, 0);
        expect(controller.content.softLeft, '假来电');
        expect(controller.content.softRight, '返回');
      });

      test('读取过程中先显示「读取通讯录…」', () {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        // 只触发，不等加载完成
        controller.softLeft();
        controller.softRight();
        controller.softRight();
        expect(controller.content.lines, ['读取通讯录…']);
      });

      test('授权被拒时给出提示，并且没有「假来电」这个动作', () async {
        final controller = PhoneController(
          contactsSource: const _FakeContactsSource(
            ContactsResult(status: ContactsStatus.denied),
          ),
        );
        addTearDown(controller.dispose);

        await openContacts(controller);
        expect(controller.content.lines.first, '未授权通讯录');
        expect(controller.content.softLeft, '', reason: '读不到人就不该提供发起来电');
      });

      test('读取失败也有提示，不是一片空白', () async {
        final controller = PhoneController(
          contactsSource: const _FakeContactsSource(
            ContactsResult(status: ContactsStatus.failed),
          ),
        );
        addTearDown(controller.dispose);

        await openContacts(controller);
        expect(controller.content.lines.first, '读取通讯录失败');
      });

      test('通讯录为空时给出提示', () async {
        final controller = withContacts([]);
        addTearDown(controller.dispose);

        await openContacts(controller);
        expect(controller.content.lines, ['通讯录为空']);
        expect(controller.content.softLeft, '');
      });

      test('上下移动选中项，到头就夹住而不是循环', () async {
        // 通讯录动辄几百条，从第一条按上键跳到最末条会很恼人——
        // 这一点和主菜单不同，主菜单短，循环才方便。
        final controller = withContacts(['妈妈', '张伟', '老板']);
        addTearDown(controller.dispose);

        await openContacts(controller);
        controller.navi(NaviDirection.up);
        expect((controller.state as ContactsOpen).selected, 0, reason: '到头夹住');

        controller.navi(NaviDirection.down);
        controller.navi(NaviDirection.down);
        expect((controller.state as ContactsOpen).selected, 2);

        controller.navi(NaviDirection.down);
        expect((controller.state as ContactsOpen).selected, 2, reason: '到底夹住');
      });

      test('条目多于屏高时开窗口，选中项始终在窗口里', () async {
        final names = [for (var i = 0; i < 20; i++) '联系人$i'];
        final controller = withContacts(names);
        addTearDown(controller.dispose);

        await openContacts(controller);
        for (var i = 0; i < 15; i++) {
          controller.navi(NaviDirection.down);
        }

        final content = controller.content;
        expect(content.lines, hasLength(maxLcdLines));
        final highlighted = content.highlightedLine!;
        expect(highlighted, inInclusiveRange(0, content.lines.length - 1));
        expect(content.lines[highlighted], '联系人15',
            reason: '反白的那一行必须就是选中的人');
      });

      test('长名字折行，不会超出屏宽', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        expect(controller.content.lines, ['来电', '', '妈妈']);
      });

      test('特别长的名字折成两行而不是被裁掉', () async {
        final controller = withContacts(['张三李四王五赵六钱七']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        final lines = controller.content.lines;
        expect(lines.first, '来电');
        expect(lines.length, greaterThan(3), reason: '长名字应当占两行');
        expect(lines.sublist(2).join(), '张三李四王五赵六钱七');
      });
    });

    group('发起来电', () {
      test('来电屏显示的是通讯录里的真人名，不是号码', () async {
        final controller = withContacts(['妈妈', '张伟']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller, index: 1);
        expect(controller.state, isA<IncomingCall>());
        expect(controller.content.lines, ['来电', '', '张伟']);
        expect(controller.content.softLeft, '接听');
        expect(controller.content.softRight, '拒接');
      });

      test('来的是选中的那个人', () async {
        final controller = withContacts(['妈妈', '张伟', '老板']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller, index: 2);
        expect(controller.content.lines.last, '老板');
      });

      test('菜单里的「假来电」也是进通讯录选人，不是随机来一发', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        controller.softLeft(); // 显示
        controller.softRight(); // 返回 → 待机
        controller.softLeft(); // 功能表
        for (var i = 0; i < 4; i++) {
          controller.navi(NaviDirection.down);
        }
        controller.navi(NaviDirection.select);
        await pumpEventQueue();

        expect(controller.state, isA<ContactsOpen>());
        expect(controller.content.lines, ['妈妈']);
      });

      test('通讯录为空时按左软键不会发起来电', () async {
        final controller = withContacts([]);
        addTearDown(controller.dispose);

        await openContacts(controller);
        controller.softLeft();
        expect(controller.state, isA<ContactsOpen>());
        expect(controller.isPlaying, isFalse);
      });

      test('来电时铃音开始循环', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        expect(controller.isPlaying, isTrue);
      });

      test('绿键接听，铃音立刻停', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.answerCall();
        expect(controller.state, isA<InCall>());
        expect(controller.isPlaying, isFalse, reason: '接听后铃音必须停，否则通话里还在响');
      });

      test('左软键也是接听', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.softLeft();
        expect(controller.state, isA<InCall>());
      });

      test('导航键在来电时无动作——真机的拨轮也不接电话', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.navi(NaviDirection.select);
        controller.navi(NaviDirection.down);
        expect(controller.state, isA<IncomingCall>());
        expect(controller.isPlaying, isTrue, reason: '铃音该继续响');
      });

      test('红键拒接，直接回待机并掐掉铃音', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.hangUp();
        expect(controller.state, isA<Standby>());
        expect(controller.isPlaying, isFalse);
      });

      test('右软键拒接', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.softRight();
        expect(controller.state, isA<Standby>());
        expect(controller.isPlaying, isFalse);
      });

      test('通话屏从 00:00 起，软键是挂断', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.answerCall();
        expect(controller.content.lines, ['通话中', '', '00:00']);
        expect(controller.content.softRight, '挂断');
        expect(controller.content.softLeft, '', reason: '通话中左软键没有动作');
      });

      test('红键挂断，显示这一通打了多久', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.answerCall();
        controller.hangUp();
        expect(controller.state, isA<CallEnded>());
        expect(controller.content.lines.first, '通话结束');
      });

      test('通话结束后返回 → 待机', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.answerCall();
        controller.hangUp();
        controller.softRight();
        expect(controller.state, isA<Standby>());
      });

      test('挂断后计时归零，下一通从 00:00 重新开始', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.answerCall();
        controller.hangUp();
        expect(controller.callSeconds, 0);
      });

      test('计时器会推进，屏幕上的时间跟着走', () async {
        // 用很短的刷新间隔，不必为了验证计时器真的等满一秒。
        final controller = PhoneController(
          callTickInterval: const Duration(milliseconds: 20),
          contactsSource: _FakeContactsSource(_ready(['妈妈'])),
        );
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.answerCall();
        expect(controller.callSeconds, 0);

        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(controller.callSeconds, greaterThanOrEqualTo(3));
        expect(controller.content.lines.last, isNot('00:00'));
      });

      test('计时在挂断后停下，不会继续跑', () async {
        final controller = PhoneController(
          callTickInterval: const Duration(milliseconds: 20),
          contactsSource: _FakeContactsSource(_ready(['妈妈'])),
        );
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.answerCall();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        controller.hangUp();

        final frozen = controller.callSeconds;
        final shown = controller.content.lines.last;
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(controller.callSeconds, frozen, reason: '挂断后计时不该继续');
        expect(controller.content.lines.last, shown, reason: '结束屏的时长应当定格');
      });

      test('来电时按数字键不改变屏幕', () async {
        final controller = withContacts(['妈妈']);
        addTearDown(controller.dispose);

        await triggerFakeCall(controller);
        controller.digit(NokiaKey.k5);
        expect(controller.state, isA<IncomingCall>());
      });
    });

    test('非来电状态下按绿键没有任何反应', () {
      expect(c.state, isA<SmsNotification>());
      c.answerCall();
      expect(c.state, isA<SmsNotification>());
    });
  });

  group('模拟拨号', () {
    /// 走到拨号盘：待机 → 绿键。
    void openDialer(PhoneController controller) {
      controller.softLeft(); // 显示（读完短信通知）
      controller.softRight(); // 返回 → 待机
      controller.greenKey();
    }

    /// 敲一串号码。
    void type(PhoneController controller, String digits) {
      for (final ch in digits.split('')) {
        controller.digit(switch (ch) {
          '1' => NokiaKey.k1,
          '2' => NokiaKey.k2,
          '3' => NokiaKey.k3,
          '4' => NokiaKey.k4,
          '5' => NokiaKey.k5,
          '6' => NokiaKey.k6,
          '7' => NokiaKey.k7,
          '8' => NokiaKey.k8,
          '9' => NokiaKey.k9,
          '*' => NokiaKey.star,
          '#' => NokiaKey.hash,
          _ => NokiaKey.k0,
        });
      }
    }

    test('待机按绿键打开拨号盘，初始是空的', () {
      openDialer(c);
      expect(c.state, isA<DialerOpen>());
      expect(c.content.lines, ['输入号码']);
      expect(c.content.softLeft, '', reason: '没号码时不该给「呼叫」');
      expect(c.content.softRight, '返回');
    });

    test('按数字键输入号码', () {
      openDialer(c);
      type(c, '138');
      expect((c.state as DialerOpen).number, '138');
      expect(c.content.lines, ['138']);
      expect(c.content.softLeft, '呼叫');
      expect(c.content.softRight, '清除');
    });

    test('星号和井号也能输进号码里', () {
      openDialer(c);
      type(c, '*#21');
      expect((c.state as DialerOpen).number, '*#21');
    });

    test('号码长度有上限，一直按不会把屏幕撑爆', () {
      openDialer(c);
      type(c, List.filled(40, '1').join());
      expect(
        (c.state as DialerOpen).number.length,
        PhoneController.maxDialLength,
      );
    });

    test('右软键退格，退到空就变成返回', () {
      openDialer(c);
      type(c, '12');
      c.softRight();
      expect((c.state as DialerOpen).number, '1');

      c.softRight(); // 退到空
      expect((c.state as DialerOpen).number, '');
      expect(c.content.softRight, '返回');

      c.softRight(); // 空盘上再按就是返回
      expect(c.state, isA<Standby>());
    });

    test('左软键拨出，进入呼叫中并显示号码', () {
      openDialer(c);
      type(c, '10086');
      c.softLeft();
      expect(c.state, isA<Calling>());
      expect(c.content.lines, ['呼叫中', '', '10086']);
      expect(c.content.softRight, '挂断');
    });

    test('号码为空时按呼叫不动作', () {
      openDialer(c);
      c.softLeft();
      expect(c.state, isA<DialerOpen>());
    });

    test('绿键在拨号盘里也是拨出', () {
      openDialer(c);
      type(c, '10086');
      c.greenKey();
      expect(c.state, isA<Calling>());
    });

    test('导航中键也是拨出，和左软键一致', () {
      openDialer(c);
      type(c, '10086');
      c.navi(NaviDirection.select);
      expect(c.state, isA<Calling>());
    });

    test('呼叫中按红键取消，直接回待机', () {
      openDialer(c);
      type(c, '10086');
      c.softLeft();
      c.hangUp();
      expect(c.state, isA<Standby>());
    });

    test('呼叫中按右软键也是挂断', () {
      openDialer(c);
      type(c, '10086');
      c.softLeft();
      c.softRight();
      expect(c.state, isA<Standby>());
    });

    test('呼叫中左软键没有动作——这一屏只能挂断', () {
      openDialer(c);
      type(c, '10086');
      c.softLeft();
      expect(c.content.softLeft, '');
      c.softLeft();
      expect(c.state, isA<Calling>());
    });

    test('拨出后等一会儿会自动接通，计时从 00:00 开始', () async {
      final controller = PhoneController(
        callConnectDelay: const Duration(milliseconds: 30),
      );
      addTearDown(controller.dispose);

      openDialer(controller);
      type(controller, '10086');
      controller.softLeft();
      expect(controller.state, isA<Calling>());

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(controller.state, isA<InCall>());
      expect(controller.content.lines.last, '00:00');
    });

    test('呼叫中等不到接通就被挂断，不会迟到接通', () async {
      final controller = PhoneController(
        callConnectDelay: const Duration(milliseconds: 30),
      );
      addTearDown(controller.dispose);

      openDialer(controller);
      type(controller, '10086');
      controller.softLeft();
      controller.hangUp(); // 立刻挂断

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(controller.state, isA<Standby>(),
          reason: '挂断后那个定时器不该再把电话接起来');
    });

    test('拨出的电话也能正常挂断并显示时长', () async {
      final controller = PhoneController(
        callConnectDelay: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      openDialer(controller);
      type(controller, '10086');
      controller.softLeft();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(controller.state, isA<InCall>());

      controller.hangUp();
      expect(controller.state, isA<CallEnded>());
      expect(controller.content.lines.first, '通话结束');
    });

    test('红键从拨号盘直接回待机', () {
      openDialer(c);
      type(c, '138');
      c.hangUp();
      expect(c.state, isA<Standby>());
    });

    test('拨号盘里按绿键前先打字，屏幕上跟着显示', () {
      openDialer(c);
      type(c, '10086');
      expect(c.content.lines.single, '10086');
    });
  });

  test('待机层的红键不改变任何状态', () {
    // 注意：红键才是「任何时候回待机」的那个键。待机层的**右软键**现在
    // 是「电话簿」，按它会进通讯录，不再是空动作。
    goStandby();
    c.hangUp();
    expect(c.state, isA<Standby>());
  });
}

ContactsResult _ready(List<String> names) =>
    ContactsResult(status: ContactsStatus.ready, names: names);

/// 假的通讯录源。真机那个要过系统权限与平台通道，测试里根本跑不了；
/// 换成这个，整条「加载 → 列表 → 选人 → 来电」的链路都能验证。
class _FakeContactsSource implements ContactsSource {
  const _FakeContactsSource(this.result);

  final ContactsResult result;

  @override
  Future<ContactsResult> load() async => result;
}
