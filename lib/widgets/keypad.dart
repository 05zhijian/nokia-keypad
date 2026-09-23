import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/audio_engine.dart';
import '../haptics/haptics.dart';
import '../model/navi.dart';
import '../model/nokia_key.dart';
import '../theme/nokia_colors.dart';
import '../theme/nokia_metrics.dart';
import 'key_cap.dart';
import 'nokia_key_button.dart';

/// 数字键的刻字。第二个元素是多按输入的字母提示。
///
/// 参考图上 `0` 键印的是 `@G195` —— 那不是任何真实诺基亚的刻字，是 AI 生成的
/// 噪音，这里换回标准的 `+`（国际拨号前缀）。参考图里 `def 3`、`wxyz 9` 把字母
/// 放在数字左边，和其余键不一致，同样按多数键的「数字在左」统一了。
const _labels = <NokiaKey, (String, String)>{
  NokiaKey.k1: ('1', ''),
  NokiaKey.k2: ('2', 'abc'),
  NokiaKey.k3: ('3', 'def'),
  NokiaKey.k4: ('4', 'ghi'),
  NokiaKey.k5: ('5', 'jkl'),
  NokiaKey.k6: ('6', 'mno'),
  NokiaKey.k7: ('7', 'pqrs'),
  NokiaKey.k8: ('8', 'tuv'),
  NokiaKey.k9: ('9', 'wxyz'),
  NokiaKey.star: ('*', ''),
  NokiaKey.k0: ('0', '+'),
  NokiaKey.hash: ('#', ''),
};

