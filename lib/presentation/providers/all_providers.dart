// lib/presentation/providers/all_providers.dart
// Plain Riverpod providers — no code generation required

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ════════════════════════════════════════════════════════════
// CORE
// ════════════════════════════════════════════════════════════

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// ════════════════════════════════════════════════════════════
// AUTH
// ════════════════════════════════════════════════════════════

final authStateProvider = StreamProvider<AuthState>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange,
);

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>(
  (ref) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier()
      : super(AsyncValue.data(Supabase.instance.client.auth.currentUser));

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await _client.auth
          .signInWithPassword(email: email, password: password);
      state = AsyncValue.data(res.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<String?> getUserRole() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final res = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', uid)
        .maybeSingle();
    return res?['role'] as String?;
  }
}

final userRoleProvider = FutureProvider<String?>((ref) async {
  return ref.read(authNotifierProvider.notifier).getUserRole();
});

// ════════════════════════════════════════════════════════════
// ROUTER
// ════════════════════════════════════════════════════════════

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull?.session != null ||
          Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;
      if (loc == '/splash') return null;
      if (!isAuthenticated && loc != '/login') return '/login';
      if (isAuthenticated && loc == '/login') return '/dashboard';
      return null;
    },
    routes: _buildRoutes(),
    errorBuilder: (ctx, state) => _ErrorPage(uri: state.uri.toString()),
  );
});

