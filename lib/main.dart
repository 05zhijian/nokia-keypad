import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio/audio_engine.dart';
import 'contacts/device_contacts_source.dart';
import 'haptics/haptics.dart';
import 'model/nokia_key.dart';
import 'state/phone_controller.dart';
import 'theme/nokia_colors.dart';
import 'widgets/phone_body.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全屏沉浸：状态栏和导航栏都藏掉，否则「这是一台按键机」的幻觉第一眼就破了。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 屏幕常亮。没人会去碰一台会自己息屏的诺基亚。
  await WakelockPlus.enable();

  await NokiaHaptics.init();

  runApp(const NokiaApp());
}

class NokiaApp extends StatelessWidget {
  const NokiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nokia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NokiaColors.body,
      ),
      home: const _PhonePage(),
    );
  }
}

class _PhonePage extends StatefulWidget {
  const _PhonePage();

  @override
  State<_PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<_PhonePage> {
  /// 注入真实的通讯录数据源。
  ///
  /// 状态机默认拿的是空实现，只有这里把它换成读系统通讯录的那个——
  /// 这样测试永远不会碰到平台通道与权限弹窗。
  final _controller = PhoneController(
    contactsSource: const DeviceContactsSource(),
  );
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 先把音频引擎拉起来再亮屏。
  ///
  /// 按键音必须提前合成好常驻内存（见 [NokiaAudio]），这个初始化有几百毫秒到
  /// 一秒的开销。用它当「开机时间」，比亮着屏卡一下自然得多。
  Future<void> _boot() async {
    await _readVersion();
    try {
      await NokiaAudio.instance.init();
    } catch (error, stack) {
      // 音频起不来不该让整个 App 打不开——先亮屏，按键只是没声音。
      debugPrint('音频初始化失败：$error\n$stack');
    }
    if (!mounted) return;
    setState(() => _booted = true);
  }

  /// 读真实版本号给占位屏当构建标记用。
  ///
  /// 走 package_info 而不是在 Dart 里再写一个字面量：写死的话改了 pubspec
  /// 忘了改这里，手机上显示的版本就会骗人——而版本号恰恰是用来分辨包的工具。
  Future<void> _readVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _controller.version = '${info.version}+${info.buildNumber}';
    } catch (error) {
      debugPrint('读取版本号失败：$error');
    }
  }

  void _handleKey(NokiaKey key) {
    switch (key) {
      case NokiaKey.softLeft:
        _controller.softLeft();
      case NokiaKey.softRight:
        _controller.softRight();
      case NokiaKey.end:
        // 红键兼作「退出」，任何时候按都回待机。编辑态右软键被「清除」占用，
        // 没有它就是死路一条。
        _controller.hangUp();
      case NokiaKey.navi:
        // 导航键走 onNavi —— 它要按落点分方向，不能只报「按下」。
        break;
      case NokiaKey.call:
        // 绿键的语义随屏幕变：来电时接听、待机时开拨号盘、拨号盘里拨出。
        _controller.greenKey();
      default:
        _controller.digit(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => PhoneBody(
          screenOn: _booted,
          content: _controller.content,
          onKey: _handleKey,
          onNavi: _controller.navi,
        ),
      ),
    );
  }
}
