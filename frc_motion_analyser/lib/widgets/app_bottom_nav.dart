import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Tab bar destinations — DESIGN SPEC.md §3 版面: 主頁 / 客戶 / 評估 / 進度.
enum AppTab { home, clients, assess, progress }

/// Tab bar — DESIGN SPEC.md §1 形狀: 高78, 背景 rgba(10,10,10,.92) + blur.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onTap,
  });

  final AppTab current;
  final ValueChanged<AppTab> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: AppSpacing.tabBarHeight,
          padding: const EdgeInsets.only(bottom: 14),
          decoration: const BoxDecoration(
            // rgba(10,10,10,.92)
            color: Color(0xEB0A0A0A),
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: '主頁',
                active: current == AppTab.home,
                onTap: () => onTap(AppTab.home),
              ),
              _NavItem(
                icon: Icons.people_alt_rounded,
                label: '客戶',
                active: current == AppTab.clients,
                onTap: () => onTap(AppTab.clients),
              ),
              _NavItem(
                icon: Icons.adjust_rounded,
                label: '評估',
                active: current == AppTab.assess,
                onTap: () => onTap(AppTab.assess),
              ),
              _NavItem(
                icon: Icons.trending_up_rounded,
                label: '進度',
                active: current == AppTab.progress,
                onTap: () => onTap(AppTab.progress),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.orange : AppColors.muted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label, style: AppText.data(size: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
