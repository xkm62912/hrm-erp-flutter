// lib/presentation/providers/all_providers.dart
// ALL imports MUST be at the top — fixed directive_after_declaration errors

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Equality classes for FutureProvider.family params ────────────────────────

class EmployeeFilter {
  final String search;
  final String? status;
  final String? departmentId;
  const EmployeeFilter({this.search = '', this.status, this.departmentId});
  @override
  bool operator ==(Object o) =>
      o is EmployeeFilter &&
      o.search == search &&
      o.status == status &&
      o.departmentId == departmentId;
  @override
  int get hashCode => Object.hash(search, status, departmentId);
}

class AttendanceFilter {
  final int month;
  final int year;
  final String? employeeId;
  const AttendanceFilter(
      {required this.month, required this.year, this.employeeId});
  @override
  bool operator ==(Object o) =>
      o is AttendanceFilter &&
      o.month == month &&
      o.year == year &&
      o.employeeId == employeeId;
  @override
  int get hashCode => Object.hash(month, year, employeeId);
}

class CrmLeadFilter {
  final String? stage;
  final String? search;
  const CrmLeadFilter({this.stage, this.search});
  @override
  bool operator ==(Object o) =>
      o is CrmLeadFilter && o.stage == stage && o.search == search;
  @override
  int get hashCode => Object.hash(stage, search);
}

// ════════════════════════════════════════════════════════════
// CORE
// ════════════════════════════════════════════════════════════

final supabaseClientProvider =
    Provider<SupabaseClient>((_) => Supabase.instance.client);

// ════════════════════════════════════════════════════════════
// AUTH
// ════════════════════════════════════════════════════════════

final authStateProvider = StreamProvider<AuthState>(
    (_) => Supabase.instance.client.auth.onAuthStateChange);

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>(
        (_) => AuthNotifier());

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier()
      : super(AsyncValue.data(Supabase.instance.client.auth.currentUser));

  SupabaseClient get _c => Supabase.instance.client;

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final r =
          await _c.auth.signInWithPassword(email: email, password: password);
      state = AsyncValue.data(r.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _c.auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<String?> getUserRole() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;
    final r = await _c
        .from('user_roles')
        .select('role')
        .eq('user_id', uid)
        .maybeSingle();
    return r?['role'] as String?;
  }
}

final userRoleProvider = FutureProvider<String?>(
    (ref) => ref.read(authNotifierProvider.notifier).getUserRole());

// ════════════════════════════════════════════════════════════
// EMPLOYEE PROVIDERS
// ════════════════════════════════════════════════════════════

final employeesProvider = FutureProvider.family<
    List<Map<String, dynamic>>, EmployeeFilter>((ref, f) async {
  final c = ref.watch(supabaseClientProvider);
  // Apply filters BEFORE .order() — fixes 'eq not defined on TransformBuilder'
  var q = c.from('employees').select('*, departments(name)');
  if (f.status != null && f.status!.isNotEmpty) q = q.eq('status', f.status!);
  if (f.departmentId != null) q = q.eq('department_id', f.departmentId!);
  if (f.search.isNotEmpty) {
    q = q.or(
        'first_name.ilike.%${f.search}%,last_name.ilike.%${f.search}%,emp_code.ilike.%${f.search}%');
  }
  final r = await q.order('first_name');
  return List<Map<String, dynamic>>.from(r as List);
});

final employeeDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final c = ref.watch(supabaseClientProvider);
  final r = await c
      .from('employees')
      .select('*, departments(name), salary_structures(*)')
      .eq('id', id)
      .single();
  return Map<String, dynamic>.from(r);
});

final employeeStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  final list = List<Map<String, dynamic>>.from(
      await c.from('employees').select('status, join_date') as List);
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
  final c = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(
      await c.from('departments').select().order('name') as List);
});

// ════════════════════════════════════════════════════════════
// ATTENDANCE PROVIDERS
// ════════════════════════════════════════════════════════════

final todayAttendanceProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  final user = c.auth.currentUser;
  if (user == null) return null;
  final emp = await c
      .from('employees')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();
  if (emp == null) return null;
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final r = await c
      .from('attendance')
      .select()
      .eq('employee_id', emp['id'] as String)
      .eq('date', today)
      .maybeSingle();
  return r != null ? Map<String, dynamic>.from(r) : null;
});

