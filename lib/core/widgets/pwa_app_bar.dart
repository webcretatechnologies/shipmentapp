import 'package:flutter/material.dart';

import '../../app/flavor.dart';

/// The PWA's teal gradient header bar — used across all screens so the mobile
/// app matches the warehouse PWA look.
PreferredSizeWidget pwaAppBar(
  String title, {
  String? subtitle,
  List<Widget>? actions,
  bool back = true,
}) {
  return AppBar(
    automaticallyImplyLeading: back,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: Pwa.headerGradient)),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        if (subtitle != null && subtitle.isNotEmpty)
          Text(subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    ),
    actions: actions,
  );
}

/// A PWA-style counter pill (white→teal gradient, value + label).
class PwaCounter extends StatelessWidget {
  const PwaCounter({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: Pwa.cardGradient,
          borderRadius: BorderRadius.circular(Pwa.radius),
          border: Border.all(color: Pwa.primaryBorder.withOpacity(0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: Pwa.primaryDark)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Pwa.muted, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}
