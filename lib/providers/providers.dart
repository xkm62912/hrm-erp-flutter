// lib/providers/providers.dart
// Simple Riverpod providers — NO family, NO code generation, NO go_router
// All imports at top (no directive_after_declaration errors)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Supabase client ─────────────────────────────────────────
final sbClient = Supabase.instance.client;

// ─── Auth ────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>(
  (_) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(AsyncValue.data(Supabase.instance.client.auth.currentUser));

  Future<String?> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final r = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      state = AsyncValue.data(r.user);
      return null;
    } catch (e) {
      state = const AsyncValue.data(null);
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final userRoleProvider = FutureProvider<String?>((ref) async {
  final uid = sbClient.auth.currentUser?.id;
  if (uid == null) return null;
  final r = await sbClient
      .from('user_roles')
      .select('role')
      .eq('user_id', uid)
      .maybeSingle();
  return r?['role'] as String?;
});

// ─── Employee filters (StateProvider so FutureProvider can watch) ─────
final empSearchProvider   = StateProvider<String>((_) => '');
final empStatusProvider   = StateProvider<String?>((_) => null);

final employeesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final search = ref.watch(empSearchProvider);
  final status = ref.watch(empStatusProvider);
  var q = sbClient.from('employees').select('*, departments(name)');
  if (status != null && status.isNotEmpty) q = q.eq('status', status);
  if (search.isNotEmpty) {
    q = q.or('first_name.ilike.%$search%,last_name.ilike.%$search%,emp_code.ilike.%$search%');
  }
  final r = await q.order('first_name');
  return List<Map<String, dynamic>>.from(r as List);
});

final employeeStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final list = List<Map<String, dynamic>>.from(
      await sbClient.from('employees').select('status, join_date') as List);
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  return {
    'total':    list.length,
    'active':   list.where((e) => e['status'] == 'active').length,
    'inactive': list.where((e) => e['status'] == 'inactive').length,
    'on_leave': list.where((e) => e['status'] == 'on_leave').length,
    'new': list.where((e) {
      final d = DateTime.tryParse(e['join_date'] as String? ?? '');
      return d != null && d.isAfter(cutoff);
    }).length,
  };
});

final departmentsProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final r = await sbClient.from('departments').select().order('name');
  return List<Map<String, dynamic>>.from(r as List);
});

final selectedEmployeeIdProvider = StateProvider<String?>((_) => null);

final employeeDetailProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final id = ref.watch(selectedEmployeeIdProvider);
  if (id == null) return null;
  final r = await sbClient
      .from('employees')
      .select('*, departments(name), salary_structures(*)')
      .eq('id', id)
      .single();
  return Map<String, dynamic>.from(r);
});

// ─── Attendance ───────────────────────────────────────────────
final attMonthProvider = StateProvider<int>((_) => DateTime.now().month);
final attYearProvider  = StateProvider<int>((_) => DateTime.now().year);

Future<String?> _currentEmpId() async {
  final uid = sbClient.auth.currentUser?.id;
  if (uid == null) return null;
  final r = await sbClient
      .from('employees')
      .select('id')
      .eq('user_id', uid)
      .maybeSingle();
  return r?['id'] as String?;
}

final todayAttendanceProvider = FutureProvider<Map<String, dynamic>?>((_) async {
  final empId = await _currentEmpId();
  if (empId == null) return null;
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final r = await sbClient
      .from('attendance')
      .select()
      .eq('employee_id', empId)
      .eq('date', today)
      .maybeSingle();
  return r != null ? Map<String, dynamic>.from(r) : null;
});

final monthlyAttendanceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final month = ref.watch(attMonthProvider);
  final year  = ref.watch(attYearProvider);
  final empId = await _currentEmpId();
  if (empId == null) return [];
  final mm    = month.toString().padLeft(2, '0');
  final last  = DateTime(year, month + 1, 0).day;
  final r = await sbClient
      .from('attendance')
      .select()
      .eq('employee_id', empId)
      .gte('date', '$year-$mm-01')
      .lte('date', '$year-$mm-${last.toString().padLeft(2, '0')}')
      .order('date');
  return List<Map<String, dynamic>>.from(r as List);
});

final attendanceActionProvider =
    StateNotifierProvider<AttendanceNotifier, AsyncValue<void>>(
        (_) => AttendanceNotifier());