/// 整个键盘。所有键位坐标来自 [nokia_metrics]。
///
/// [extraHeight] 是屏幕比设计画布高出来的部分（设计画布单位）。它被摊进
/// [keypadGaps] 里，**键帽尺寸不变**——真机在长屏上也是缝隙变大，不是键变长。
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    this.onKey,
    this.onNavi,
    this.extraHeight = 0,
    this.topOffset = 0,
  });

  final void Function(NokiaKey key)? onKey;

  /// 导航键按落点报方向，见 [_NaviKey]。
  final void Function(NaviDirection direction)? onNavi;

  final double extraHeight;

  /// 屏幕分走额外高度后长高了多少——整块键盘要原样往下让这么多，
  /// 否则会长进屏幕里。
  final double topOffset;

  static const _margin = 24.0;

  /// 每份权重能分到多少额外高度。
  ///
  /// 按**权重**摊而不是平均摊：上下两头的留白权重更高。平均摊会让余量全被
  /// 行间缝隙吃掉——导航键不动、最后一行戳到底边，键盘整体散开。
  double get _extraPerWeight {
    final weights =
        keypadGaps.length * keypadGapWeight + 2 * keypadEdgeWeight;
    final per = extraHeight / weights;
    // 压缩时不让最窄的那道缝低于下限。
    final floor = (minKeypadGap - keypadGaps.reduce(math.min)) /
        keypadGapWeight;
    return per < floor ? floor : per;
  }

  /// 键盘整体往下让多少——上方留白那一份，加上屏幕长高把键盘顶下去的量。
  double get _topShift =>
      _extraPerWeight * keypadEdgeWeight + topOffset;

  /// 第 [row] 行额外往下偏移多少（row 0 是软键/导航排）。
  double _rowShift(int row) =>
      _topShift + _extraPerWeight * keypadGapWeight * row;

  /// 导航键的矩形。
  ///
  /// 竖直方向**绕「左右软键 + 通话/挂断键」围出的方块中心收**，高度固定。
  /// 直接取满方块的话底部会贴到「2」键上（只剩 8 个单位的缝）。
  Rect get _naviRect {
    final blockTop = softRowTop + _rowShift(0);
    final blockBottom = callRowTop + callKeySize.height + _rowShift(1);
    final center = (blockTop + blockBottom) / 2;
    final height = math.min(naviKeyHeight, blockBottom - blockTop);
    return Rect.fromLTWH(
      naviKeyLeft,
      center - height / 2,
      naviKeyWidth,
      height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var row = 0; row < numRowY.length; row++)
          for (var col = 0; col < numColX.length; col++)
            _at(
              Rect.fromLTWH(
                numColX[col],
                // 数字键盘前面有 2 道缝：软键排→通话排、通话排→数字第一行。
                numRowY[row] + _rowShift(row + 2),
                numKeySize.width,
                numKeySize.height,
              ),
              _numericKey(dtmfKeys[row * 3 + col]),
            ),
        _at(
          Rect.fromLTWH(
            _margin,
            softRowTop + _rowShift(0),
            softKeySize.width,
            softKeySize.height,
          ),
          _barKey(NokiaKey.softLeft),
        ),
        _at(
          Rect.fromLTWH(
            designWidth - _margin - softKeySize.width,
            softRowTop + _rowShift(0),
            softKeySize.width,
            softKeySize.height,
          ),
          _barKey(NokiaKey.softRight),
        ),
        _at(
          _naviRect,
          _NaviKey(
            size: _naviRect.size,
            onDirection: (direction) => onNavi?.call(direction),
          ),
        ),
        _at(
          Rect.fromLTWH(
            _margin,
            callRowTop + _rowShift(1),
            callKeySize.width,
            callKeySize.height,
          ),
          _handsetKey(NokiaKey.call, NokiaColors.callGreen, Icons.call),
        ),
        _at(
          Rect.fromLTWH(
            designWidth - _margin - callKeySize.width,
            callRowTop + _rowShift(1),
            callKeySize.width,
            callKeySize.height,
          ),
          _handsetKey(NokiaKey.end, NokiaColors.endRed, Icons.call_end),
        ),
      ],
    );
  }

  Widget _at(Rect rect, Widget child) =>
      Positioned(left: rect.left, top: rect.top, child: child);

  /// 数字键刻字的字号。**按真机的系统字体定**，不是按测试环境。
  ///
  /// 踩过的坑：`flutter test` 里没有拉丁系统字体，键帽刻字会渲染成全角方块，
  /// 于是「wxyz」在快照里占 4 个字宽、报 RenderFlex 溢出。但真机上用的是
  /// 系统字体，`wxyz` 只有一半宽，根本不会溢出——**按那个报错去缩字号，
  /// 就是在迁就一个测试假象**（之前就是这么把字母从 28 缩到 26 的）。
  ///
  /// 正确的做法是：字号按真机观感给足，外面套 [FittedBox] 兜底，
  /// 任何字体度量意外都只是等比缩一点，不会报错。
  static const _digitFontSize = 40.0;
  static const _subFontSize = 28.0;

  Widget _numericKey(NokiaKey key) {
    final (digit, sub) = _labels[key]!;
    return NokiaKeyButton(
      nokiaKey: key,
      onPressed: () => onKey?.call(key),
      builder: (context, pressed) => KeyCap(
        width: numKeySize.width,
        height: numKeySize.height,
        radius: numKeyRadius,
        pressed: pressed,
        child: FittedBox(
          // 兜底：真机上永远不触发，测试环境和异常字体度量下防溢出。
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                digit,
                style: const TextStyle(
                  fontSize: _digitFontSize,
                  height: 1,
                  color: NokiaColors.keyLabel,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  sub,
                  style: const TextStyle(
                    // 之前是 21，真机上字母明显偏小、和数字主次失衡。
                    fontSize: _subFontSize,
                    height: 1,
                    color: NokiaColors.keySublabel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 软键：参考图上是一道横杠。
  Widget _barKey(NokiaKey key) => NokiaKeyButton(
        nokiaKey: key,
        onPressed: () => onKey?.call(key),
        builder: (context, pressed) => KeyCap(
          width: softKeySize.width,
          height: softKeySize.height,
          radius: pillKeyRadius,
          pressed: pressed,
          child: Container(
            width: softKeySize.width * 0.42,
            height: 3,
            decoration: BoxDecoration(
              color: NokiaColors.keyLabel,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  /// 通话 / 挂断键：绿色与红色的听筒。
  ///
  /// 用 Material 的 `Icons.call` / `call_end`，**不要自己画**。试过自绘圆弧
  /// 想做出更粗更「真」的听筒，走了三版（细缝 → 糊成一坨 → 哑铃），都不如
  /// 这个字形。问题从来不是形状，是**尺寸**——原来 30 太小没填满按键。
  Widget _handsetKey(
    NokiaKey key,
    Color color,
    IconData icon,
  ) =>
      NokiaKeyButton(
        nokiaKey: key,
        onPressed: () => onKey?.call(key),
        builder: (context, pressed) => KeyCap(
          width: callKeySize.width,
          height: callKeySize.height,
          radius: pillKeyRadius,
          pressed: pressed,
          child: Icon(icon, color: color, size: 44),
        ),
      );
}

/// 导航键。参考图上中键是一整块圆角矩形，但实体机上它是上下拨轮，
/// 触屏没有拨轮，所以按**落点**分方向：敲上半部分是「上」，敲正中间是「确定」。
///
/// 不能复用 [NokiaKeyButton]——那个只报「按下」，拿不到落点。
class _NaviKey extends StatefulWidget {
  const _NaviKey({required this.size, this.onDirection});

  final Size size;
  final void Function(NaviDirection direction)? onDirection;

  @override
  State<_NaviKey> createState() => _NaviKeyState();
}

class _NaviKeyState extends State<_NaviKey> {
  bool _pressed = false;

  /// 中心 50% × 50% 的区域算「确定」，其余按偏离较大的那个轴定方向。
  NaviDirection _directionAt(Offset local) {
    final dx = local.dx / widget.size.width - 0.5;
    final dy = local.dy / widget.size.height - 0.5;

    if (dx.abs() < 0.25 && dy.abs() < 0.25) return NaviDirection.select;
    if (dy.abs() >= dx.abs()) {
      return dy < 0 ? NaviDirection.up : NaviDirection.down;
    }
    return dx < 0 ? NaviDirection.left : NaviDirection.right;
  }

  void _handleDown(PointerDownEvent event) {
    if (_pressed) return;
    setState(() => _pressed = true);
    NokiaAudio.instance.playKey(NokiaKey.navi);
    NokiaHaptics.keyPress();
    widget.onDirection?.call(_directionAt(event.localPosition));
  }

  void _handleUp() {
    if (!_pressed) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleDown,
      onPointerUp: (_) => _handleUp(),
      onPointerCancel: (_) => _handleUp(),
      behavior: HitTestBehavior.opaque,
      child: KeyCap(
        width: widget.size.width,
        height: widget.size.height,
        radius: 26,
        pressed: _pressed,
        faceColor: NokiaColors.naviFace,
        borderColor: NokiaColors.naviBorder,
        // 描边加粗过：原来 1.6 在真机上太细，导航键的轮廓立不住。
        borderWidth: 2.8,
      ),
    );
  }
}
