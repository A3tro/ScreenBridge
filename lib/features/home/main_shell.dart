import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../../data/app_controller.dart';
import '../calendar/calendar_screen.dart';
import '../home/home_screen.dart';
import '../inbox/inbox_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/scan_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  late final AnimationController entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  final screens = [HomeScreen(), CalendarScreen(), ScanScreen(), InboxScreen(), ProfileScreen()];
  final labels = ['Home', 'Calendar', 'Scan', 'Inbox', 'Profile'];
  final icons = [Icons.home_outlined, Icons.calendar_month_outlined, Icons.document_scanner_outlined,
    Icons.notifications_none_rounded, Icons.person_outline_rounded];
  int lastTab = 0;
  double direction = 1;

  @override void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.of(context).currentTab;
    if (lastTab != next) {
      direction = next > lastTab ? 1 : -1;
      lastTab = next;
      if (!MediaQuery.of(context).disableAnimations) { entrance.forward(from: 0); } else { entrance.value = 1; }
    }
  }

  @override void dispose() { entrance.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = AppPalette.of(context);
    final reduced = MediaQuery.of(context).disableAnimations;
    final dur = reduced ? Duration.zero : const Duration(milliseconds: 380);
    return Scaffold(
      body: AnimatedBuilder(animation: entrance, builder: (_, child) => Opacity(
        opacity: .55 + .45 * entrance.value,
        child: Transform.translate(offset: Offset((1 - Curves.easeOutCubic.transform(entrance.value)) * 18 * direction, 0), child: child)),
        // すべてのタブの状態を保ったまま、見えていないタブのアニメーションは止める
        child: IndexedStack(index: app.currentTab, children: List.generate(screens.length, (i) =>
          TickerMode(enabled: app.currentTab == i, child: screens[i])))),
      bottomNavigationBar: SafeArea(top: false, child: SizedBox(height: 88, child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / screens.length;
        return Stack(clipBehavior: Clip.none, children: [
          // 白い土台
          Positioned(left: 0, right: 0, bottom: 0, height: 66, child: Container(decoration: BoxDecoration(
            color: p.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, -4))]))),
          // 選んだボタン（丸く浮き上がって、すべって動く）
          AnimatedPositioned(duration: dur, curve: Curves.easeOutBack, top: 0, left: w * app.currentTab + w / 2 - 31,
            child: Container(width: 62, height: 62,
              decoration: BoxDecoration(color: p.butter, shape: BoxShape.circle,
                border: Border.all(color: p.ivory, width: 6),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))]),
              child: Center(child: AnimatedSwitcher(duration: dur,
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: AppIcon(icons[app.currentTab], key: ValueKey(app.currentTab), size: 24, color: p.navy))))),
          // 5つのボタン
          Positioned(left: 0, right: 0, bottom: 0, height: 66, child: Row(children: List.generate(screens.length, (i) {
            final active = app.currentTab == i;
            return Expanded(child: Semantics(selected: active, button: true, label: labels[i], child: InkWell(
              onTap: () => app.setTab(i),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                AnimatedOpacity(duration: dur, opacity: active ? 0 : 1, child: Stack(clipBehavior: Clip.none, children: [
                  AppIcon(icons[i], size: 23, color: p.muted),
                  if (i == 3 && app.unreadCount > 0) Positioned(right: -3, top: -2, child: Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: p.danger, shape: BoxShape.circle))),
                ])),
                const SizedBox(height: 5),
                Text(labels[i], style: TextStyle(fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? p.navy : p.muted)),
                const SizedBox(height: 10),
              ]))));
          }))),
        ]);
      }))),
    );
  }
}