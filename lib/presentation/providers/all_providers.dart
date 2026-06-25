// lib/presentation/providers/all_providers.dart
// Central barrel file — all Riverpod providers for the HRM ERP

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'all_providers.g.dart';

// ═══════════════════════════════════════════════════════════════
// CORE
// ═══════════════════════════════════════════════════════════════

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// ═══════════════════════════════════════════════════════════════
// AUTH PROVIDER
// ═══════════════════════════════════════════════════════════════

@riverpod
Stream<AuthState> authState(AuthStateRef ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<User?> build() {
    final user = Supabase.instance.client.auth.currentUser;
    return AsyncValue.data(user);
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(res.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<String?> getUserRole() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    final res = await Supabase.instance.client
        .from('user_roles')
        .select('role')
        .eq('user_id', uid)
        .maybeSingle();
    return res?['role'] as String?;
  }
}

final userRoleProvider = FutureProvider<String?>((ref) async {
  final notifier = ref.read(authNotifierProvider.notifier);
  return notifier.getUserRole();
});

// ═══════════════════════════════════════════════════════════════
// EMPLOYEE PROVIDERS
// ═══════════════════════════════════════════════════════════════

@riverpod
Future<List<Map<String, dynamic>>> employees(
  EmployeesRef ref, {
  String search = '',
  String? departmentId,
  String? status,
}) async {
  final client = ref.watch(supabaseClientProvider);
  var query = client
      .from('employees')
      .select('*, departments(name)')
      .order('first_name');

  if (status != null && status.isNotEmpty) {
    query = query.eq('status', status) as dynamic;
  }
  if (departmentId != null) {
    query = query.eq('department_id', departmentId) as dynamic;
  }
  if (search.isNotEmpty) {
    query = query.or(
      'first_name.ilike.%$search%,last_name.ilike.%$search%,emp_code.ilike.%$search%,email.ilike.%$search%',
    ) as dynamic;
  }

  final data = await query;
  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
Future<Map<String, dynamic>> employeeDetail(
    EmployeeDetailRef ref, String id) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('employees')
      .select('*, departments(name), salary_structures(*)')
      .eq('id', id)
      .single();
  return Map<String, dynamic>.from(data);
}

@riverpod
Future<Map<String, int>> employeeStats(EmployeeStatsRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final allEmps = await client.from('employees').select('status, join_date');
  final list = List<Map<String, dynamic>>.from(allEmps as List);
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
  return {
    'total': list.length,
    'active': list.where((e) => e['status'] == 'active').length,
    'inactive': list.where((e) => e['status'] == 'inactive').length,
    'on_leave': list.where((e) => e['status'] == 'on_leave').length,
    'new': list.where((e) {
      final joinDate = DateTime.tryParse(e['join_date'] ?? '');
      return joinDate != null && joinDate.isAfter(thirtyDaysAgo);
    }).length,
  };
}

@riverpod
Future<List<Map<String, dynamic>>> departments(DepartmentsRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('departments').select().order('name');
  return List<Map<String, dynamic>>.from(data as List);
}

// ═══════════════════════════════════════════════════════════════
// ATTENDANCE PROVIDERS
// ═══════════════════════════════════════════════════════════════

@riverpod
Future<Map<String, dynamic>?> todayAttendance(TodayAttendanceRef ref) async {
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
}

@riverpod
Future<List<Map<String, dynamic>>> monthlyAttendance(
  MonthlyAttendanceRef ref, {
  required int month,
  required int year,
  String? employeeId,
}) async {
  final client = ref.watch(supabaseClientProvider);
  String? empId = employeeId;

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

  final start = '$year-${month.toString().padLeft(2, '0')}-01';
  final end = DateTime(year, month + 1, 0);
  final endStr =
      '$year-${month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

  final data = await client
      .from('attendance')
      .select()
      .eq('employee_id', empId)
      .gte('date', start)
      .lte('date', endStr)
      .order('date');

  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
class AttendanceAction extends _$AttendanceAction {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> checkIn() async {
    state = const AsyncValue.loading();
    try {
      final client = Supabase.instance.client;
      final emp = await client
          .from('employees')
          .select('id')
          .eq('user_id', client.auth.currentUser!.id)
          .single();

      final now = DateTime.now();
      final today = now.toIso8601String().substring(0, 10);
      final isLate = now.hour > 9 || (now.hour == 9 && now.minute > 0);

      await client.from('attendance').upsert({
        'employee_id': emp['id'],
        'date': today,
        'check_in': now.toIso8601String(),
        'status': isLate ? 'late' : 'present',
      });

      ref.invalidate(todayAttendanceProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> checkOut() async {
    state = const AsyncValue.loading();
    try {
      final client = Supabase.instance.client;
      final emp = await client
          .from('employees')
          .select('id')
          .eq('user_id', client.auth.currentUser!.id)
          .single();

      final today = DateTime.now().toIso8601String().substring(0, 10);
      await client.from('attendance').update({
        'check_out': DateTime.now().toIso8601String(),
      }).eq('employee_id', emp['id']).eq('date', today);

      ref.invalidate(todayAttendanceProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// LEAVE PROVIDERS
// ═══════════════════════════════════════════════════════════════

@riverpod
Future<List<Map<String, dynamic>>> leaveTypes(LeaveTypesRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('leave_types')
      .select()
      .eq('is_active', true)
      .order('name');
  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
Future<List<Map<String, dynamic>>> myLeaveRequests(
    MyLeaveRequestsRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final emp = await client
      .from('employees')
      .select('id')
      .eq('user_id', client.auth.currentUser!.id)
      .single();

  final data = await client
      .from('leave_requests')
      .select('*, leave_types(name, is_paid), employees!approved_by(first_name, last_name)')
      .eq('employee_id', emp['id'])
      .order('applied_at', ascending: false);

  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
Future<List<Map<String, dynamic>>> pendingLeaveApprovals(
    PendingLeaveApprovalsRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('leave_requests')
      .select('*, leave_types(name), employees!employee_id(first_name, last_name, avatar_url, designation)')
      .eq('status', 'pending')
      .order('applied_at');
  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
Future<List<Map<String, dynamic>>> myLeaveBalances(
    MyLeaveBalancesRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final emp = await client
      .from('employees')
      .select('id')
      .eq('user_id', client.auth.currentUser!.id)
      .single();

  final year = DateTime.now().year;
  final data = await client
      .from('leave_balances')
      .select('*, leave_types(name, max_days_per_year)')
      .eq('employee_id', emp['id'])
      .eq('year', year);

  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
class LeaveRequestNotifier extends _$LeaveRequestNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> submitRequest({
    required String leaveTypeId,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = Supabase.instance.client;
      final emp = await client
          .from('employees')
          .select('id')
          .eq('user_id', client.auth.currentUser!.id)
          .single();

      final totalDays = toDate.difference(fromDate).inDays + 1;

      await client.from('leave_requests').insert({
        'employee_id': emp['id'],
        'leave_type_id': leaveTypeId,
        'from_date': fromDate.toIso8601String().substring(0, 10),
        'to_date': toDate.toIso8601String().substring(0, 10),
        'total_days': totalDays,
        'reason': reason,
        'status': 'pending',
      });

      // Update pending balance
      final year = DateTime.now().year;
      await client.from('leave_balances').upsert({
        'employee_id': emp['id'],
        'leave_type_id': leaveTypeId,
        'year': year,
        'pending_days': totalDays,
      }, onConflict: 'employee_id,leave_type_id,year');

      ref.invalidate(myLeaveRequestsProvider);
      ref.invalidate(myLeaveBalancesProvider);
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
      final client = Supabase.instance.client;
      await client.from('leave_requests').update({
        'status': status,
        'approved_by': approverId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      ref.invalidate(pendingLeaveApprovalsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// PAYROLL PROVIDERS
// ═══════════════════════════════════════════════════════════════

@riverpod
Future<List<Map<String, dynamic>>> payrollRuns(PayrollRunsRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('payroll_runs')
      .select('*, employees!processed_by(first_name, last_name)')
      .order('year', ascending: false)
      .order('month', ascending: false);
  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
Future<List<Map<String, dynamic>>> payslipsForRun(
    PayslipsForRunRef ref, String runId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('payslips')
      .select('*, employees(first_name, last_name, emp_code, designation, avatar_url, departments(name))')
      .eq('payroll_run_id', runId)
      .order('net_salary', ascending: false);
  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
Future<Map<String, dynamic>?> myLatestPayslip(
    MyLatestPayslipRef ref) async {
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
}

@riverpod
class PayrollRunNotifier extends _$PayrollRunNotifier {
  @override
  AsyncValue<String?> build() => const AsyncValue.data(null);

  Future<bool> runPayroll({
    required int month,
    required int year,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = Supabase.instance.client;
      final processorEmp = await client
          .from('employees')
          .select('id')
          .eq('user_id', client.auth.currentUser!.id)
          .single();

      // Get all active employees with salary structures
      final employees = await client
          .from('employees')
          .select('*, salary_structures(*)')
          .eq('status', 'active');

      final empList = List<Map<String, dynamic>>.from(employees as List);
      final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(year, month + 1, 0).day;
      final endDate =
          '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

      // Get attendance
      final attendance = await client
          .from('attendance')
          .select('employee_id, status')
          .gte('date', startDate)
          .lte('date', endDate);

      final attendanceList =
          List<Map<String, dynamic>>.from(attendance as List);

      // Count working days in month
      int workDays = 0;
      for (int d = 1; d <= lastDay; d++) {
        final wd = DateTime(year, month, d).weekday;
        if (wd != 6 && wd != 7) workDays++;
      }

      double totalGross = 0, totalDeductions = 0, totalNet = 0;

      // Create payroll run
      final run = await client.from('payroll_runs').insert({
        'month': month,
        'year': year,
        'status': 'processing',
        'processed_by': processorEmp['id'],
        'processed_at': DateTime.now().toIso8601String(),
        'employee_count': empList.length,
      }).select().single();

      final runId = run['id'] as String;

      List<Map<String, dynamic>> payslipRecords = [];

      for (final emp in empList) {
        final salStructures =
            emp['salary_structures'] as List<dynamic>? ?? [];
        if (salStructures.isEmpty) continue;
        final sal = Map<String, dynamic>.from(salStructures.first);

        final basic = (sal['basic_salary'] as num? ?? 0).toDouble();
        final house = (sal['house_allowance'] as num? ?? 0).toDouble();
        final transport =
            (sal['transport_allowance'] as num? ?? 0).toDouble();
        final medical =
            (sal['medical_allowance'] as num? ?? 0).toDouble();
        final meal = (sal['meal_allowance'] as num? ?? 0).toDouble();
        final otherAllow =
            (sal['other_allowance'] as num? ?? 0).toDouble();
        final tax = (sal['tax_deduction'] as num? ?? 0).toDouble();
        final insurance =
            (sal['insurance_deduction'] as num? ?? 0).toDouble();
        final pf = (sal['provident_fund'] as num? ?? 0).toDouble();

        final gross = basic + house + transport + medical + meal + otherAllow;
        final perDay = workDays > 0 ? gross / workDays : 0.0;

        final empAttendance = attendanceList
            .where((a) => a['employee_id'] == emp['id'])
            .toList();
        final presentDays = empAttendance
            .where((a) =>
                a['status'] == 'present' ||
                a['status'] == 'late' ||
                a['status'] == 'half_day')
            .length;
        final absentDays = workDays - presentDays;
        final absentDeduction = absentDays * perDay;

        final totalDed = tax + insurance + pf + absentDeduction;
        final net = (gross - totalDed).clamp(0, double.infinity);

        totalGross += gross;
        totalDeductions += totalDed;
        totalNet += net;

        payslipRecords.add({
          'payroll_run_id': runId,
          'employee_id': emp['id'],
          'basic_salary': basic,
          'house_allowance': house,
          'transport_allowance': transport,
          'medical_allowance': medical,
          'other_allowances': meal + otherAllow,
          'gross_salary': gross,
          'tax_deduction': tax,
          'insurance_deduction': insurance,
          'provident_fund': pf,
          'absent_deduction': absentDeduction,
          'total_deductions': totalDed,
          'net_salary': net,
          'working_days': workDays,
          'paid_days': presentDays,
          'absent_days': absentDays,
          'status': 'generated',
        });
      }

      if (payslipRecords.isNotEmpty) {
        await client.from('payslips').insert(payslipRecords);
      }

      await client.from('payroll_runs').update({
        'status': 'approved',
        'total_gross': totalGross,
        'total_deductions': totalDeductions,
        'total_net': totalNet,
        'employee_count': payslipRecords.length,
      }).eq('id', runId);

      ref.invalidate(payrollRunsProvider);
      state = AsyncValue.data(runId);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// DASHBOARD PROVIDERS
// ═══════════════════════════════════════════════════════════════

@riverpod
Future<Map<String, dynamic>> dashboardStats(DashboardStatsRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final thisMonth = DateTime.now().month;
  final thisYear = DateTime.now().year;

  final results = await Future.wait([
    client.from('employees').count().eq('status', 'active'),
    client.from('attendance').count().eq('date', today).eq('status', 'present'),
    client.from('leave_requests').count().eq('status', 'pending'),
    client.from('payroll_runs').select('total_net').eq('month', thisMonth).eq('year', thisYear).maybeSingle(),
  ]);

  return {
    'total_employees': results[0],
    'present_today': results[1],
    'pending_leaves': results[2],
    'payroll_this_month': (results[3] as Map?)?['total_net'] ?? 0,
  };
}

@riverpod
Future<List<Map<String, dynamic>>> attendanceTrend(
    AttendanceTrendRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateTime.now();

  List<Map<String, dynamic>> trend = [];
  for (int i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final dateStr = day.toIso8601String().substring(0, 10);

    final present = await client
        .from('attendance')
        .count()
        .eq('date', dateStr)
        .eq('status', 'present');

    final absent = await client
        .from('attendance')
        .count()
        .eq('date', dateStr)
        .eq('status', 'absent');

    trend.add({
      'date': dateStr,
      'day': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1],
      'present': present,
      'absent': absent,
    });
  }
  return trend;
}

@riverpod
Future<List<Map<String, dynamic>>> payrollTrend(
    PayrollTrendRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('payroll_runs')
      .select('month, year, total_net, employee_count')
      .eq('status', 'approved')
      .order('year', ascending: false)
      .order('month', ascending: false)
      .limit(6);
  return List<Map<String, dynamic>>.from((data as List).reversed.toList());
}

@riverpod
Future<List<Map<String, dynamic>>> departmentDistribution(
    DepartmentDistributionRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final emps = await client
      .from('employees')
      .select('department_id, departments(name)')
      .eq('status', 'active');

  final empList = List<Map<String, dynamic>>.from(emps as List);
  final Map<String, int> counts = {};

  for (final emp in empList) {
    final deptName =
        (emp['departments'] as Map?)?['name'] as String? ?? 'Unknown';
    counts[deptName] = (counts[deptName] ?? 0) + 1;
  }

  return counts.entries
      .map((e) => {'department': e.key, 'count': e.value})
      .toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
}

// ═══════════════════════════════════════════════════════════════
// CRM PROVIDERS
// ═══════════════════════════════════════════════════════════════

@riverpod
Future<List<Map<String, dynamic>>> crmLeads(CrmLeadsRef ref,
    {String? stage, String? search}) async {
  final client = ref.watch(supabaseClientProvider);
  var query = client
      .from('crm_leads')
      .select('*, employees!assigned_to(first_name, last_name)')
      .order('created_at', ascending: false);

  if (stage != null && stage.isNotEmpty) {
    query = query.eq('stage', stage) as dynamic;
  }
  if (search != null && search.isNotEmpty) {
    query = query.or(
      'company_name.ilike.%$search%,contact_name.ilike.%$search%,email.ilike.%$search%',
    ) as dynamic;
  }

  final data = await query;
  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
Future<List<Map<String, dynamic>>> crmClients(CrmClientsRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('crm_clients')
      .select()
      .order('company_name');
  return List<Map<String, dynamic>>.from(data as List);
}

@riverpod
Future<Map<String, dynamic>> crmStats(CrmStatsRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final leads = await client.from('crm_leads').select('stage, deal_value');
  final leadList = List<Map<String, dynamic>>.from(leads as List);

  double totalPipeline = 0;
  int won = 0, lost = 0, inProgress = 0;

  for (final l in leadList) {
    final val = (l['deal_value'] as num? ?? 0).toDouble();
    totalPipeline += val;
    final stage = l['stage'] as String?;
    if (stage == 'won') {
      won++;
    } else if (stage == 'lost') {
      lost++;
    } else {
      inProgress++;
    }
  }

  final clients = await client.from('crm_clients').count();

  return {
    'total_leads': leadList.length,
    'pipeline_value': totalPipeline,
    'won': won,
    'lost': lost,
    'in_progress': inProgress,
    'total_clients': clients,
    'conversion_rate': leadList.isNotEmpty
        ? ((won / leadList.length) * 100).toStringAsFixed(1)
        : '0',
  };
}

@riverpod
class CrmLeadNotifier extends _$CrmLeadNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> saveLead(Map<String, dynamic> data, {String? leadId}) async {
    state = const AsyncValue.loading();
    try {
      final client = Supabase.instance.client;
      if (leadId != null) {
        await client.from('crm_leads').update(data).eq('id', leadId);
      } else {
        await client.from('crm_leads').insert(data);
      }
      ref.invalidate(crmLeadsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateStage(String leadId, String newStage) async {
    state = const AsyncValue.loading();
    try {
      final client = Supabase.instance.client;
      await client
          .from('crm_leads')
          .update({'stage': newStage, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', leadId);
      ref.invalidate(crmLeadsProvider);
      ref.invalidate(crmStatsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
