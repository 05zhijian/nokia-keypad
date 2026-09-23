import 'package:flutter_test/flutter_test.dart';
import 'package:nokia/theme/nokia_metrics.dart';

/// 键盘几何的测试。
///
/// 这几条盯的都是**用户在真机上实际反馈过的问题**，不是凭空造的约束——
/// 布局参数的改动很容易在某个屏宽下把它们重新撞坏。
void main() {
  // 基准行位置（长屏上会被撑开，但相对关系不变）。
  const blockTop = softRowTop;
  final blockBottom = callRowTop + callKeySize.height;
  final naviCenter = (blockTop + blockBottom) / 2;

  test('导航键落在四颗键围出的方块正中间', () {
    // 上缘到软键排顶、下缘到通话排底，距离相等。
    final naviTop = naviCenter - naviKeyHeight / 2;
    final naviBottom = naviCenter + naviKeyHeight / 2;

    expect(naviTop - blockTop, closeTo(blockBottom - naviBottom, 0.001),
        reason: '上下留白应当相等，否则会显得偏上或偏下');
  });

  test('导航键底部和第一排数字键之间留出足够空隙', () {
    // 「它太靠近 2 了」是用户实际反馈。撑满方块时这条缝只剩 8 个单位。
    final naviBottom = naviCenter + naviKeyHeight / 2;
    expect(numRowY.first - naviBottom, greaterThan(20));
  });

  test('导航键水平居中', () {
    expect(naviKeyLeft + naviKeyWidth / 2, closeTo(designWidth / 2, 0.001));
  });

  test('导航键不比方块还高，否则会顶到屏幕或数字键', () {
    expect(naviKeyHeight, lessThanOrEqualTo(blockBottom - blockTop));
  });

  test('导航键和两侧软键不重叠', () {
    final softLeftRight = 24 + softKeySize.width;
    final softRightLeft = designWidth - 24 - softKeySize.width;

    expect(naviKeyLeft, greaterThan(softLeftRight), reason: '左侧要有缝');
    expect(naviKeyLeft + naviKeyWidth, lessThan(softRightLeft), reason: '右侧要有缝');
  });
}
