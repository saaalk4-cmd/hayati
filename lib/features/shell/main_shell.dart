import 'package:go_router/go_router.dart';

import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/palettes.dart';

/// الشريط السفلي: يومي، عباداتي، مهامي، فلوسي، المزيد
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: shell,
      // شريط عائم زجاجي بزوايا مدورة وحافة ذهبي
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.bgTop.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: p.cardBorder),
              ),
              child: NavigationBar(
                height: 68,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: shell.currentIndex,
                onDestinationSelected: (i) =>
                    shell.goBranch(i, initialLocation: i == shell.currentIndex),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'يومي',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.mosque_outlined),
                    selectedIcon: Icon(Icons.mosque),
                    label: 'عباداتي',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.checklist_rtl),
                    selectedIcon: Icon(Icons.checklist_rtl),
                    label: 'مهامي',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: Icon(Icons.account_balance_wallet),
                    label: 'فلوسي',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    selectedIcon: Icon(Icons.more_horiz),
                    label: 'المزيد',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