class AttendanceNotifier extends StateNotifier<AsyncValue<void>> {
  AttendanceNotifier() : super(const AsyncValue.data(null));

  Future<void> checkIn() async {
    state = const AsyncValue.loading();
    try {
      final empId = await _currentEmpId();
      if (empId == null) throw Exception('Employee not found');
      final now   = DateTime.now();
      final isLate = now.hour > 9 || (now.hour == 9 && now.minute > 0);
      await sbClient.from('attendance').upsert({
        'employee_id': empId,
        'date':        now.toIso8601String().substring(0, 10),
        'check_in':    now.toIso8601String(),
        'status':      isLate ? 'late' : 'present',
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> checkOut() async {
    state = const AsyncValue.loading();
    try {
      final empId = await _currentEmpId();
      if (empId == null) throw Exception('Employee not found');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await sbClient
          .from('attendance')
          .update({'check_out': DateTime.now().toIso8601String()})
          .eq('employee_id', empId)
          .eq('date', today);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ─── Leave ────────────────────────────────────────────────────
final leaveTypesProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final r = await sbClient
      .from('leave_types')
      .select()
      .eq('is_active', true)
      .order('name');
  return List<Map<String, dynamic>>.from(r as List);
});

final myLeaveRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final empId = await _currentEmpId();
  if (empId == null) return [];
  final r = await sbClient
      .from('leave_requests')
      .select('*, leave_types(name, is_paid)')
      .eq('employee_id', empId)
      .order('applied_at', ascending: false);
  return List<Map<String, dynamic>>.from(r as List);
});

final pendingApprovalsProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final r = await sbClient
      .from('leave_requests')
      .select('*, leave_types(name), employees!employee_id(first_name, last_name, designation)')
      .eq('status', 'pending')
      .order('applied_at');
  return List<Map<String, dynamic>>.from(r as List);
});

final myLeaveBalancesProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final empId = await _currentEmpId();
  if (empId == null) return [];
  final r = await sbClient
      .from('leave_balances')
      .select('*, leave_types(name, max_days_per_year)')
      .eq('employee_id', empId)
      .eq('year', DateTime.now().year);
  return List<Map<String, dynamic>>.from(r as List);
});

final leaveNotifierProvider =
    StateNotifierProvider<LeaveNotifier, AsyncValue<void>>((_) => LeaveNotifier());

class LeaveNotifier extends StateNotifier<AsyncValue<void>> {
  LeaveNotifier() : super(const AsyncValue.data(null));

