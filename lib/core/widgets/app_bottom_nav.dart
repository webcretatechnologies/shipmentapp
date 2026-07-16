import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/flavor.dart';

/// Persistent bottom nav — Home / Scan / Racking / Kitting (mockup). Shown on the
/// four primary screens so it stays put as the user moves between them. "Scan"
/// opens the shipments list to pick a shipment to scan.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});

  /// 0=Home 1=Shipments(Scan) 2=Racking 3=Kitting.
  final int current;

  void _go(BuildContext context, int i) {
    if (i == current) return;
    switch (i) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/shipments');
        break;
      case 2:
        context.go('/racking');
        break;
      case 3:
        context.go('/kitting');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current,
      backgroundColor: Colors.white,
      indicatorColor: Pwa.primaryLight,
      onDestinationSelected: (i) => _go(context, i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), label: 'Scan'),
        NavigationDestination(icon: Icon(Icons.dns_outlined), label: 'Racking'),
        NavigationDestination(icon: Icon(Icons.hexagon_outlined), label: 'Kitting'),
      ],
    );
  }
}