List<RouteBase> _buildRoutes() {
  return [
    GoRoute(path: '/splash', builder: (_, __) => const _SplashRedirect()),
    GoRoute(
        path: '/login',
        builder: (_, __) {
          // Lazy import to avoid circular
          return const _LoginPlaceholder();
        }),
    ShellRoute(
      builder: (_, __, child) => _MainShellWrapper(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const _DashPlaceholder()),
        GoRoute(
          path: '/employees',
          builder: (_, __) => const _EmpListPlaceholder(),
          routes: [
            GoRoute(path: 'add', builder: (_, __) => const _EmpFormPlaceholder()),
            GoRoute(
              path: ':id',
              builder: (_, state) =>
                  _EmpDetailPlaceholder(id: state.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, state) => _EmpFormPlaceholder(
                      employeeId: state.pathParameters['id']),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/attendance', builder: (_, __) => const _AttPlaceholder()),
        GoRoute(
          path: '/leave',
          builder: (_, __) => const _LeaveListPlaceholder(),
          routes: [
            GoRoute(path: 'request', builder: (_, __) => const _LeaveReqPlaceholder()),
            GoRoute(path: 'approval', builder: (_, __) => const _LeaveAppPlaceholder()),
          ],
        ),
        GoRoute(
          path: '/payroll',
          builder: (_, __) => const _PayrollListPlaceholder(),
          routes: [
            GoRoute(path: 'run', builder: (_, __) => const _PayrollRunPlaceholder()),
            GoRoute(
                path: 'payslip/:id',
                builder: (_, state) =>
                    _PayslipPlaceholder(id: state.pathParameters['id']!)),
          ],
        ),
        GoRoute(
          path: '/crm',
          builder: (_, __) => const _CrmDashPlaceholder(),
          routes: [
            GoRoute(
              path: 'leads',
              builder: (_, __) => const _LeadListPlaceholder(),
              routes: [
                GoRoute(path: 'add', builder: (_, __) => const _LeadFormPlaceholder()),
                GoRoute(
                    path: ':id/edit',
                    builder: (_, state) =>
                        _LeadFormPlaceholder(leadId: state.pathParameters['id'])),
              ],
            ),
            GoRoute(path: 'clients', builder: (_, __) => const _ClientListPlaceholder()),
          ],
        ),
      ],
    ),
  ];
}

// Placeholder widgets that import the real screens
import 'package:flutter/material.dart';
import '../modules/auth/splash_screen.dart';
import '../modules/auth/login_screen.dart';
import '../modules/dashboard/dashboard_screen.dart';
import '../modules/employees/employee_screens.dart';
import '../modules/attendance/attendance_screen.dart';
import '../modules/leave/leave_screens.dart';
import '../modules/payroll/payroll_screens.dart';
import '../modules/crm/crm_screens.dart';
import '../shared/widgets/main_shell.dart';

class _SplashRedirect extends StatelessWidget {
  const _SplashRedirect();
  @override
  Widget build(BuildContext context) => const SplashScreen();
}

class _LoginPlaceholder extends StatelessWidget {
  const _LoginPlaceholder();
  @override
  Widget build(BuildContext context) => const LoginScreen();
}

class _MainShellWrapper extends StatelessWidget {
  final Widget child;
  const _MainShellWrapper({required this.child});
  @override
  Widget build(BuildContext context) => MainShell(child: child);
}

class _DashPlaceholder extends StatelessWidget {
  const _DashPlaceholder();
  @override
  Widget build(BuildContext context) => const DashboardScreen();
}

class _EmpListPlaceholder extends StatelessWidget {
  const _EmpListPlaceholder();
  @override
  Widget build(BuildContext context) => const EmployeeListScreen();
}

class _EmpDetailPlaceholder extends StatelessWidget {
  final String id;
  const _EmpDetailPlaceholder({required this.id});
  @override
  Widget build(BuildContext context) => EmployeeDetailScreen(id: id);
}

class _EmpFormPlaceholder extends StatelessWidget {
  final String? employeeId;
  const _EmpFormPlaceholder({this.employeeId});
  @override
  Widget build(BuildContext context) => EmployeeFormScreen(employeeId: employeeId);
}

class _AttPlaceholder extends StatelessWidget {
  const _AttPlaceholder();
  @override
  Widget build(BuildContext context) => const AttendanceScreen();
}

class _LeaveListPlaceholder extends StatelessWidget {
  const _LeaveListPlaceholder();
  @override
  Widget build(BuildContext context) => const LeaveListScreen();
}

class _LeaveReqPlaceholder extends StatelessWidget {
  const _LeaveReqPlaceholder();
  @override
  Widget build(BuildContext context) => const LeaveRequestScreen();
}

class _LeaveAppPlaceholder extends StatelessWidget {
  const _LeaveAppPlaceholder();
  @override
  Widget build(BuildContext context) => const LeaveApprovalScreen();
}

class _PayrollListPlaceholder extends StatelessWidget {
  const _PayrollListPlaceholder();
  @override
  Widget build(BuildContext context) => const PayrollListScreen();
}

class _PayrollRunPlaceholder extends StatelessWidget {
  const _PayrollRunPlaceholder();
  @override
  Widget build(BuildContext context) => const PayrollRunScreen();
}

class _PayslipPlaceholder extends StatelessWidget {
  final String id;
  const _PayslipPlaceholder({required this.id});
  @override
  Widget build(BuildContext context) => PayslipDetailScreen(payslipId: id);
}

class _CrmDashPlaceholder extends StatelessWidget {
  const _CrmDashPlaceholder();
  @override
  Widget build(BuildContext context) => const CrmDashboardScreen();
}

class _LeadListPlaceholder extends StatelessWidget {
  const _LeadListPlaceholder();
  @override
  Widget build(BuildContext context) => const LeadListScreen();
}

class _LeadFormPlaceholder extends StatelessWidget {
  final String? leadId;
  const _LeadFormPlaceholder({this.leadId});
  @override
  Widget build(BuildContext context) => LeadFormScreen(leadId: leadId);
}

class _ClientListPlaceholder extends StatelessWidget {
  const _ClientListPlaceholder();
  @override
  Widget build(BuildContext context) => const ClientListScreen();
}

class _ErrorPage extends StatelessWidget {
  final String uri;
  const _ErrorPage({required this.uri});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: $uri'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go Home'),
            ),
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════
// EMPLOYEE PROVIDERS
// ════════════════════════════════════════════════════════════

final employeesProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({String search, String? status, String? departmentId})>((ref, params) async {
  final client = ref.watch(supabaseClientProvider);
  var query = client
      .from('employees')
      .select('*, departments(name)')
      .order('first_name');
  if (params.status != null && params.status!.isNotEmpty) {
    query = query.eq('status', params.status!) as dynamic;
  }
  if (params.departmentId != null) {
    query = query.eq('department_id', params.departmentId!) as dynamic;
  }
  if (params.search.isNotEmpty) {
    query = query.or(
      'first_name.ilike.%${params.search}%,last_name.ilike.%${params.search}%,emp_code.ilike.%${params.search}%',
    ) as dynamic;
  }
  return List<Map<String, dynamic>>.from(await query as List);
});

// Convenience overloads
final employeesProviderDefault = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(employeesProvider((search: '', status: null, departmentId: null)).future);
});

final employeeDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('employees')
      .select('*, departments(name), salary_structures(*)')
      .eq('id', id)
      .single();
  return Map<String, dynamic>.from(data);
});

final employeeStatsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final all = await client.from('employees').select('status, join_date');
  final list = List<Map<String, dynamic>>.from(all as List);
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  return {
    'total': list.length,
    'active': list.where((e) => e['status'] == 'active').length,
    'inactive': list.where((e) => e['status'] == 'inactive').length,
    'on_leave': list.where((e) => e['status'] == 'on_leave').length,
    'new': list.where((e) {
      final d = DateTime.tryParse(e['join_date'] ?? '');
      return d != null && d.isAfter(cutoff);
    }).length,
  };
});

final departmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(
      await client.from('departments').select().order('name') as List);
});

// ════════════════════════════════════════════════════════════
// ATTENDANCE PROVIDERS
// ════════════════════════════════════════════════════════════

final todayAttendanceProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return null;
  final emp = await client
      .from('employees')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();
  if (emp == null) return null;
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final data = await client
      .from('attendance')
      .select()
      .eq('employee_id', emp['id'])
      .eq('date', today)
      .maybeSingle();
  return data != null ? Map<String, dynamic>.from(data) : null;
});

final monthlyAttendanceProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    ({int month, int year, String? employeeId})>((ref, p) async {
  final client = ref.watch(supabaseClientProvider);
  String? empId = p.employeeId;
  if (empId == null) {
    final user = client.auth.currentUser;
    if (user == null) return [];
    final emp = await client
        .from('employees')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();
    empId = emp?['id'] as String?;
    if (empId == null) return [];
  }
  final start =
      '${p.year}-${p.month.toString().padLeft(2, '0')}-01';
  final lastDay = DateTime(p.year, p.month + 1, 0).day;
  final end =
      '${p.year}-${p.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
  final data = await client
      .from('attendance')
      .select()
      .eq('employee_id', empId)
      .gte('date', start)
      .lte('date', end)
      .order('date');
  return List<Map<String, dynamic>>.from(data as List);
});

final attendanceActionProvider =
    StateNotifierProvider<AttendanceActionNotifier, AsyncValue<void>>(
  (_) => AttendanceActionNotifier(),
);

class AttendanceActionNotifier extends StateNotifier<AsyncValue<void>> {
  AttendanceActionNotifier() : super(const AsyncValue.data(null));

  SupabaseClient get _c => Supabase.instance.client;

  Future<void> checkIn() async {
    state = const AsyncValue.loading();
    try {
      final emp = await _c
          .from('employees')
          .select('id')
          .eq('user_id', _c.auth.currentUser!.id)
          .single();
      final now = DateTime.now();
      final isLate = now.hour > 9 || (now.hour == 9 && now.minute > 0);
      await _c.from('attendance').upsert({
        'employee_id': emp['id'],
        'date': now.toIso8601String().substring(0, 10),
        'check_in': now.toIso8601String(),
        'status': isLate ? 'late' : 'present',
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> checkOut() async {
    state = const AsyncValue.loading();
    try {
      final emp = await _c
          .from('employees')
          .select('id')
          .eq('user_id', _c.auth.currentUser!.id)
          .single();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await _c.from('attendance').update({
        'check_out': DateTime.now().toIso8601String(),
      }).eq('employee_id', emp['id']).eq('date', today);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ════════════════════════════════════════════════════════════
// LEAVE PROVIDERS
// ════════════════════════════════════════════════════════════

final leaveTypesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(
      await client.from('leave_types').select().eq('is_active', true).order('name') as List);
});

final myLeaveRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final emp = await client
      .from('employees')
      .select('id')
      .eq('user_id', client.auth.currentUser!.id)
      .single();
  return List<Map<String, dynamic>>.from(await client
      .from('leave_requests')
      .select('*, leave_types(name, is_paid)')
      .eq('employee_id', emp['id'])
      .order('applied_at', ascending: false) as List);
});

final pendingLeaveApprovalsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await client
      .from('leave_requests')
      .select('*, leave_types(name), employees!employee_id(first_name, last_name, designation)')
      .eq('status', 'pending')
      .order('applied_at') as List);
});

final myLeaveBalancesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final emp = await client
      .from('employees')
      .select('id')
      .eq('user_id', client.auth.currentUser!.id)
      .single();
  return List<Map<String, dynamic>>.from(await client
      .from('leave_balances')
      .select('*, leave_types(name, max_days_per_year)')
      .eq('employee_id', emp['id'])
      .eq('year', DateTime.now().year) as List);
});

final leaveRequestNotifierProvider =
    StateNotifierProvider<LeaveRequestNotifier, AsyncValue<void>>(
  (_) => LeaveRequestNotifier(),
);

class LeaveRequestNotifier extends StateNotifier<AsyncValue<void>> {
  LeaveRequestNotifier() : super(const AsyncValue.data(null));
  SupabaseClient get _c => Supabase.instance.client;

  Future<bool> submitRequest({
    required String leaveTypeId,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final emp = await _c
          .from('employees')
          .select('id')
          .eq('user_id', _c.auth.currentUser!.id)
          .single();
      final totalDays = toDate.difference(fromDate).inDays + 1;
      await _c.from('leave_requests').insert({
        'employee_id': emp['id'],
        'leave_type_id': leaveTypeId,
        'from_date': fromDate.toIso8601String().substring(0, 10),
        'to_date': toDate.toIso8601String().substring(0, 10),
        'total_days': totalDays,
        'reason': reason,
        'status': 'pending',
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateStatus(
      String requestId, String status, String approverId) async {
    state = const AsyncValue.loading();
    try {
      await _c.from('leave_requests').update({
        'status': status,
        'approved_by': approverId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// ════════════════════════════════════════════════════════════
// PAYROLL PROVIDERS
// ════════════════════════════════════════════════════════════

final payrollRunsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await client
      .from('payroll_runs')
      .select()
      .order('year', ascending: false)
      .order('month', ascending: false) as List);
});

final payslipsForRunProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, runId) async {
  final client = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await client
      .from('payslips')
      .select('*, employees(first_name, last_name, emp_code, designation)')
      .eq('payroll_run_id', runId)
      .order('net_salary', ascending: false) as List);
});

final myLatestPayslipProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final emp = await client
      .from('employees')
      .select('id')
      .eq('user_id', client.auth.currentUser!.id)
      .maybeSingle();
  if (emp == null) return null;
  final data = await client
      .from('payslips')
      .select('*, payroll_runs(month, year)')
      .eq('employee_id', emp['id'])
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return data != null ? Map<String, dynamic>.from(data) : null;
});

final payrollRunNotifierProvider =
    StateNotifierProvider<PayrollRunNotifier, AsyncValue<String?>>(
  (_) => PayrollRunNotifier(),
);

class PayrollRunNotifier extends StateNotifier<AsyncValue<String?>> {
  PayrollRunNotifier() : super(const AsyncValue.data(null));
  SupabaseClient get _c => Supabase.instance.client;

