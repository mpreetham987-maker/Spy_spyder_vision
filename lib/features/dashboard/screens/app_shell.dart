import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../ai_detection/screens/ai_detection_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'camera_control_screen.dart';
import 'dashboard_home_screen.dart';

/// Hosts the persistent bottom navigation bar and swaps between the
/// app's four destinations: Dashboard (status), Control (camera feed
/// + gamepad), AI Detection (its own camera feed + detection toggle),
/// and Settings.
///
/// Using an [IndexedStack] keeps the camera stream connection and any
/// in-flight animations alive when switching back and forth.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = [
    _NavDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
      outlinedIcon: Icons.dashboard_outlined,
    ),
    _NavDestination(
      label: 'Control',
      icon: Icons.videogame_asset_rounded,
      outlinedIcon: Icons.videogame_asset_outlined,
    ),
    _NavDestination(
      label: 'AI',
      icon: Icons.center_focus_strong_rounded,
      outlinedIcon: Icons.center_focus_weak_outlined,
    ),
    _NavDestination(
      label: 'Settings',
      icon: Icons.tune_rounded,
      outlinedIcon: Icons.tune_outlined,
    ),
  ];

  void _onTabSelected(int index) => setState(() => _index = index);

  /// Lets child screens (e.g. Dashboard's quick-jump buttons)
  /// programmatically switch tabs.
  void navigateToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: IndexedStack(
        index: _index,
        children: [
          DashboardHomeScreen(onNavigateToTab: navigateToTab),
          const CameraControlScreen(),
          const AiDetectionScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _GlassBottomNav(
        destinations: _destinations,
        currentIndex: _index,
        onSelected: _onTabSelected,
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.outlinedIcon,
  });

  final String label;
  final IconData icon;
  final IconData outlinedIcon;
}

/// A frosted bottom navigation bar, styled to match the dashboard's
/// glassmorphism language rather than using the default Material bar.
class _GlassBottomNav extends StatelessWidget {
  const _GlassBottomNav({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<_NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.charcoalElevated.withValues(alpha: 0.92),
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < destinations.length; i++)
            _NavItem(
              destination: destinations[i],
              selected: i == currentIndex,
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.cyan : AppColors.textTertiary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.icon : destination.outlinedIcon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
