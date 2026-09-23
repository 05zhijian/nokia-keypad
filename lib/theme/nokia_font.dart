/// 中文像素字体（缝合像素字体 Fusion Pixel Font，OFL-1.1）。
///
/// 为什么用它：最早选的 Zpix（最像素）经核实是**付费商业字体**
/// （README 明写「字体付费后，我会给一份授权协议」，且禁止转换与拆分），
/// 不能用。缝合像素字体是 OFL-1.1，可免费商用与捆绑分发。
const nokiaFontFamily = 'FusionPixel';

/// 字体的原生点阵尺寸。
///
/// 像素字体只在原生尺寸的整数倍上栅格化才是锐利的；给一个 47.3 这样的字号，
/// 字形会在像素格之间插值，糊成一片。所有字号都必须经过 [nokiaFontSnap]。
const nokiaFontNativeSize = 12.0;

/// 把期望字号吸附到字体原生尺寸的整数倍上。
double nokiaFontSnap(double desired) {
  final steps = (desired / nokiaFontNativeSize).round();
  return (steps < 1 ? 1 : steps) * nokiaFontNativeSize;
}
