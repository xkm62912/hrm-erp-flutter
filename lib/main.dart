import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/colors.dart';
import 'providers/providers.dart';
import 'screens/login.dart';
import 'screens/dashboard.dart';
import 'screens/employees.dart';
import 'screens/attendance.dart';
import 'screens/leave.dart';
import 'screens/payroll.dart';
import 'screens/crm.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://iuuzzlcyaduhmhkfecgp.supabase.co',
    publishableKey:
        'sb_publishable_y75qrANkJn-2NmfU4LLfig_1CPC-S6I',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  runApp(const ProviderScope(child: HRMApp()));
}

class HRMApp extends ConsumerWidget {
  const HRMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isLoggedIn = auth.valueOrNull != null ||
        Supabase.instance.client.auth.currentSession != null;

    return MaterialApp(
      title: 'HRM ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
      home: isLoggedIn ? const MainShell() : const LoginScreen(),
    );
  }
}

// ── Main Shell with Bottom Navigation ────────────────────────
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _tabs = [
    _Tab('Dashboard',  Icons.dashboard_rounded,     Icons.dashboard_outlined),
    _Tab('Employees',  Icons.people_rounded,         Icons.people_outline_rounded),
    _Tab('Attendance', Icons.fingerprint_rounded,    Icons.fingerprint),
    _Tab('Leave',      Icons.event_busy_rounded,     Icons.event_busy_outlined),
    _Tab('Payroll',    Icons.payments_rounded,       Icons.payments_outlined),
  ];

  static const _pages = <Widget>[
    DashboardScreen(),
    EmployeesScreen(),
    AttendanceScreen(),
    LeaveScreen(),
    PayrollScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ))
            .toList(),
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.crmColor,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CrmScreen())),
              child: const Icon(Icons.handshake_rounded, color: Colors.white),
            )
          : null,
    );
  }
}

class _Tab {
  final String label;
  final IconData activeIcon, icon;
  const _Tab(this.label, this.activeIcon, this.icon);
}
