/// 诺基亚键盘上的全部按键。
///
/// 顺序对应参考图里的物理布局，UI / 音频 / 触觉三层共用这一份定义，
/// 避免各自维护一套键表而对不上。
enum NokiaKey {
  // 键盘第一排：左软键、导航键、右软键
  softLeft,
  navi,
  softRight,

  // 通话键（绿）/ 挂断键（红）
  call,
  end,

  // 十二键数字键盘
  k1,
  k2,
  k3,
  k4,
  k5,
  k6,
  k7,
  k8,
  k9,
  star,
  k0,
  hash,
}

/// 会发出 DTMF 双音的键。软键、导航键、通话键都是静音的。
const dtmfKeys = <NokiaKey>[
  NokiaKey.k1,
  NokiaKey.k2,
  NokiaKey.k3,
  NokiaKey.k4,
  NokiaKey.k5,
  NokiaKey.k6,
  NokiaKey.k7,
  NokiaKey.k8,
  NokiaKey.k9,
  NokiaKey.star,
  NokiaKey.k0,
  NokiaKey.hash,
];
