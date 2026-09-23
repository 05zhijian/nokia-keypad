import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/navi.dart';
import '../model/nokia_key.dart';
import '../state/phone_state.dart';
import '../theme/nokia_colors.dart';
import '../theme/nokia_metrics.dart';
import 'grain_overlay.dart';
import 'keypad.dart';
import 'lcd_screen.dart';

/// 整台「手机」。
///
/// 内部按 [designWidth] 宽的设计画布排版，**按宽度铺满屏幕**，高度随屏幕浮动。
/// 不用等比装箱：那在比参考图更长的手机上会把多出来的高度全丢成下方留白。
/// 多出来的高度交给 [Keypad] 摊进键缝里，键帽尺寸保持不变。
class PhoneBody extends StatelessWidget {
  const PhoneBody({
    super.key,
    this.content,
    this.onKey,
    this.onNavi,
    this.screenOn = true,
  });

  /// 屏幕上要显示的内容。为 null 或 [screenOn] 为 false 时显示关机屏。
  final LcdContent? content;

  final void Function(NokiaKey key)? onKey;
  final void Function(NaviDirection direction)? onNavi;
  final bool screenOn;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NokiaColors.body,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / designWidth;
          // 让画布高度跟着屏幕走，而不是死守参考图的 1170。
          // 这样 BoxFit.fill 得到的正好是一个**等比**缩放（宽高比一致），
          // 多出来的高度再分给屏幕和键盘。
          final canvasHeight = constraints.maxHeight / scale;
          final extra = canvasHeight - designHeight;

          // 多出来的高度分一份给屏幕。全给键盘的话，长屏上键盘越长越高、
          // 屏幕显得越来越小，比例就偏离参考图了。
          final screenHeight = math.max(
            screenRect.height * 0.6,
            screenRect.height + extra * screenExtraShare,
          );
          // 屏幕实际长高了多少——键盘要原样往下让这么多，否则会长进屏幕里。
          final screenGrowth = screenHeight - screenRect.height;
          final lcd = content;

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FittedBox(
              // 用 FittedBox 而不是 Transform.scale：Transform 不改变布局尺寸，
              // 会让裁剪框与绘制结果对不上（长屏下键盘会被横向切掉）。
              fit: BoxFit.fill,
              child: SizedBox(
                width: designWidth,
                height: canvasHeight,
                child: Stack(
                  children: [
                    const Positioned.fill(child: _BodySheen()),
                    const Positioned(
                      top: logoCenterY - 22,
                      left: 0,
                      right: 0,
                      child: Center(child: _NokiaLogo()),
                    ),
                    Positioned(
                      left: screenRect.left,
                      top: screenRect.top,
                      child: (screenOn && lcd != null)
                          ? LcdScreen(
                              width: screenRect.width,
                              height: screenHeight,
                              lines: lcd.lines,
                              highlightedLine: lcd.highlightedLine,
                              softLeft: lcd.softLeft,
                              softRight: lcd.softRight,
                              showEnvelope: lcd.showEnvelope,
                              capsLabel: lcd.capsLabel,
                            )
                          : _PoweredOffScreen(
                              width: screenRect.width,
                              height: screenHeight,
                            ),
                    ),
                    Positioned.fill(
                      child: Keypad(
                        extraHeight: extra - screenGrowth,
                        topOffset: screenGrowth,
                        onKey: onKey,
                        onNavi: onNavi,
                      ),
                    ),
                    // 噪点铺在最上层，模拟照片的传感器噪点与机身灰尘。
                    const Positioned.fill(child: GrainOverlay()),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 机身亮面的极弱高光，避免整块死黑。
class _BodySheen extends StatelessWidget {
  const _BodySheen();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.75),
          radius: 1.5,
          colors: [Color(0xFF171717), NokiaColors.body],
        ),
      ),
    );
  }
}

/// NOKIA 字样。真实机身上的 logo 是定制的无衬线体，
/// 这里用加宽字距的粗体近似——不引入外部字体，避免又多一个授权问题。
class _NokiaLogo extends StatelessWidget {
  const _NokiaLogo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'NOKIA',
      style: TextStyle(
        color: NokiaColors.logo,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: 4,
        height: 1,
      ),
    );
  }
}

/// 关机状态的屏幕：一片暗绿，什么都不显示。
class _PoweredOffScreen extends StatelessWidget {
  const _PoweredOffScreen({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NokiaColors.lcdOff,
        borderRadius: BorderRadius.circular(width * 0.028),
      ),
    );
  }
}
