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
    backgroundColor: Pwa.primaryDark,
    foregroundColor: Colors.white,
    elevation: 0,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    // Container (not DecoratedBox) fills the flexibleSpace so the gradient
    // actually paints; primaryDark above is a solid fallback.
    flexibleSpace: Container(decoration: const BoxDecoration(gradient: Pwa.headerGradient)),
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

/// A PWA-style stat card (.ws-stat): white→teal gradient, teal top accent bar,
/// big value + uppercase label. Matches the warehouse PWA pixel-for-pixel.
class PwaCounter extends StatelessWidget {
  const PwaCounter({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          gradient: Pwa.cardGradient,
          borderRadius: BorderRadius.circular(Pwa.radius),
          border: Border.all(color: Pwa.primaryBorder),
          boxShadow: const [
            BoxShadow(color: Color(0x0F0F172A), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // top 3px teal accent bar (linear-gradient(90deg,#028894,#03a0ad))
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Pwa.primary, Pwa.primaryMid]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value,
                        style: const TextStyle(
                            fontSize: 21,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Pwa.primaryDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Pwa.muted,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PWA segmented-pill control (.ws-seg): the Scan log / Boxes / Expected tabs.
/// Active pill = teal bg + white text; inactive = white bg, muted text, border.
class PwaSegmented extends StatelessWidget {
  const PwaSegmented({super.key, required this.tabs, required this.index, required this.onChanged});
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Pwa.bg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _pill(tabs[i], i == index, () => onChanged(i))),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Pwa.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? Pwa.primary : Pwa.border),
          boxShadow: [
            BoxShadow(
              color: active ? Pwa.primary.withOpacity(0.22) : const Color(0x0F0F172A),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Pwa.muted)),
      ),
    );
  }
}
