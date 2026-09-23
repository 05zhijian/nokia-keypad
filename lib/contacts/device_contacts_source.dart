import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'contacts_source.dart';

/// 读手机真实通讯录。
///
/// 三点说明：
/// - 只读不写：申请的是 [PermissionType.read]，不是 readWrite。
/// - 读到的名字只活在这个进程里，不落盘也不外传——App 的 release manifest
///   里只有 `VIBRATE` 一项权限，连 `INTERNET` 都没有，物理上发不出去。
/// - 不显式排序，交给系统。Android 通讯录本来就按系统的语言习惯排好序了，
///   在 Dart 里再按码点排一次反而会把中文名字打乱（码点序不是拼音序）。
class DeviceContactsSource implements ContactsSource {
  const DeviceContactsSource();

  @override
  Future<ContactsResult> load() async {
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        return const ContactsResult(status: ContactsStatus.denied);
      }

      // 不传 properties：只要名字的话这样快得多，不必把号码邮箱地址全拉一遍。
      final contacts = await FlutterContacts.getAll();

      final names = <String>[
        for (final contact in contacts)
          if (contact.displayName case final name?
              when name.trim().isNotEmpty)
            name.trim(),
      ];

      return ContactsResult(status: ContactsStatus.ready, names: names);
    } catch (error, stack) {
      debugPrint('读通讯录失败：$error\n$stack');
      return const ContactsResult(status: ContactsStatus.failed);
    }
  }
}