  Future<bool> submit({
    required String leaveTypeId,
    required DateTime from,
    required DateTime to,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final empId = await _currentEmpId();
      if (empId == null) throw Exception('Employee not found');
      await sbClient.from('leave_requests').insert({
        'employee_id':   empId,
        'leave_type_id': leaveTypeId,
        'from_date':     from.toIso8601String().substring(0, 10),
        'to_date':       to.toIso8601String().substring(0, 10),
        'total_days':    to.difference(from).inDays + 1,
        'reason':        reason,
        'status':        'pending',
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateStatus(String id, String status, String approverId) async {
    state = const AsyncValue.loading();
    try {
      await sbClient.from('leave_requests').update({
        'status':      status,
        'approved_by': approverId,
        'updated_at':  DateTime.now().toIso8601String(),
      }).eq('id', id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// ─── Payroll ──────────────────────────────────────────────────
final payrollRunsProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final r = await sbClient
      .from('payroll_runs')
      .select()
      .order('year',  ascending: false)
      .order('month', ascending: false);
  return List<Map<String, dynamic>>.from(r as List);
});

final myLatestPayslipProvider = FutureProvider<Map<String, dynamic>?>((_) async {
  final empId = await _currentEmpId();
  if (empId == null) return null;
  final r = await sbClient
      .from('payslips')
      .select('*, payroll_runs(month, year)')
      .eq('employee_id', empId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return r != null ? Map<String, dynamic>.from(r) : null;
});

final payrollNotifierProvider =
    StateNotifierProvider<PayrollNotifier, AsyncValue<String?>>(
        (_) => PayrollNotifier());

class PayrollNotifier extends StateNotifier<AsyncValue<String?>> {
  PayrollNotifier() : super(const AsyncValue.data(null));

  Future<bool> runPayroll(int month, int year) async {
    state = const AsyncValue.loading();
    try {
      final empId = await _currentEmpId();
      if (empId == null) throw Exception('Employee not found');
      final emps = List<Map<String, dynamic>>.from(
          await sbClient.from('employees')
              .select('*, salary_structures(*)')
              .eq('status', 'active') as List);
      final mm      = month.toString().padLeft(2, '0');
      final lastDay = DateTime(year, month + 1, 0).day;
      final atts = List<Map<String, dynamic>>.from(
          await sbClient.from('attendance')
              .select('employee_id, status')
              .gte('date', '$year-$mm-01')
              .lte('date', '$year-$mm-${lastDay.toString().padLeft(2,'0')}') as List);
      int workDays = 0;
      for (int d = 1; d <= lastDay; d++) {
        final wd = DateTime(year, month, d).weekday;
        if (wd != 6 && wd != 7) workDays++;
      }
      final run = await sbClient.from('payroll_runs').insert({
        'month':          month,
        'year':           year,
        'status':         'processing',
        'processed_by':   empId,
        'processed_at':   DateTime.now().toIso8601String(),
        'employee_count': emps.length,
      }).select().single();
      final runId = run['id'] as String;
      double tg = 0, td = 0, tn = 0;
      final slips = <Map<String, dynamic>>[];
      for (final emp in emps) {
        final structs = emp['salary_structures'] as List? ?? [];
        if (structs.isEmpty) continue;
        final s    = Map<String, dynamic>.from(structs.first as Map);
        final bas  = (s['basic_salary']         as num? ?? 0).toDouble();
        final hou  = (s['house_allowance']       as num? ?? 0).toDouble();
        final tra  = (s['transport_allowance']   as num? ?? 0).toDouble();
        final med  = (s['medical_allowance']     as num? ?? 0).toDouble();
        final oth  = (s['other_allowance']       as num? ?? 0).toDouble();
        final tax  = (s['tax_deduction']         as num? ?? 0).toDouble();
        final ins  = (s['insurance_deduction']   as num? ?? 0).toDouble();
        final pf   = (s['provident_fund']        as num? ?? 0).toDouble();
        final gross = bas + hou + tra + med + oth;
        final perDay = workDays > 0 ? gross / workDays : 0.0;
        final present = atts.where((a) =>
          a['employee_id'] == emp['id'] &&
          (a['status'] == 'present' || a['status'] == 'late' || a['status'] == 'half_day')
        ).length;
        final absent = workDays - present;
        final ded  = tax + ins + pf + (absent * perDay);
        final net  = (gross - ded).clamp(0.0, double.infinity);
        tg += gross; td += ded; tn += net;
        slips.add({
          'payroll_run_id':    runId,
          'employee_id':       emp['id'],
          'basic_salary':      bas,
          'house_allowance':   hou,
          'transport_allowance': tra,
          'medical_allowance': med,
          'other_allowances':  oth,
          'gross_salary':      gross,
          'tax_deduction':     tax,
          'insurance_deduction': ins,
          'provident_fund':    pf,
          'absent_deduction':  absent * perDay,
          'total_deductions':  ded,
          'net_salary':        net,
          'working_days':      workDays,
          'paid_days':         present,
          'absent_days':       absent,
          'status':            'generated',
        });
      }
      if (slips.isNotEmpty) await sbClient.from('payslips').insert(slips);
      await sbClient.from('payroll_runs').update({
        'status':           'approved',
        'total_gross':      tg,
        'total_deductions': td,
        'total_net':        tn,
        'employee_count':   slips.length,
      }).eq('id', runId);
      state = AsyncValue.data(runId);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// ─── Dashboard ────────────────────────────────────────────────
final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((_) async {
  final today   = DateTime.now().toIso8601String().substring(0, 10);
  final emps    = List.from(await sbClient.from('employees').select('status') as List);
  final present = List.from(await sbClient.from('attendance').select('id').eq('date', today).eq('status', 'present') as List);
  final pending = List.from(await sbClient.from('leave_requests').select('id').eq('status', 'pending') as List);
  final payroll = await sbClient.from('payroll_runs')
      .select('total_net')
      .eq('month', DateTime.now().month)
      .eq('year',  DateTime.now().year)
      .maybeSingle();
  return {
    'total_employees':    emps.where((e) => (e as Map)['status'] == 'active').length,
    'present_today':      present.length,
    'pending_leaves':     pending.length,
    'payroll_this_month': (payroll?['total_net'] as num? ?? 0).toDouble(),
  };
});

final attendanceTrendProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final today = DateTime.now();
  final days  = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  final trend = <Map<String, dynamic>>[];
  for (int i = 6; i >= 0; i--) {
    final day     = today.subtract(Duration(days: i));
    final dateStr = day.toIso8601String().substring(0, 10);
    final all = List<Map<String, dynamic>>.from(
        await sbClient.from('attendance').select('status').eq('date', dateStr) as List);
    trend.add({
      'day':     days[day.weekday - 1],
      'present': all.where((a) => a['status'] == 'present').length,
      'absent':  all.where((a) => a['status'] == 'absent').length,
    });
  }
  return trend;
});

final payrollTrendProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final r = await sbClient
      .from('payroll_runs')
      .select('month, year, total_net')
      .eq('status', 'approved')
      .order('year',  ascending: false)
      .order('month', ascending: false)
      .limit(6);
  return List<Map<String, dynamic>>.from((r as List).reversed.toList());
});

final deptDistributionProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final emps = List<Map<String, dynamic>>.from(
      await sbClient.from('employees').select('departments(name)').eq('status', 'active') as List);
  final counts = <String, int>{};
  for (final e in emps) {
    final name = (e['departments'] as Map?)?['name'] as String? ?? 'Unknown';
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return (counts.entries.map((e) => {'department': e.key, 'count': e.value}).toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int)));
});

// ─── CRM ─────────────────────────────────────────────────────
final crmStageFilterProvider = StateProvider<String?>((_) => null);
final crmSearchProvider      = StateProvider<String>((_) => '');

final crmLeadsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final stage  = ref.watch(crmStageFilterProvider);
  final search = ref.watch(crmSearchProvider);
  var q = sbClient.from('crm_leads')
      .select('*, employees!assigned_to(first_name, last_name)');
  if (stage != null && stage.isNotEmpty) q = q.eq('stage', stage);
  if (search.isNotEmpty) {
    q = q.or('company_name.ilike.%$search%,contact_name.ilike.%$search%');
  }
  final r = await q.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(r as List);
});

final crmClientsProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final r = await sbClient.from('crm_clients').select().order('company_name');
  return List<Map<String, dynamic>>.from(r as List);
});

