// lib/core/router/app_router.dart
// ALL imports at top — no @riverpod, no part directive

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../presentation/modules/auth/splash_screen.dart';
import '../../presentation/modules/auth/login_screen.dart';
import '../../presentation/modules/dashboard/dashboard_screen.dart';
import '../../presentation/modules/employees/employee_screens.dart';
import '../../presentation/modules/attendance/attendance_screen.dart';
import '../../presentation/modules/leave/leave_screens.dart';
import '../../presentation/modules/payroll/payroll_screens.dart';
import '../../presentation/modules/crm/crm_screens.dart';
import '../../presentation/shared/widgets/main_shell.dart';
import '../../presentation/providers/all_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = Supabase.instance.client.auth.currentSession != null ||
          authState.valueOrNull?.session != null;
      final loc = state.matchedLocation;
      if (loc == '/splash') return null;
      if (!isAuth && loc != '/login') return '/login';
      if (isAuth && loc == '/login') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/employees',
            builder: (_, __) => const EmployeeListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) => const EmployeeFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    EmployeeDetailScreen(id: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, s) => EmployeeFormScreen(
                        employeeId: s.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/attendance',
            builder: (_, __) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/leave',
            builder: (_, __) => const LeaveListScreen(),
            routes: [
              GoRoute(
                path: 'request',
                builder: (_, __) => const LeaveRequestScreen(),
              ),
              GoRoute(
                path: 'approval',
                builder: (_, __) => const LeaveApprovalScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/payroll',
            builder: (_, __) => const PayrollListScreen(),
            routes: [
              GoRoute(
                path: 'run',
                builder: (_, __) => const PayrollRunScreen(),
              ),
              GoRoute(
                path: 'payslip/:id',
                builder: (_, s) =>
                    PayslipDetailScreen(payslipId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/crm',
            builder: (_, __) => const CrmDashboardScreen(),
            routes: [
              GoRoute(
                path: 'leads',
                builder: (_, __) => const LeadListScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (_, __) => const LeadFormScreen(),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    builder: (_, s) =>
                        LeadFormScreen(leadId: s.pathParameters['id']),
                  ),
                ],
              ),
              GoRoute(
                path: 'clients',
                builder: (_, __) => const ClientListScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => GoRouter.of(context).go('/dashboard'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
