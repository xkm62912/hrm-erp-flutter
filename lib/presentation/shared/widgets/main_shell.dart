import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _NavTab('/dashboard', Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
    _NavTab('/employees', Icons.people_rounded, Icons.people_outline_rounded, 'Employees'),
    _NavTab('/attendance', Icons.fingerprint_rounded, Icons.fingerprint, 'Attendance'),
    _NavTab('/leave', Icons.event_busy_rounded, Icons.event_busy_outlined, 'Leave'),
    _NavTab('/payroll', Icons.payments_rounded, Icons.payments_outlined, 'Payroll'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isSelected = i == idx;
                return Expanded(
                  child: InkWell(
                    onTap: () => context.go(tab.path),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? tab.activeIcon : tab.icon,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textHint,
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String path;
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _NavTab(this.path, this.activeIcon, this.icon, this.label);
}
