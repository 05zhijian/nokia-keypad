import 'package:flutter/material.dart';

import '../theme/nokia_colors.dart';
import '../theme/nokia_font.dart';
import '../theme/nokia_metrics.dart';

/// 单色 LCD 屏。
///
/// 内容按「行」组织，与参考图一致：状态栏 / 正文若干行 / 底部软键标签。
/// 各功能屏只换 [lines]、[highlightedLine] 与两个软键标签，外壳不变。
class LcdScreen extends StatelessWidget {
  const LcdScreen({
    super.key,
    required this.width,
    required this.height,
    required this.lines,
    this.highlightedLine,
    this.softLeft = '',
    this.softRight = '',
    this.showEnvelope = true,
    this.capsLabel,
  });

  final double width;
  final double height;
  final List<String> lines;

  /// 反白显示的行号。主菜单用它标出当前选中项。
  final int? highlightedLine;

  final String softLeft;
  final String softRight;

  /// 状态栏是否显示信封图标。有未读短信时才亮。
  final bool showEnvelope;

  /// 状态栏左上角的大小写提示（`ABC` / `abc`）。只在编辑态出现。
  final String? capsLabel;

  @override
  Widget build(BuildContext context) {
    final pad = width * lcdPaddingRatio;
    final statusH = height * 0.088;
    // 字号必须吸附到像素字体的原生尺寸整数倍上，否则点阵会糊。
    // 比例是共享常量，折行计算用的是同一份，两边不会走样。
    final textSize = nokiaFontSnap(height * lcdTextSizeRatio);
    final softSize = nokiaFontSnap(height * lcdSoftSizeRatio);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NokiaColors.lcd,
        borderRadius: BorderRadius.circular(width * 0.028),
        boxShadow: [
          // 屏幕是凹进机身的，四周压一圈暗边才不像贴纸。
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 7,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: statusH,
            child: _StatusBar(
              showEnvelope: showEnvelope,
              capsLabel: capsLabel,
            ),
          ),
          SizedBox(height: height * 0.05),
          Expanded(
            // 内容超出屏高时直接裁掉。诺基亚是按屏翻页的，
            // 不做平滑滚动，所以这里用 ClipRect + OverflowBox 而不是滚动视图。
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxHeight: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < lines.length; i++)
                      _Line(
                        text: lines[i],
                        highlighted: i == highlightedLine,
                        fontSize: textSize,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(softLeft, style: _softStyle(softSize)),
              Text(softRight, style: _softStyle(softSize)),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _softStyle(double size) => TextStyle(
        fontFamily: nokiaFontFamily,
        fontSize: size,
        color: NokiaColors.lcdInk,
      );
}

/// 正文的一行。选中项用**反白**（底色与字色对调）标出——
/// 这是诺基亚在单色屏上表达「选中」的方式。
class _Line extends StatelessWidget {
  const _Line({
    required this.text,
    required this.highlighted,
    required this.fontSize,
  });

  final String text;
  final bool highlighted;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: nokiaFontFamily,
      fontSize: fontSize,
      height: 1.16,
      color: highlighted ? NokiaColors.lcd : NokiaColors.lcdInk,
    );

    if (!highlighted) return Text(text, style: style);

    return ColoredBox(
      color: NokiaColors.lcdInk,
      child: Text(text, style: style),
    );
  }
}

/// 状态栏：左起信号格 +（有未读时）信封图标 +（编辑态）大小写提示，右侧电池。
/// 全部按容器高度等比缩放。
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.showEnvelope, this.capsLabel});

  final bool showEnvelope;
  final String? capsLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final caps = capsLabel;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: h * 1.30,
              height: h,
              child: CustomPaint(painter: _SignalPainter()),
            ),
            if (showEnvelope) ...[
              SizedBox(width: h * 0.34),
              SizedBox(
                width: h * 1.45,
                height: h,
                child: CustomPaint(painter: _EnvelopePainter()),
              ),
            ],
            if (caps != null) ...[
              SizedBox(width: h * 0.30),
              SizedBox(
                height: h,
                child: Center(
                  child: Text(
                    caps,
                    style: TextStyle(
                      fontFamily: nokiaFontFamily,
                      fontSize: nokiaFontSnap(h * 0.55),
                      height: 1,
                      color: NokiaColors.lcdInk,
                    ),
                  ),
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: h * 2.05,
              height: h,
              child: CustomPaint(painter: _BatteryPainter()),
            ),
          ],
        );
      },
    );
  }
}

/// 四格信号，逐格升高，底部对齐。
class _SignalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = NokiaColors.lcdInk;
    const bars = 4;
    final gap = size.width * 0.11;
    final barW = (size.width - gap * (bars - 1)) / bars;

    for (var i = 0; i < bars; i++) {
      final barH = size.height * (0.40 + 0.20 * i);
      canvas.drawRect(
        Rect.fromLTWH(i * (barW + gap), size.height - barH, barW, barH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 新短信的信封图标。
class _EnvelopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.13;
    final paint = Paint()
      ..color = NokiaColors.lcdInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.miter;

    final body = Rect.fromLTWH(
      stroke / 2,
      size.height * 0.14,
      size.width - stroke,
      size.height * 0.72,
    );
    canvas.drawRect(body, paint);

    // 信封正面的 V 形封口
    canvas.drawPath(
      Path()
        ..moveTo(body.left, body.top)
        ..lineTo(body.center.dx, body.top + body.height * 0.58)
        ..lineTo(body.right, body.top),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 电池：外壳 + 正极凸起 + 电量格。
class _BatteryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = NokiaColors.lcdInk;
    final stroke = size.height * 0.12;

    final nubW = size.width * 0.06;
    final shellW = size.width - nubW - size.width * 0.05;
    final shell = Rect.fromLTWH(
      stroke / 2,
      size.height * 0.24,
      shellW - stroke,
      size.height * 0.52,
    );

    canvas.drawRect(
      shell,
      Paint()
        ..color = NokiaColors.lcdInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(shell.right + size.width * 0.02, size.height * 0.38, nubW,
          size.height * 0.24),
      fill,
    );

    const segments = 4;
    final inner = shell.deflate(stroke);
    final segGap = size.width * 0.035;
    final segW = (inner.width - segGap * (segments - 1)) / segments;
    for (var i = 0; i < segments; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
            inner.left + i * (segW + segGap), inner.top, segW, inner.height),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
