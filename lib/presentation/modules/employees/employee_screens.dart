// lib/presentation/modules/employees/employee_screens.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/all_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EMPLOYEE LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  final _tabs = [('All', null), ('Active', 'active'), ('Inactive', 'inactive'), ('On Leave', 'on_leave')];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(employeeStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [IconButton(icon: const Icon(Icons.filter_list_rounded), onPressed: () {})],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search name, code, email...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _search = ''))
                    : null,
              ),
            ),
          ),
          statsAsync.when(
            loading: () => const SizedBox(height: 44),
            error: (_, __) => const SizedBox.shrink(),
            data: (s) => SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _StatChip('Total', '${s['total']}', AppColors.primary),
                  _StatChip('Active', '${s['active']}', AppColors.success),
                  _StatChip('On Leave', '${s['on_leave']}', AppColors.warning),
                  _StatChip('New (30d)', '${s['new']}', AppColors.info),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((t) {
                final empAsync = ref.watch(employeesProvider(EmployeeFilter(search: _search, status: t.$2)));
                return empAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (emps) => emps.isEmpty
                      ? Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            const Text('No employees found', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(onPressed: () => context.push('/employees/add'), icon: const Icon(Icons.add), label: const Text('Add Employee')),
                          ]),
                        )
                      : RefreshIndicator(
                          onRefresh: () => ref.refresh(employeesProvider(EmployeeFilter(search: _search)).future),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                            itemCount: emps.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => EmployeeCard(emp: emps[i], onTap: () => context.push('/employees/${emps[i]['id']}')),
                          ),
                        ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/employees/add'),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Employee', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value; final Color color;
  const _StatChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
    ]),
  );
}

// ─── Employee Card ────────────────────────────────────────────────────────────
class EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> emp; final VoidCallback onTap;
  const EmployeeCard({super.key, required this.emp, required this.onTap});

  Color _statusColor(String s) => s == 'active' ? AppColors.success : s == 'on_leave' ? AppColors.warning : s == 'terminated' ? AppColors.error : AppColors.textHint;

  @override
  Widget build(BuildContext context) {
    final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final status = emp['status'] as String? ?? 'active';
    final deptName = (emp['departments'] as Map?)?['name'] as String? ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          emp['avatar_url'] != null
              ? CircleAvatar(radius: 26, backgroundImage: NetworkImage(emp['avatar_url'] as String))
              : CircleAvatar(radius: 26, backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${emp['designation'] ?? ''}${deptName.isNotEmpty ? '  •  $deptName' : ''}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
            Text(emp['emp_code'] as String? ?? '', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle)),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 18),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPLOYEE DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeDetailScreen extends ConsumerWidget {
  final String id;
  const EmployeeDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(employeeDetailProvider(id));
    return Scaffold(
      body: empAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (emp) {
          final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
          final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
          final deptName = (emp['departments'] as Map?)?['name'] as String? ?? '';
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 220, pinned: true,
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              actions: [IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => context.push('/employees/$id/edit'))],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 48),
                    emp['avatar_url'] != null
                        ? CircleAvatar(radius: 44, backgroundImage: NetworkImage(emp['avatar_url'] as String))
                        : CircleAvatar(radius: 44, backgroundColor: Colors.white.withOpacity(0.2), child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 10),
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('${emp['designation'] ?? ''}  •  $deptName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _InfoChip(emp['emp_code'] as String? ?? '', Icons.badge_rounded, AppColors.primary),
                    const SizedBox(width: 8),
                    _InfoChip((emp['status'] as String? ?? 'active').toUpperCase(), Icons.circle, emp['status'] == 'active' ? AppColors.success : AppColors.error),
                    const SizedBox(width: 8),
                    _InfoChip(emp['employment_type'] as String? ?? '', Icons.work_rounded, AppColors.info),
                  ]),
                  const SizedBox(height: 20),
                  const _SectionHeader('Contact Information'),
                  _DetailTile(Icons.email_rounded, 'Email', emp['email'] as String? ?? ''),
                  _DetailTile(Icons.phone_rounded, 'Phone', emp['phone'] as String? ?? 'Not provided'),
                  _DetailTile(Icons.location_on_rounded, 'Address', emp['address'] as String? ?? 'Not provided'),
                  const SizedBox(height: 16),
                  const _SectionHeader('Employment Details'),
                  _DetailTile(Icons.calendar_today_rounded, 'Join Date', emp['join_date'] as String? ?? ''),
                  _DetailTile(Icons.account_tree_rounded, 'Department', deptName),
                  _DetailTile(Icons.supervisor_account_rounded, 'Type', emp['employment_type'] as String? ?? ''),
                  const SizedBox(height: 16),
                  const _SectionHeader('Salary'),
                  () {
                    final structures = emp['salary_structures'] as List? ?? [];
                    if (structures.isEmpty) return const _DetailTile(Icons.payments_rounded, 'Basic Salary', 'Not configured');
                    final sal = structures.first as Map;
                    final basic = (sal['basic_salary'] as num? ?? 0).toDouble();
                    return _DetailTile(Icons.payments_rounded, 'Basic Salary', NumberFormat.currency(symbol: '\$').format(basic));
                  }(),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/attendance'), icon: const Icon(Icons.fingerprint_rounded), label: const Text('Attendance'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton.icon(onPressed: () => context.push('/leave'), icon: const Icon(Icons.event_busy_rounded), label: const Text('Leaves'))),
                  ]),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label; final IconData icon; final Color color;
  const _InfoChip(this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color), const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title; const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );
}

