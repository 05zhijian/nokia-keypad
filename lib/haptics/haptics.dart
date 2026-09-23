import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// 按键触觉反馈。
///
/// 两级降级：`vibration` 包能给到具体时长与振幅，最接近实体键那种「一下」；
/// 但部分机型没有振幅控制或没有马达，此时退回 Flutter 内置的
/// [HapticFeedback]。任何一步失败都静默吞掉——触觉没了不该让 App 崩。
abstract final class NokiaHaptics {
  static bool _ready = false;

  static Future<void> init() async {
    try {
      _ready = await Vibration.hasVibrator();
    } catch (_) {
      _ready = false;
    }
  }

  /// 实体键那种短促的一下。诺基亚的震感是干脆的，不是「嗡」。
  static void keyPress() {
    if (_ready) {
      // 15ms 极短震动。振幅压到 128，太强会显得廉价。
      Vibration.vibrate(duration: 15, amplitude: 128).catchError((_) {});
    } else {
      HapticFeedback.lightImpact();
    }
  }
}
