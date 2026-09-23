import 'package:flutter/material.dart';

import '../audio/audio_engine.dart';
import '../haptics/haptics.dart';
import '../model/nokia_key.dart';

/// 所有键帽的公共外壳：处理按下/抬起的视觉状态，并触发音效与触觉。
///
/// 用 [Listener] 而不是 GestureDetector。后者要等手势竞技场裁决
/// （判断是不是双击、长按、拖动……）才回调，会引入几十毫秒延迟。
/// 按键必须按下即响，所以直接监听原始指针事件。
class NokiaKeyButton extends StatefulWidget {
  const NokiaKeyButton({
    super.key,
    required this.nokiaKey,
    required this.builder,
    this.onPressed,
  });

  final NokiaKey nokiaKey;

  /// [pressed] 用于绘制按下态。
  final Widget Function(BuildContext context, bool pressed) builder;

  /// 在**按下**时触发，不是抬起时。
  final VoidCallback? onPressed;

  @override
  State<NokiaKeyButton> createState() => _NokiaKeyButtonState();
}

class _NokiaKeyButtonState extends State<NokiaKeyButton> {
  bool _pressed = false;

  void _handleDown(PointerDownEvent _) {
    if (_pressed) return;
    setState(() => _pressed = true);
    NokiaAudio.instance.playKey(widget.nokiaKey);
    NokiaHaptics.keyPress();
    widget.onPressed?.call();
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
      child: widget.builder(context, _pressed),
    );
  }
}
