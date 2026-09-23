/// 通讯录的读取结果状态。
enum ContactsStatus {
  /// 正在读。
  loading,

  /// 读到了（可能为空）。
  ready,

  /// 用户拒绝了授权。
  denied,

  /// 授权了但读取过程出错。
  failed,
}

/// 一次读取的结果。
class ContactsResult {
  const ContactsResult({required this.status, this.names = const []});

  final ContactsStatus status;
  final List<String> names;
}

/// 通讯录数据源。
///
/// 抽成接口是为了让状态机保持可测：真机实现要过系统权限和平台通道，
/// 在没有设备的环境里根本跑不起来。测试注入一个假的，就能完整验证
/// 「加载中 → 列表 → 选人 → 来电」这条链路，以及授权被拒的分支。
abstract interface class ContactsSource {
  Future<ContactsResult> load();
}

/// 什么都不返回的实现。
///
/// 默认用它，这样测试和不需要通讯录的场景都不会碰到平台通道。
class EmptyContactsSource implements ContactsSource {
  const EmptyContactsSource();

  @override
  Future<ContactsResult> load() async =>
      const ContactsResult(status: ContactsStatus.ready);
}