  Future<bool> runPayroll({required int month, required int year}) async {
    state = const AsyncValue.loading();
    try {
      final processor = await _c
          .from('employees')
          .select('id')
          .eq('user_id', _c.auth.currentUser!.id)
          .single();

      final employees = await _c
          .from('employees')
          .select('*, salary_structures(*)')
          .eq('status', 'active');
      final empList = List<Map<String, dynamic>>.from(employees as List);

      final startDate =
          '$year-${month.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(year, month + 1, 0).day;
      final endDate =
          '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

      final attendance = await _c
          .from('attendance')
          .select('employee_id, status')
          .gte('date', startDate)
          .lte('date', endDate);
      final attList = List<Map<String, dynamic>>.from(attendance as List);

      int workDays = 0;
      for (int d = 1; d <= lastDay; d++) {
        final wd = DateTime(year, month, d).weekday;
        if (wd != 6 && wd != 7) workDays++;
      }

      final run = await _c.from('payroll_runs').insert({
        'month': month,
        'year': year,
        'status': 'processing',
        'processed_by': processor['id'],
        'processed_at': DateTime.now().toIso8601String(),
        'employee_count': empList.length,
      }).select().single();

      final runId = run['id'] as String;
      double totalGross = 0, totalDed = 0, totalNet = 0;
      final payslips = <Map<String, dynamic>>[];

      for (final emp in empList) {
        final structs = emp['salary_structures'] as List? ?? [];
        if (structs.isEmpty) continue;
        final sal = Map<String, dynamic>.from(structs.first as Map);
        final basic = (sal['basic_salary'] as num? ?? 0).toDouble();
        final house = (sal['house_allowance'] as num? ?? 0).toDouble();
        final transport = (sal['transport_allowance'] as num? ?? 0).toDouble();
        final medical = (sal['medical_allowance'] as num? ?? 0).toDouble();
        final meal = (sal['meal_allowance'] as num? ?? 0).toDouble();
        final other = (sal['other_allowance'] as num? ?? 0).toDouble();
        final tax = (sal['tax_deduction'] as num? ?? 0).toDouble();
        final ins = (sal['insurance_deduction'] as num? ?? 0).toDouble();
        final pf = (sal['provident_fund'] as num? ?? 0).toDouble();
        final gross = basic + house + transport + medical + meal + other;
        final perDay = workDays > 0 ? gross / workDays : 0.0;
        final present = attList
            .where((a) =>
                a['employee_id'] == emp['id'] &&
                (a['status'] == 'present' ||
                    a['status'] == 'late' ||
                    a['status'] == 'half_day'))
            .length;
        final absent = workDays - present;
        final absentDed = absent * perDay;
        final ded = tax + ins + pf + absentDed;
        final net = (gross - ded).clamp(0.0, double.infinity);
        totalGross += gross;
        totalDed += ded;
        totalNet += net;
        payslips.add({
          'payroll_run_id': runId,
          'employee_id': emp['id'],
          'basic_salary': basic,
          'house_allowance': house,
          'transport_allowance': transport,
          'medical_allowance': medical,
          'other_allowances': meal + other,
          'gross_salary': gross,
          'tax_deduction': tax,
          'insurance_deduction': ins,
          'provident_fund': pf,
          'absent_deduction': absentDed,
          'total_deductions': ded,
          'net_salary': net,
          'working_days': workDays,
          'paid_days': present,
          'absent_days': absent,
          'status': 'generated',
        });
      }

      if (payslips.isNotEmpty) {
        await _c.from('payslips').insert(payslips);
      }
      await _c.from('payroll_runs').update({
        'status': 'approved',
        'total_gross': totalGross,
        'total_deductions': totalDed,
        'total_net': totalNet,
        'employee_count': payslips.length,
      }).eq('id', runId);

      state = AsyncValue.data(runId);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// ════════════════════════════════════════════════════════════
// DASHBOARD PROVIDERS
// ════════════════════════════════════════════════════════════

final dashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final month = DateTime.now().month;
  final year = DateTime.now().year;
  final emps = await client
      .from('employees')
      .select('status');
  final empList = List<Map<String, dynamic>>.from(emps as List);
  final presentToday = await client
      .from('attendance')
      .select('id')
      .eq('date', today)
      .eq('status', 'present');
  final pendingLeaves = await client
      .from('leave_requests')
      .select('id')
      .eq('status', 'pending');
  final payroll = await client
      .from('payroll_runs')
      .select('total_net')
      .eq('month', month)
      .eq('year', year)
      .maybeSingle();
  return {
    'total_employees': empList.where((e) => e['status'] == 'active').length,
    'present_today': (presentToday as List).length,
    'pending_leaves': (pendingLeaves as List).length,
    'payroll_this_month': (payroll?['total_net'] as num? ?? 0).toDouble(),
  };
});

final attendanceTrendProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateTime.now();
  final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  final trend = <Map<String, dynamic>>[];
  for (int i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final dateStr = day.toIso8601String().substring(0, 10);
    final all = await client
        .from('attendance')
        .select('status')
        .eq('date', dateStr);
    final list = List<Map<String, dynamic>>.from(all as List);
    trend.add({
      'date': dateStr,
      'day': days[day.weekday - 1],
      'present': list.where((a) => a['status'] == 'present').length,
      'absent': list.where((a) => a['status'] == 'absent').length,
    });
  }
  return trend;
});

final payrollTrendProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('payroll_runs')
      .select('month, year, total_net, employee_count')
      .eq('status', 'approved')
      .order('year', ascending: false)
      .order('month', ascending: false)
      .limit(6);
  return List<Map<String, dynamic>>.from((data as List).reversed.toList());
});

final departmentDistributionProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final emps = await client
      .from('employees')
      .select('department_id, departments(name)')
      .eq('status', 'active');
  final empList = List<Map<String, dynamic>>.from(emps as List);
  final counts = <String, int>{};
  for (final e in empList) {
    final name = (e['departments'] as Map?)?['name'] as String? ?? 'Unknown';
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final result = counts.entries
      .map((e) => {'department': e.key, 'count': e.value})
      .toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  return result;
});

// ════════════════════════════════════════════════════════════
// CRM PROVIDERS
// ════════════════════════════════════════════════════════════

final crmLeadsProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({String? stage, String? search})>((ref, p) async {
  final client = ref.watch(supabaseClientProvider);
  var query = client
      .from('crm_leads')
      .select('*, employees!assigned_to(first_name, last_name)')
      .order('created_at', ascending: false);
  if (p.stage != null && p.stage!.isNotEmpty) {
    query = query.eq('stage', p.stage!) as dynamic;
  }
  if (p.search != null && p.search!.isNotEmpty) {
    query = query.or(
        'company_name.ilike.%${p.search}%,contact_name.ilike.%${p.search}%') as dynamic;
  }
  return List<Map<String, dynamic>>.from(await query as List);
});

final crmClientsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(
      await client.from('crm_clients').select().order('company_name') as List);
});

final crmStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final leads = await client.from('crm_leads').select('stage, deal_value');
  final list = List<Map<String, dynamic>>.from(leads as List);
  double pipeline = 0;
  int won = 0, lost = 0, inProgress = 0;
  for (final l in list) {
    pipeline += (l['deal_value'] as num? ?? 0).toDouble();
    if (l['stage'] == 'won') won++;
    else if (l['stage'] == 'lost') lost++;
    else inProgress++;
  }
  final clients = await client.from('crm_clients').select('id');
  return {
    'total_leads': list.length,
    'pipeline_value': pipeline,
    'won': won,
    'lost': lost,
    'in_progress': inProgress,
    'total_clients': (clients as List).length,
    'conversion_rate': list.isNotEmpty
        ? ((won / list.length) * 100).toStringAsFixed(1)
        : '0',
  };
});

final crmLeadNotifierProvider =
    StateNotifierProvider<CrmLeadNotifier, AsyncValue<void>>(
  (_) => CrmLeadNotifier(),
);

class CrmLeadNotifier extends StateNotifier<AsyncValue<void>> {
  CrmLeadNotifier() : super(const AsyncValue.data(null));
  SupabaseClient get _c => Supabase.instance.client;

  Future<bool> saveLead(Map<String, dynamic> data, {String? leadId}) async {
    state = const AsyncValue.loading();
    try {
      if (leadId != null) {
        await _c.from('crm_leads').update(data).eq('id', leadId);
      } else {
        await _c.from('crm_leads').insert(data);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateStage(String leadId, String stage) async {
    state = const AsyncValue.loading();
    try {
      await _c.from('crm_leads').update({
        'stage': stage,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', leadId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
