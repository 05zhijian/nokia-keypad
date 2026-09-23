import 'package:flutter/material.dart';

/// 配色采样自参考图。
///
/// 全部集中在这里是为了方便对着真机调——LCD 的绿是最容易调偏的一项，
/// 参考图偏黄绿（chartreuse），不是常见的苔绿。
abstract final class NokiaColors {
  /// 机身。参考图是亮面纯黑，靠近边缘有极弱的高光渐变。
  static const body = Color(0xFF050505);
  static const bodySheen = Color(0xFF1C1C1C);

  /// NOKIA logo。
  static const logo = Color(0xFFFFFFFF);

  /// 单色 LCD 屏。偏黄绿，不要调成 #9BBC0F 那种 Game Boy 苔绿。
  ///
  /// 亮度调低过一档：原来 #C5D24E 在真机上偏刺眼，不像被动式 LCD。
  static const lcd = Color(0xFFAEBA45);
  /// LCD 上的「墨色」——不是纯黑，是带屏色的深橄榄，这样才有背光透出来的感觉。
  static const lcdInk = Color(0xFF23260C);
  /// LCD 关闭时的底色。
  static const lcdOff = Color(0xFF798238);

  /// 按键。上缘提亮、下缘压暗，靠这个做出塑料键的厚度。
  ///
  /// 调暗过一档：#2B2B2B 在真机上偏亮，和调暗后的屏幕不搭。
  static const keyFace = Color(0xFF212121);
  static const keyHighlight = Color(0xFF3F3F3F);
  static const keyShadow = Color(0xFF0E0E0E);

  /// 键帽刻字。数字是亮白，底下的 abc/def 是灰的。
  static const keyLabel = Color(0xFFF5F5F5);
  static const keySublabel = Color(0xFFAFAFAF);

  /// 导航键：黑底 + 浅灰描边。描边调亮过一档（#8E8E8E 在真机上偏暗）。
  static const naviFace = Color(0xFF0A0A0A);
  static const naviBorder = Color(0xFFBCBCBC);

  /// 通话键（绿）/ 挂断键（红）的图标色。
  static const callGreen = Color(0xFF3ED35A);
  static const endRed = Color(0xFFEE3B2F);
}