final monthlyAttendanceProvider = FutureProvider.family<
    List<Map<String, dynamic>>, AttendanceFilter>((ref, f) async {
  final c = ref.watch(supabaseClientProvider);
  String? empId = f.employeeId;
  if (empId == null) {
    final user = c.auth.currentUser;
    if (user == null) return [];
    final emp = await c
        .from('employees')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();
    empId = emp?['id'] as String?;
    if (empId == null) return [];
  }
  final mm = f.month.toString().padLeft(2, '0');
  final start = '${f.year}-$mm-01';
  final lastDay = DateTime(f.year, f.month + 1, 0).day;
  final end = '${f.year}-$mm-${lastDay.toString().padLeft(2, '0')}';
  final r = await c
      .from('attendance')
      .select()
      .eq('employee_id', empId)
      .gte('date', start)
      .lte('date', end)
      .order('date');
  return List<Map<String, dynamic>>.from(r as List);
});

final attendanceActionProvider =
    StateNotifierProvider<AttendanceActionNotifier, AsyncValue<void>>(
        (_) => AttendanceActionNotifier());

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
      await _c
          .from('attendance')
          .update({'check_out': DateTime.now().toIso8601String()})
          .eq('employee_id', emp['id'] as String)
          .eq('date', today);
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
  final c = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await c
      .from('leave_types')
      .select()
      .eq('is_active', true)
      .order('name') as List);
});

final myLeaveRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  final emp = await c
      .from('employees')
      .select('id')
      .eq('user_id', c.auth.currentUser!.id)
      .single();
  return List<Map<String, dynamic>>.from(await c
      .from('leave_requests')
      .select('*, leave_types(name, is_paid)')
      .eq('employee_id', emp['id'] as String)
      .order('applied_at', ascending: false) as List);
});

final pendingLeaveApprovalsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await c
      .from('leave_requests')
      .select(
          '*, leave_types(name), employees!employee_id(first_name, last_name, designation)')
      .eq('status', 'pending')
      .order('applied_at') as List);
});

final myLeaveBalancesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  final emp = await c
      .from('employees')
      .select('id')
      .eq('user_id', c.auth.currentUser!.id)
      .single();
  return List<Map<String, dynamic>>.from(await c
      .from('leave_balances')
      .select('*, leave_types(name, max_days_per_year)')
      .eq('employee_id', emp['id'] as String)
      .eq('year', DateTime.now().year) as List);
});

final leaveRequestNotifierProvider =
    StateNotifierProvider<LeaveRequestNotifier, AsyncValue<void>>(
        (_) => LeaveRequestNotifier());

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
      await _c.from('leave_requests').insert({
        'employee_id': emp['id'],
        'leave_type_id': leaveTypeId,
        'from_date': fromDate.toIso8601String().substring(0, 10),
        'to_date': toDate.toIso8601String().substring(0, 10),
        'total_days': toDate.difference(fromDate).inDays + 1,
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
  final c = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await c
      .from('payroll_runs')
      .select()
      .order('year', ascending: false)
      .order('month', ascending: false) as List);
});

final myLatestPayslipProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  final emp = await c
      .from('employees')
      .select('id')
      .eq('user_id', c.auth.currentUser!.id)
      .maybeSingle();
  if (emp == null) return null;
  final r = await c
      .from('payslips')
      .select('*, payroll_runs(month, year)')
      .eq('employee_id', emp['id'] as String)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return r != null ? Map<String, dynamic>.from(r) : null;
});

