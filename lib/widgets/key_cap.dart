import 'package:flutter/material.dart';

import '../theme/nokia_colors.dart';

/// 键帽的统一外观。
///
/// 「手感」有相当一部分是视觉的：按下时键帽下沉、阴影收窄、整体压暗。
/// 三者缺一，按压就会显得像贴纸而不是塑料键。
///
/// **所有键帽必须长得完全一样。**
///
/// 试过给每颗键不同的明度/色相来做旧（`wearSeed` 那套），实际效果被读成
/// 「亮度不一致」而不是「用旧了」——用户明确要求调一致。做旧的方向是错的，
/// 不要再加回去；真实感从棱边高光和阴影来，不从色差来。
class KeyCap extends StatelessWidget {
  const KeyCap({
    super.key,
    required this.width,
    required this.height,
    required this.radius,
    required this.pressed,
    this.child,
    this.faceColor = NokiaColors.keyFace,
    this.borderColor,
    this.borderWidth = 0,
  });

  final double width;
  final double height;
  final double radius;
  final bool pressed;
  final Widget? child;
  final Color faceColor;
  final Color? borderColor;
  final double borderWidth;

  /// 键程。真实键帽按下大约 1~2mm，换算到设计画布约 3 个单位。
  static const _travel = 3.0;

  static Color _shiftLightness(Color c, double delta) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, pressed ? _travel : 0),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: borderWidth)
              // 没有专门描边色时压一圈极暗的边，定义键帽轮廓。
              : Border.all(
                  color: Colors.black.withValues(alpha: 0.30),
                  width: 1,
                ),
          // 面是平的，只有上下棱边吃光——模压塑料件的样子，不是抛光件。
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: pressed
                ? [faceColor, faceColor]
                : [
                    _shiftLightness(faceColor, 0.12),
                    faceColor,
                    _shiftLightness(faceColor, -0.02),
                    _shiftLightness(faceColor, -0.06),
                  ],
            stops: const [0.0, 0.09, 0.86, 1.0],
          ),
          // 按下时阴影收紧并变短——键帽贴近底板了。
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: pressed ? 0.55 : 0.85),
              blurRadius: pressed ? 2 : 6,
              offset: Offset(0, pressed ? 1 : 5),
            ),
          ],
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}