class _DetailTile extends StatelessWidget {
  final IconData icon; final String label, value;
  const _DetailTile(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: AppColors.textHint), const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPLOYEE FORM SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  const EmployeeFormScreen({super.key, this.employeeId});
  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _basicSalaryCtrl = TextEditingController();
  String _employmentType = 'full_time';
  String? _departmentId;
  DateTime _joinDate = DateTime.now();
  bool _isLoading = false;
  bool get _isEdit => widget.employeeId != null;

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose();
    _designationCtrl.dispose(); _basicSalaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final client = ref.read(supabaseClientProvider);
    try {
      final empData = {
        'first_name': _firstNameCtrl.text.trim(), 'last_name': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(), 'phone': _phoneCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(), 'employment_type': _employmentType,
        'department_id': _departmentId, 'join_date': _joinDate.toIso8601String().substring(0, 10),
      };
      String empId;
      if (_isEdit) {
        await client.from('employees').update(empData).eq('id', widget.employeeId!);
        empId = widget.employeeId!;
      } else {
        final count = await client.from('employees').count();
        empData['emp_code'] = 'EMP-${(count + 1).toString().padLeft(4, '0')}';
        final res = await client.from('employees').insert(empData).select().single();
        empId = res['id'] as String;
      }
      if (_basicSalaryCtrl.text.isNotEmpty) {
        await client.from('salary_structures').upsert({
          'employee_id': empId, 'basic_salary': double.parse(_basicSalaryCtrl.text),
          'effective_from': _joinDate.toIso8601String().substring(0, 10), 'is_active': true,
        }, onConflict: 'employee_id');
      }
      ref.invalidate(employeesProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Employee ${_isEdit ? 'updated' : 'created'} ✓'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(departmentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Employee' : 'New Employee')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _FormSection('Personal Information'),
            Row(children: [
              Expanded(child: _FF('First Name *', _firstNameCtrl, Icons.person_rounded, validator: (v) => v?.isEmpty == true ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: _FF('Last Name *', _lastNameCtrl, Icons.person_rounded, validator: (v) => v?.isEmpty == true ? 'Required' : null)),
            ]),
            _FF('Email *', _emailCtrl, Icons.email_rounded, type: TextInputType.emailAddress, validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null),
            _FF('Phone', _phoneCtrl, Icons.phone_rounded, type: TextInputType.phone),
            const SizedBox(height: 8),
            const _FormSection('Employment'),
            _FF('Designation *', _designationCtrl, Icons.work_rounded, validator: (v) => v?.isEmpty == true ? 'Required' : null),
            deptsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (depts) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _departmentId, hint: const Text('Select Department'),
                  decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.account_tree_rounded)),
                  items: depts.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['name'] as String))).toList(),
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: _employmentType,
                decoration: const InputDecoration(labelText: 'Employment Type', prefixIcon: Icon(Icons.badge_rounded)),
                items: const [
                  DropdownMenuItem(value: 'full_time', child: Text('Full Time')),
                  DropdownMenuItem(value: 'part_time', child: Text('Part Time')),
                  DropdownMenuItem(value: 'contract', child: Text('Contract')),
                  DropdownMenuItem(value: 'intern', child: Text('Intern')),
                ],
                onChanged: (v) => setState(() => _employmentType = v!),
              ),
            ),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _joinDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                if (d != null) setState(() => _joinDate = d);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.textSecondary), const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Join Date', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                    Text(DateFormat('dd MMMM yyyy').format(_joinDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            const _FormSection('Salary'),
            _FF('Basic Salary (\$)', _basicSalaryCtrl, Icons.payments_rounded, type: TextInputType.number),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isEdit ? 'Update Employee' : 'Create Employee', style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  Widget _FF(String label, TextEditingController ctrl, IconData icon, {TextInputType type = TextInputType.text, String? Function(String?)? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(controller: ctrl, keyboardType: type, validator: validator, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon))),
      );
}

class _FormSection extends StatelessWidget {
  final String title; const _FormSection(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );
}
