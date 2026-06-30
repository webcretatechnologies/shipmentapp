import 'package:flutter/material.dart';

import '../../app/flavor.dart';
import '../theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Shared design-system widgets for the mobile app (orange + dark-navy theme).
/// ─────────────────────────────────────────────────────────────────────────

/// Dark navy header used at the top of the dashboard and detail screens.
/// [overline] renders small ABOVE the title; [subtitle] small BELOW it.
/// [child] holds extra dark-region content (a stat strip, a scan area, …).
class DarkHeader extends StatelessWidget {
  const DarkHeader({
    super.key,
    required this.title,
    this.overline,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.child,
  });

  final String title;
  final String? overline;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: Pwa.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (onBack != null) ...[
                    DarkIconButton(icon: Icons.arrow_back_ios_new, onTap: onBack!),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (overline != null && overline!.isNotEmpty)
                          Text(
                            overline!.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (child != null) ...[const SizedBox(height: 18), child!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle translucent icon button for the dark header (back / logout / refresh).
class DarkIconButton extends StatelessWidget {
  const DarkIconButton({super.key, required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

/// One cell of a [StatStrip].
class StatItem {
  const StatItem(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;
}

/// Dark, translucent 3-up stat strip shown inside a [DarkHeader].
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.items});
  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 34, color: Colors.white.withOpacity(0.10)),
            Expanded(
              child: Column(
                children: [
                  Text(items[i].value,
                      style: TextStyle(
                          color: items[i].color, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(items[i].label,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small uppercase muted section label ("QUICK ACCESS", "PENDING BOXES").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});
  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Pwa.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Colored status pill (auto-colored from the status text).
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

/// Standard white card container used across the list screens.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding ?? const EdgeInsets.all(16), child: child);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Pwa.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A white app bar with a rounded light back button, matching the list-screen
/// mockups. Use as `appBar: lightAppBar(context, 'Title')`.
PreferredSizeWidget lightAppBar(BuildContext context, String title,
    {List<Widget>? actions, bool back = true, PreferredSizeWidget? bottom}) {
  return AppBar(
    titleSpacing: back ? 4 : 16,
    leading: back
        ? Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _RoundedBack(onTap: () => Navigator.of(context).maybePop()),
          )
        : null,
    leadingWidth: back ? 56 : null,
    title: Text(title),
    actions: actions,
    bottom: bottom,
  );
}

class _RoundedBack extends StatelessWidget {
  const _RoundedBack({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Pwa.border),
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Pwa.text),
        ),
      ),
    );
  }
}
