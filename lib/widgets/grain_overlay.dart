import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../theme/nokia_metrics.dart';

/// 铺在整机上的一层极细噪点。
///
/// 参考图是一张**照片**，照片自带传感器噪点与灰尘；纯矢量绘制出来太干净，
/// 一眼就看出是渲染图而不是实物。盖一层确定性噪点把它拉回「被拍下来的东西」。
///
/// 点集静态预生成、坐标是绝对的（设计画布单位），并且向纵向多铺 45%——
/// 这样在比参考图更长的手机上也能盖满，不需要按画布高度重新计算。
/// 固定种子保证每帧完全一致，否则噪点会像下雪一样闪。
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({
    super.key,
    this.lightOpacity = 0.075,
    this.darkOpacity = 0.08,
  });

  /// 亮点的透明度——模拟落在机身上的灰尘反光。
  final double lightOpacity;

  /// 暗点的透明度——模拟缝隙里的积垢。
  final double darkOpacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GrainPainter(
          lightOpacity: lightOpacity,
          darkOpacity: darkOpacity,
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.lightOpacity, required this.darkOpacity});

  final double lightOpacity;
  final double darkOpacity;

  static const _count = 7000;

  /// 纵向多铺出的比例，覆盖比设计画布更高的屏幕。
  static const _verticalOverflow = 1.45;

  static final Float32List _light = _build(20260922);
  static final Float32List _dark = _build(19980601);

  static Float32List _build(int seed) {
    final rnd = math.Random(seed);
    final spanY = designHeight * _verticalOverflow;
    final out = Float32List(_count * 2);
    for (var i = 0; i < _count; i++) {
      out[i * 2] = rnd.nextDouble() * designWidth;
      out[i * 2 + 1] = rnd.nextDouble() * spanY;
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // drawRawPoints 一次调用画完所有点，比逐个 drawRect 快得多。
    canvas.drawRawPoints(
      PointMode.points,
      _light,
      Paint()
        ..color = Colors.white.withValues(alpha: lightOpacity)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRawPoints(
      PointMode.points,
      _dark,
      Paint()
        ..color = Colors.black.withValues(alpha: darkOpacity)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) =>
      old.lightOpacity != lightOpacity || old.darkOpacity != darkOpacity;
}
