import 'dart:ui';

import 'nokia_font.dart';

/// 键盘几何，单位是「设计画布」坐标（554 × 1170），照参考图量出来的。
///
/// 整个机身按单一缩放系数铺满屏幕，所以这里只描述相对比例，
/// 不写任何像素绝对值——这样从手表到平板都不会走形。
const designWidth = 554.0;
const designHeight = 1170.0;

/// 屏幕区域。
const screenRect = Rect.fromLTRB(33, 133, 521, 632);

/// NOKIA logo 的基线位置。
const logoCenterY = 78.0;

// ---- 键盘区 ----

/// 第一排：左软键 / 导航键 / 右软键。
const softRowTop = 645.0;
const softKeySize = Size(116, 62);

/// 导航键的宽度与高度（左右对称于画布中线）。
///
/// **竖直位置刻意不在这里定。** 导航键要落在「左右软键 + 通话/挂断键」这四颗
/// 键围出的方块**正中间**，所以它的 top 由 `Keypad` 按实际行距算出来——长屏上
/// 那两排的间距会被撑开，导航键得跟着居中，写死就会偏上。
///
/// 高度也从 147（撑满方块）收回到 112：撑满时底部离「2」键只剩 8 个单位，
/// 太挤。112 让底部留出约 26 个单位的空隙，和参考图的疏密接近。
const naviKeyLeft = 192.0;
const naviKeyWidth = 170.0;
const naviKeyHeight = 112.0;

/// 第二排：通话键（绿）/ 挂断键（红）。
const callRowTop = 730.0;
const callKeySize = Size(116, 62);

/// 数字键盘：3 列 × 4 行。
const numKeySize = Size(156, 78);
const numColX = <double>[24, 199, 374];
const numRowY = <double>[800, 890, 980, 1070];

/// 键盘各行之间的基准缝隙，从上往下：软键排→通话排，通话排→数字第一行，
/// 以及数字各行之间。
///
/// 屏幕比设计画布更高时，多出来的高度摊进这些缝隙和上下留白里——
/// **键帽尺寸不变**。真机在长屏上也是这样：缝隙变大，不是键被拉长。
const keypadGaps = <double>[23, 8, 12, 12, 12];

/// 键盘上方的基准留白（屏幕下沿到导航键之间）。
const keypadTopGap = 8.0;

/// 键盘下方的基准留白（最后一行键到画布底）。
const keypadBottomGap = 22.0;

/// 摊额外高度时，行间缝隙的权重。
const keypadGapWeight = 1.0;

/// 上下两头留白的权重。
///
/// 比行间缝隙高——**这一条是踩过坑的**：早先按平均摊，结果长屏手机上余量
/// 全被行间缝隙吃掉，导航键贴着屏幕不动、最后一行戳到底边，整块键盘「散开」了。
/// 两头多分一点，键盘才会始终居中、不贴边。
const keypadEdgeWeight = 1.6;

/// 键帽之间的最小缝隙。压缩时不会窄于这个值，否则键会粘在一起。
const minKeypadGap = 4.0;

/// 长屏多出来的高度里，**屏幕**分到的比例。
///
/// 不给屏幕分的话，多出来的高度会全部进键盘的缝隙——键盘越长越高、屏幕显得
/// 越来越小，比例就偏离参考图了（用户反馈过「屏幕该拉长一些，比例像原图」）。
///
/// 0.5 大致能维持参考图里「屏幕高度 ≈ 键盘高度」的关系。
const screenExtraShare = 0.5;

/// 键帽圆角。数字键是圆角矩形，软键/通话键更接近胶囊。
const numKeyRadius = 14.0;
const pillKeyRadius = 22.0;

// ---- LCD 排版 ----

/// 屏幕内边距占屏宽的比例。
const lcdPaddingRatio = 0.045;

/// 正文字号相对屏高的比例。0.118 是照着参考图量的：正文约占屏宽 46%。
const lcdTextSizeRatio = 0.118;

/// 软键标签字号相对屏高的比例。
const lcdSoftSizeRatio = 0.070;

/// LCD 正文每行能放下几个「字宽」。
///
/// 控制器折行要用它，必须和 [LcdScreen] 实际渲染的字号一致——所以这里从屏宽和
/// **吸附后**的字号算出来，改字号时两边一起变，不会各写一份而走样。
double get lcdColumns {
  final inner = screenRect.width * (1 - 2 * lcdPaddingRatio);
  final fontSize = nokiaFontSnap(screenRect.height * lcdTextSizeRatio);
  return inner / fontSize;
}