final payrollRunNotifierProvider =
    StateNotifierProvider<PayrollRunNotifier, AsyncValue<String?>>(
        (_) => PayrollRunNotifier());

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
      final emps = List<Map<String, dynamic>>.from(
          await _c.from('employees').select('*, salary_structures(*)').eq(
              'status', 'active') as List);
      final mm = month.toString().padLeft(2, '0');
      final lastDay = DateTime(year, month + 1, 0).day;
      final atts = List<Map<String, dynamic>>.from(await _c
          .from('attendance')
          .select('employee_id, status')
          .gte('date', '$year-$mm-01')
          .lte('date',
              '$year-$mm-${lastDay.toString().padLeft(2, '0')}') as List);
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
        'employee_count': emps.length,
      }).select().single();
      final runId = run['id'] as String;
      double totalGross = 0, totalDed = 0, totalNet = 0;
      final payslips = <Map<String, dynamic>>[];
      for (final emp in emps) {
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
        final present = atts
            .where((a) =>
                a['employee_id'] == emp['id'] &&
                (a['status'] == 'present' ||
                    a['status'] == 'late' ||
                    a['status'] == 'half_day'))
            .length;
        final absent = workDays - present;
        final ded = tax + ins + pf + (absent * perDay);
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
          'absent_deduction': absent * perDay,
          'total_deductions': ded,
          'net_salary': net,
          'working_days': workDays,
          'paid_days': present,
          'absent_days': absent,
          'status': 'generated',
        });
      }
      if (payslips.isNotEmpty) await _c.from('payslips').insert(payslips);
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
  final c = ref.watch(supabaseClientProvider);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final emps = List<Map<String, dynamic>>.from(
      await c.from('employees').select('status') as List);
  final present = List.from(await c
      .from('attendance')
      .select('id')
      .eq('date', today)
      .eq('status', 'present') as List);
  final pending = List.from(await c
      .from('leave_requests')
      .select('id')
      .eq('status', 'pending') as List);
  final payroll = await c
      .from('payroll_runs')
      .select('total_net')
      .eq('month', DateTime.now().month)
      .eq('year', DateTime.now().year)
      .maybeSingle();
  return {
    'total_employees': emps.where((e) => e['status'] == 'active').length,
    'present_today': present.length,
    'pending_leaves': pending.length,
    'payroll_this_month': (payroll?['total_net'] as num? ?? 0).toDouble(),
  };
});

final attendanceTrendProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  final today = DateTime.now();
  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final trend = <Map<String, dynamic>>[];
  for (int i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final dateStr = day.toIso8601String().substring(0, 10);
    final all = List<Map<String, dynamic>>.from(
        await c.from('attendance').select('status').eq('date', dateStr) as List);
    trend.add({
      'date': dateStr,
      'day': days[day.weekday - 1],
      'present': all.where((a) => a['status'] == 'present').length,
      'absent': all.where((a) => a['status'] == 'absent').length,
    });
  }
  return trend;
});

final payrollTrendProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  final r = await c
      .from('payroll_runs')
      .select('month, year, total_net, employee_count')
      .eq('status', 'approved')
      .order('year', ascending: false)
      .order('month', ascending: false)
      .limit(6);
  return List<Map<String, dynamic>>.from((r as List).reversed.toList());
});

final departmentDistributionProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  final emps = List<Map<String, dynamic>>.from(
      await c
          .from('employees')
          .select('department_id, departments(name)')
          .eq('status', 'active') as List);
  final counts = <String, int>{};
  for (final e in emps) {
    final name = (e['departments'] as Map?)?['name'] as String? ?? 'Unknown';
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return (counts.entries
      .map((e) => {'department': e.key, 'count': e.value})
      .toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int)));
});

// ════════════════════════════════════════════════════════════
// CRM PROVIDERS
// ════════════════════════════════════════════════════════════

final crmLeadsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, CrmLeadFilter>((ref, f) async {
  final c = ref.watch(supabaseClientProvider);
  // Apply filters BEFORE order
  var q = c
      .from('crm_leads')
      .select('*, employees!assigned_to(first_name, last_name)');
  if (f.stage != null && f.stage!.isNotEmpty) q = q.eq('stage', f.stage!);
  if (f.search != null && f.search!.isNotEmpty) {
    q = q.or(
        'company_name.ilike.%${f.search}%,contact_name.ilike.%${f.search}%');
  }
  final r = await q.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(r as List);
});

final crmClientsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(
      await c.from('crm_clients').select().order('company_name') as List);
});

final crmStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final c = ref.watch(supabaseClientProvider);
  final leads = List<Map<String, dynamic>>.from(
      await c.from('crm_leads').select('stage, deal_value') as List);
  double pipeline = 0;
  int won = 0, lost = 0, inProgress = 0;
  for (final l in leads) {
    pipeline += (l['deal_value'] as num? ?? 0).toDouble();
    if (l['stage'] == 'won') {
      won++;
    } else if (l['stage'] == 'lost') {
      lost++;
    } else {
      inProgress++;
    }
  }
  final clients = List.from(await c.from('crm_clients').select('id') as List);
  return {
    'total_leads': leads.length,
    'pipeline_value': pipeline,
    'won': won,
    'lost': lost,
    'in_progress': inProgress,
    'total_clients': clients.length,
    'conversion_rate': leads.isNotEmpty
        ? ((won / leads.length) * 100).toStringAsFixed(1)
        : '0',
  };
});

final crmLeadNotifierProvider =
    StateNotifierProvider<CrmLeadNotifier, AsyncValue<void>>(
        (_) => CrmLeadNotifier());

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
