import 'package:flutter/material.dart';

import '../../app/flavor.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_ui.dart';
import '../box_scanning/box_scanning_screen.dart';
import '../racking/racking_screen.dart';

/// Racking Area + Box Scanning in a single screen with two tabs — the two steps
/// are handled in the same place (as requested), instead of two separate cards.
class RackingBoxScreen extends StatelessWidget {
  const RackingBoxScreen({super.key, this.initialTab = 0});

  /// 0 = Racking, 1 = Box Scanning.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: lightAppBar(
          context,
          'Racking & Box Scanning',
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.65),
            indicatorColor: Colors.white,
            indicatorWeight: 2.4,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: [
              Tab(text: 'Racking'),
              Tab(text: 'Box Scanning'),
            ],
          ),
        ),
        bottomNavigationBar: const AppBottomNav(current: 2),
        body: const TabBarView(
          children: [
            RackingScreen(embedded: true),
            BoxScanningScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
