import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/audio/nokia_tune.dart';
import 'package:nokia/state/phone_state.dart';
import 'package:nokia/theme/nokia_colors.dart';
import 'package:nokia/theme/nokia_font.dart';
import 'package:nokia/theme/nokia_metrics.dart';
import 'package:nokia/utils/lcd_text.dart';
import 'package:nokia/widgets/key_cap.dart';
import 'package:nokia/widgets/phone_body.dart';

/// 版式快照。
///
/// 这里手动把像素字体载进测试环境——否则 `flutter test` 会拿默认字体，
/// 中文全渲染成占位方块，快照就失去了核对意义。
///
/// 注意：快照在测试环境栅格化，与真机的缩放路径不完全一致，所以它用来核对
/// **版式、比例、配色**，最终手感仍以真机为准。
/// 重新生成：`flutter test --update-goldens test/layout_golden_test.dart`
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader(nokiaFontFamily)
      ..addFont(rootBundle.load(
        'assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf',
      ));
    await loader.load();
  });

  Future<void> pumpPhone(WidgetTester tester, Size logical) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = logical * 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: PhoneBody(
            content: LcdContent(
              lines: ['无内鬼', '抓紧上车', '讯息：'],
              softLeft: '显示',
              softRight: '退出',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 渲染一屏给定的内容并出快照。
  Future<void> pumpScreen(
    WidgetTester tester,
    LcdContent content,
    String goldenPath,
  ) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(554 * 2, 1170 * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: PhoneBody(content: content),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(PhoneBody), matchesGoldenFile(goldenPath));
  }

  testWidgets('参考图比例下的整体版式', (tester) async {
    // 与参考图同比例：554 × 1170。
    await pumpPhone(tester, const Size(554, 1170));

    await expectLater(
      find.byType(PhoneBody),
      matchesGoldenFile('goldens/phone_reference_aspect.png'),
    );
  });

  testWidgets('长屏手机上键盘铺到底，下方不留空白', (tester) async {
    // 模拟一台 20:9 的手机（400 × 890 逻辑像素），比参考图更长。
    // 这是回归测试：早先按等比装箱渲染时，多出来的高度全堆在下方成了空白。
    await pumpPhone(tester, const Size(400, 890));

    await expectLater(
      find.byType(PhoneBody),
      matchesGoldenFile('goldens/phone_tall_aspect.png'),
    );
  });

  testWidgets('主菜单的反白高亮', (tester) async {
    // 反白（底色与字色对调）是诺基亚在单色屏上表达「选中」的方式，
    // 也是这一阶段新加的视觉元素，单独出一张快照盯住。
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(554 * 2, 1170 * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: PhoneBody(
            content: LcdContent(
              // 从真实的菜单树取，别硬编码——否则加了菜单项快照也发现不了，
              // 而「项变多了还放不放得下」正是这张快照要盯的东西。
              lines: [for (final node in rootMenu) node.label],
              highlightedLine: 1,
              softLeft: '选择',
              softRight: '退出',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PhoneBody),
      matchesGoldenFile('goldens/phone_menu.png'),
    );
  });

  testWidgets('编辑屏：正文折行与大小写提示', (tester) async {
    // 折行位置必须和 LCD 实际渲染的字号对得上，这里用一张快照盯住。
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(554 * 2, 1170 * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: PhoneBody(
            content: LcdContent(
              lines: ['无内鬼，抓紧上', '车。今晚八点，', '老地方，_'],
              softLeft: '发送',
              softRight: '清除',
              capsLabel: 'abc',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PhoneBody),
      matchesGoldenFile('goldens/phone_compose.png'),
    );
  });

  testWidgets('来电屏', (tester) async {
    // 来电是全屏的：状态栏、号码、两个软键。用来确认号码放得下、
    // 且没有信封之类的待机残留。
    await pumpScreen(
      tester,
      const LcdContent(
        lines: ['来电', '', '妈妈'],
        softLeft: '接听',
        softRight: '拒接',
      ),
      'goldens/phone_incoming_call.png',
    );
  });

  testWidgets('通话中屏', (tester) async {
    await pumpScreen(
      tester,
      const LcdContent(
        lines: ['通话中', '', '01:23'],
        softRight: '挂断',
      ),
      'goldens/phone_in_call.png',
    );
  });

  testWidgets('通讯录列表', (tester) async {
    // 渲染路径和主菜单一样（行 + 反白），所以这张盯的不是列表本身，
    // 而是「假来电」这个**三字**软键标签和「返回」并排时放不放得下——
    // 别处的软键标签都是两个字。
    await pumpScreen(
      tester,
      const LcdContent(
        lines: ['妈妈', '张伟', '老板', '李娜'],
        highlightedLine: 1,
        softLeft: '假来电',
        softRight: '返回',
      ),
      'goldens/phone_contacts.png',
    );
  });

  testWidgets('键帽必须颗颗一致', (tester) async {
    // 这条盯的是「一致性」而不是「做旧」。
    //
    // 曾经给每颗键不同的明度/色相想做旧，结果被读成「亮度不一致」——
    // 用户明确要求调一致。所以五颗键**必须长得完全一样**，
    // 这张快照就是防止以后又把色差加回去。
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(560 * 2, 180 * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: NokiaColors.body,
          body: Center(
            child: Row(
              key: const ValueKey('keyRow'),
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 5; i++)
                  const KeyCap(
                    width: 96,
                    height: 96,
                    radius: numKeyRadius,
                    pressed: false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('keyRow')),
      matchesGoldenFile('goldens/keycaps_identical.png'),
    );
  });

  testWidgets('铃声编辑器：记号序列与八度提示', (tester) async {
    // 编辑器屏有个别处没有的东西：正文是**记号序列**而不是自然语言，
    // 末尾那个 `4` 是还没落下的半成品（诺基亚的当前设置就是这么显示的）。
    // 快照用来确认折行不会把记号拆断、八度提示在状态栏里放得下。
    final tokens = [for (final note in nokiaTune()) note.label, '4'];
    final lines = wrapTokensForLcd(tokens, columns: lcdColumns)
        .take(maxLcdLines)
        .toList();

    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(554 * 2, 1170 * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: PhoneBody(
            content: LcdContent(
              lines: lines,
              softLeft: '播放',
              softRight: '清除',
              capsLabel: 'o5',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PhoneBody),
      matchesGoldenFile('goldens/phone_composer.png'),
    );
  });
}
