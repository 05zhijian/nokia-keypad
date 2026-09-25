import '../contacts/contacts_source.dart';

/// 菜单项能触发的动作。
enum MenuAction {
  compose,
  inbox,
  callLog,
  nokiaTune,
  blankRingtone,
  snake,
  settings,
  fakeCall,
}

/// 菜单树的一个节点：要么展开成子菜单，要么进一个功能屏。
sealed class MenuNode {
  const MenuNode(this.label);

  final String label;
}

/// 展开成下一级菜单。
class SubMenuNode extends MenuNode {
  const SubMenuNode(super.label, this.children);

  final List<MenuNode> children;
}

/// 进入一个功能屏。
class ActionNode extends MenuNode {
  const ActionNode(super.label, this.action);

  final MenuAction action;
}

/// 主菜单树。
///
/// 真实的 3310 主菜单是图标网格，但图标在单色点阵上要逐个手绘，收益不划算；
/// 这里用**反白高亮列表**——同样是诺基亚的视觉语言（S30/S40 都用这种），
/// 在低分辨率下比硬塞图标可读得多。
const rootMenu = <MenuNode>[
  SubMenuNode('信息', [
    ActionNode('写信息', MenuAction.compose),
    ActionNode('收件箱', MenuAction.inbox),
  ]),
  ActionNode('通话记录', MenuAction.callLog),
  SubMenuNode('铃声编辑器', [
    // 分成两条路：预置的那段能一键听到，也不用先删掉才能自己编。
    ActionNode('诺基亚铃声', MenuAction.nokiaTune),
    ActionNode('自己编', MenuAction.blankRingtone),
  ]),
  ActionNode('设置', MenuAction.settings),
  ActionNode('假来电', MenuAction.fakeCall),
  ActionNode('贪吃蛇', MenuAction.snake),
];

/// 收件箱里那条短信的正文。
///
/// 通知屏上的「无内鬼 / 抓紧上车」是参考图里拍的，这里的正文顺那个语气续下去。
const inboxBody = <String>[
  '无内鬼，抓紧上车。',
  '今晚八点，老地方，',
  '迟到的自罚三杯。',
];

/// 一个人最多能看到几行。超出交给 LCD 裁掉（诺基亚是按屏翻页的）。
const maxLcdLines = 6;

/// 手机界面当前所处的屏。
///
/// 诺基亚的交互是严格层级的：待机 → 主菜单 → 子项 → 功能屏，右软键逐级退回。
/// 这个层级直接建模成 [PhoneController] 里的一个栈。
sealed class PhoneUiState {
  const PhoneUiState();
}

/// 待机。真实待机画面只有运营商名和两个软键标签。
class Standby extends PhoneUiState {
  const Standby();
}

/// 新短信通知——参考图拍的正是这一屏。
class SmsNotification extends PhoneUiState {
  const SmsNotification();
}

/// 读短信。[scroll] 是顶部被翻过去的行数，诺基亚是按屏翻不是平滑滚动。
class SmsView extends PhoneUiState {
  const SmsView({this.scroll = 0});

  final int scroll;
}

/// 菜单。[items] 是当前这一级的节点，[selected] 是反白的那一项。
///
/// 用「列表」而不是「枚举」是因为菜单是树：信息底下还挂着写信息和收件箱。
class MenuOpen extends PhoneUiState {
  const MenuOpen({required this.items, this.selected = 0});

  final List<MenuNode> items;
  final int selected;
}

/// 写信息。正文由 [T9Input] 维护，这里只是一屏。
class Compose extends PhoneUiState {
  const Compose();
}

/// 发送后的确认屏。
class MessageSent extends PhoneUiState {
  const MessageSent();
}

/// 铃声编辑器。[playing] 为真时软键变「停止」。
class ComposerOpen extends PhoneUiState {
  const ComposerOpen({this.playing = false});

  final bool playing;
}

/// 来电。[callerName] 取自通讯录，所以屏幕上显示的是真人名而不是号码。
class IncomingCall extends PhoneUiState {
  const IncomingCall({required this.callerName});

  final String callerName;
}

/// 通讯录。
///
/// 加载中 / 被拒授权 / 读取失败 / 读到了但是空的——这几种都要显示不同的提示，
/// 所以状态和名字一起放在这里，而不是另开几个屏。
class ContactsOpen extends PhoneUiState {
  const ContactsOpen({
    this.status = ContactsStatus.loading,
    this.names = const [],
    this.selected = 0,
  });

  final ContactsStatus status;
  final List<String> names;
  final int selected;
}

/// 通话中。[seconds] 是已通话秒数，每秒刷新一次。
class InCall extends PhoneUiState {
  const InCall({this.seconds = 0});

  final int seconds;
}

/// 通话结束，显示这通电话打了多久。
class CallEnded extends PhoneUiState {
  const CallEnded({required this.seconds});

  final int seconds;
}

/// 拨号盘。[number] 是已经敲进去的数字。
class DialerOpen extends PhoneUiState {
  const DialerOpen({this.number = ''});

  final String number;
}

/// 呼叫中——号码已拨出，等对方接。这期间响铃回音。
class Calling extends PhoneUiState {
  const Calling({required this.number});

  final String number;
}

/// 贪吃蛇。游戏本身的状态在 [PhoneController] 里，这一屏只是个标记。
class SnakeOpen extends PhoneUiState {
  const SnakeOpen();
}

/// 菜单里还没实现的功能。留着是为了让导航层级现在就能走通。
class NotImplemented extends PhoneUiState {
  const NotImplemented(this.title);

  final String title;
}

/// 一屏要显示的全部内容。由 [PhoneController] 从状态映射出来，UI 只负责画。
class LcdContent {
  const LcdContent({
    this.lines = const [],
    this.grid,
    this.highlightedLine,
    this.softLeft = '',
    this.softRight = '',
    this.showEnvelope = false,
    this.capsLabel,
  });

  final List<String> lines;

  /// 点阵内容（贪吃蛇）。给了这个就画点阵，忽略 [lines]。
  final LcdGrid? grid;

  /// 反白显示的行号（主菜单、通讯录用）。
  final int? highlightedLine;

  final String softLeft;
  final String softRight;

  /// 状态栏是否显示信封图标。有未读短信时才亮。
  final bool showEnvelope;

  /// 状态栏左上角的小字提示（`ABC` / `abc` / 游戏分数）。只在需要时出现。
  final String? capsLabel;
}

/// 一块单色点阵。
///
/// 屏幕本来就是像素网格，用字符拼图是绕远路——直接把格子给渲染层。
class LcdGrid {
  const LcdGrid({
    required this.columns,
    required this.rows,
    required this.cells,
  });

  final int columns;
  final int rows;

  /// 行优先，每格是否点亮。
  final List<bool> cells;

  bool at(int x, int y) => cells[y * columns + x];
}