final crmStatsProvider = FutureProvider<Map<String, dynamic>>((_) async {
  final leads = List<Map<String, dynamic>>.from(
      await sbClient.from('crm_leads').select('stage, deal_value') as List);
  double pipeline = 0;
  int won = 0, lost = 0, active = 0;
  for (final l in leads) {
    pipeline += (l['deal_value'] as num? ?? 0).toDouble();
    if      (l['stage'] == 'won')  won++;
    else if (l['stage'] == 'lost') lost++;
    else                           active++;
  }
  final clients = List.from(await sbClient.from('crm_clients').select('id') as List);
  return {
    'total_leads':     leads.length,
    'pipeline_value':  pipeline,
    'won':             won,
    'lost':            lost,
    'in_progress':     active,
    'total_clients':   clients.length,
    'conversion_rate': leads.isNotEmpty
        ? ((won / leads.length) * 100).toStringAsFixed(1) : '0',
  };
});

final crmLeadNotifierProvider =
    StateNotifierProvider<CrmLeadNotifier, AsyncValue<void>>(
        (_) => CrmLeadNotifier());

class CrmLeadNotifier extends StateNotifier<AsyncValue<void>> {
  CrmLeadNotifier() : super(const AsyncValue.data(null));

  Future<bool> save(Map<String, dynamic> data, {String? id}) async {
    state = const AsyncValue.loading();
    try {
      if (id != null) {
        await sbClient.from('crm_leads').update(data).eq('id', id);
      } else {
        await sbClient.from('crm_leads').insert(data);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateStage(String id, String stage) async {
    state = const AsyncValue.loading();
    try {
      await sbClient.from('crm_leads').update({
        'stage':      stage,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
