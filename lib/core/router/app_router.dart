import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../presentation/modules/auth/login_screen.dart';
import '../presentation/modules/auth/splash_screen.dart';
import '../presentation/modules/dashboard/dashboard_screen.dart';
import '../presentation/modules/employees/employee_list_screen.dart';
import '../presentation/modules/employees/employee_detail_screen.dart';
import '../presentation/modules/employees/employee_form_screen.dart';
import '../presentation/modules/attendance/attendance_screen.dart';
import '../presentation/modules/leave/leave_list_screen.dart';
import '../presentation/modules/leave/leave_request_screen.dart';
import '../presentation/modules/leave/leave_approval_screen.dart';
import '../presentation/modules/payroll/payroll_list_screen.dart';
import '../presentation/modules/payroll/payroll_run_screen.dart';
import '../presentation/modules/payroll/payslip_detail_screen.dart';
import '../presentation/modules/crm/crm_dashboard_screen.dart';
import '../presentation/modules/crm/lead_list_screen.dart';
import '../presentation/modules/crm/lead_form_screen.dart';
import '../presentation/modules/crm/client_list_screen.dart';
import '../presentation/shared/widgets/main_shell.dart';
import '../presentation/providers/auth_provider.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isOnAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/splash';

      if (state.matchedLocation == '/splash') return null;
      if (!isAuthenticated && !isOnAuth) return '/login';
      if (isAuthenticated && state.matchedLocation == '/login') return '/dashboard';
      return null;
    },
    routes: [
      // ── Splash ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Main Shell (Bottom Nav) ───────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),

          // ── Employees ──────────────────────────────────────────────────
          GoRoute(
            path: '/employees',
            name: 'employees',
            builder: (_, __) => const EmployeeListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'employee-add',
                builder: (_, __) => const EmployeeFormScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'employee-detail',
                builder: (_, state) =>
                    EmployeeDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'employee-edit',
                    builder: (_, state) => EmployeeFormScreen(
                      employeeId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Attendance ────────────────────────────────────────────────
          GoRoute(
            path: '/attendance',
            name: 'attendance',
            builder: (_, __) => const AttendanceScreen(),
          ),

          // ── Leave ─────────────────────────────────────────────────────
          GoRoute(
            path: '/leave',
            name: 'leave',
            builder: (_, __) => const LeaveListScreen(),
            routes: [
              GoRoute(
                path: 'request',
                name: 'leave-request',
                builder: (_, __) => const LeaveRequestScreen(),
              ),
              GoRoute(
                path: 'approval',
                name: 'leave-approval',
                builder: (_, __) => const LeaveApprovalScreen(),
              ),
            ],
          ),

          // ── Payroll ───────────────────────────────────────────────────
          GoRoute(
            path: '/payroll',
            name: 'payroll',
            builder: (_, __) => const PayrollListScreen(),
            routes: [
              GoRoute(
                path: 'run',
                name: 'payroll-run',
                builder: (_, __) => const PayrollRunScreen(),
              ),
              GoRoute(
                path: 'payslip/:id',
                name: 'payslip-detail',
                builder: (_, state) =>
                    PayslipDetailScreen(payslipId: state.pathParameters['id']!),
              ),
            ],
          ),

          // ── CRM ───────────────────────────────────────────────────────
          GoRoute(
            path: '/crm',
            name: 'crm',
            builder: (_, __) => const CrmDashboardScreen(),
            routes: [
              GoRoute(
                path: 'leads',
                name: 'leads',
                builder: (_, __) => const LeadListScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'lead-add',
                    builder: (_, __) => const LeadFormScreen(),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    name: 'lead-edit',
                    builder: (_, state) =>
                        LeadFormScreen(leadId: state.pathParameters['id']),
                  ),
                ],
              ),
              GoRoute(
                path: 'clients',
                name: 'clients',
                builder: (_, __) => const ClientListScreen(),
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
