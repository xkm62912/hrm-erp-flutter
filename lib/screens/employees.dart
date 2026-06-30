import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../providers/providers.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});
  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  @override
  Widget build(BuildContext context) {
    final empsAsync  = ref.watch(employeesProvider);
    final statsAsync = ref.watch(employeeStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => ref.read(empSearchProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Search name, code, email...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: ref.watch(empSearchProvider).isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () =>
                          ref.read(empSearchProvider.notifier).state = '',
                    )
                  : null,
            ),
          ),
        ),
        // Stats chips
        statsAsync.when(
          loading: () => const SizedBox(height: 40),
          error: (_, __) => const SizedBox.shrink(),
          data: (s) => SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('Total',    '${s['total']}',    AppColors.primary),
                _chip('Active',   '${s['active']}',   AppColors.success),
                _chip('On Leave', '${s['on_leave']}', AppColors.warning),
                _chip('New/30d',  '${s['new']}',      AppColors.info),
              ],
            ),
          ),
        ),
        // Status filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const Text('Filter: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ...['All', 'active', 'inactive', 'on_leave'].map((s) =>
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(s == 'All' ? 'All' : s.replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 11)),
                  selected: (ref.watch(empStatusProvider) ?? 'All') == s,
                  onSelected: (_) =>
                      ref.read(empStatusProvider.notifier).state =
                          s == 'All' ? null : s,
                ),
              )),
          ]),
        ),
        // List
        Expanded(child: empsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (emps) => emps.isEmpty
              ? const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textHint),
                    SizedBox(height: 12),
                    Text('No employees found', style: TextStyle(color: AppColors.textSecondary)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(employeesProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: emps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _EmpCard(
                        emp: emps[i],
                        onTap: () => _openDetail(context, emps[i])),
                  ),
                ),
        )),
      ]),
    );
  }

  Widget _chip(String label, String val, Color color) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
    ]),
  );

  void _openForm(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const EmployeeFormScreen()));

  void _openDetail(BuildContext context, Map<String, dynamic> emp) {
    ref.read(selectedEmployeeIdProvider.notifier).state = emp['id'] as String;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => EmployeeDetailScreen(emp: emp)));
  }
}

class _EmpCard extends StatelessWidget {
  final Map<String, dynamic> emp;
  final VoidCallback onTap;
  const _EmpCard({required this.emp, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'active':   return AppColors.success;
      case 'on_leave': return AppColors.warning;
      case 'inactive': return AppColors.error;
      default:         return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name   = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    final status = emp['status'] as String? ?? 'active';
    final dept   = (emp['departments'] as Map?)?['name'] as String? ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary,
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${emp['designation'] ?? ''}${dept.isNotEmpty ? ' • $dept' : ''}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis),
            Text(emp['emp_code'] as String? ?? '',
                style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(
                    color: _statusColor(status), shape: BoxShape.circle)),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 18),
          ]),
        ]),
      ),
    );
  }
}

// ── Employee Detail ───────────────────────────────────────────
class EmployeeDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> emp;
  const EmployeeDetailScreen({super.key, required this.emp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    final dept = (emp['departments'] as Map?)?['name'] as String? ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => EmployeeFormScreen(emp: emp))),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Column(children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary,
                    fontWeight: FontWeight.bold, fontSize: 36)),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(emp['designation'] as String? ?? '',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _badge(emp['emp_code'] as String? ?? '', AppColors.primary),
            const SizedBox(width: 8),
            _badge((emp['status'] as String? ?? '').toUpperCase(),
                emp['status'] == 'active' ? AppColors.success : AppColors.error),
          ]),
        ])),
        const SizedBox(height: 24),
        _section('Contact'),
        _row(Icons.email_rounded,    'Email',   emp['email']  as String? ?? ''),
        _row(Icons.phone_rounded,    'Phone',   emp['phone']  as String? ?? 'Not set'),
        _row(Icons.location_on_rounded, 'Address', emp['address'] as String? ?? 'Not set'),
        const SizedBox(height: 16),
        _section('Employment'),
        _row(Icons.calendar_today_rounded, 'Join Date',   emp['join_date']        as String? ?? ''),
        _row(Icons.account_tree_rounded,   'Department',  dept),
        _row(Icons.work_rounded,           'Type',        emp['employment_type']  as String? ?? ''),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );

  Widget _row(IconData icon, String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: AppColors.textHint),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    ]),
  );
}

// ── Employee Form ─────────────────────────────────────────────
class EmployeeFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? emp;
  const EmployeeFormScreen({super.key, this.emp});
  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<EmployeeFormScreen> {
  final _formKey  = GlobalKey<FormState>();
  late final _fn  = TextEditingController(text: widget.emp?['first_name'] as String? ?? '');
  late final _ln  = TextEditingController(text: widget.emp?['last_name']  as String? ?? '');
  late final _em  = TextEditingController(text: widget.emp?['email']       as String? ?? '');
  late final _ph  = TextEditingController(text: widget.emp?['phone']       as String? ?? '');
  late final _des = TextEditingController(text: widget.emp?['designation'] as String? ?? '');
  late final _sal = TextEditingController();
  String _type    = 'full_time';
  String? _deptId;
  DateTime _joinDate = DateTime.now();
  bool _loading   = false;

  bool get _isEdit => widget.emp != null;

  @override
  void dispose() {
    _fn.dispose(); _ln.dispose(); _em.dispose();
    _ph.dispose(); _des.dispose(); _sal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = {
        'first_name':       _fn.text.trim(),
        'last_name':        _ln.text.trim(),
        'email':            _em.text.trim(),
        'phone':            _ph.text.trim(),
        'designation':      _des.text.trim(),
        'employment_type':  _type,
        'department_id':    _deptId,
        'join_date':        _joinDate.toIso8601String().substring(0, 10),
      };
      String empId;
      if (_isEdit) {
        await sbClient.from('employees')
            .update(data).eq('id', widget.emp!['id'] as String);
        empId = widget.emp!['id'] as String;
      } else {
        final existing = await sbClient.from('employees').select('id');
        final count = (existing as List).length;
        data['emp_code'] = 'EMP-${(count + 1).toString().padLeft(4, '0')}';
        final r = await sbClient.from('employees').insert(data).select().single();
        empId = r['id'] as String;
      }
      if (_sal.text.isNotEmpty) {
        await sbClient.from('salary_structures').upsert({
          'employee_id':  empId,
          'basic_salary': double.parse(_sal.text),
          'effective_from': _joinDate.toIso8601String().substring(0, 10),
          'is_active':    true,
        }, onConflict: 'employee_id');
      }
      ref.invalidate(employeesProvider);
      ref.invalidate(employeeStatsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Employee ${_isEdit ? 'updated' : 'created'} ✓'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(departmentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Employee' : 'New Employee')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _ff('First Name *', _fn, Icons.person_rounded,
              validator: (v) => v!.isEmpty ? 'Required' : null),
          _ff('Last Name *', _ln, Icons.person_rounded,
              validator: (v) => v!.isEmpty ? 'Required' : null),
          _ff('Email *', _em, Icons.email_rounded,
              type: TextInputType.emailAddress,
              validator: (v) => !v!.contains('@') ? 'Valid email required' : null),
          _ff('Phone', _ph, Icons.phone_rounded, type: TextInputType.phone),
          _ff('Designation *', _des, Icons.work_rounded,
              validator: (v) => v!.isEmpty ? 'Required' : null),
          deptsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (depts) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: _deptId,
                hint: const Text('Select Department'),
                decoration: const InputDecoration(
                    labelText: 'Department', prefixIcon: Icon(Icons.account_tree_rounded)),
                items: depts.map((d) => DropdownMenuItem(
                    value: d['id'] as String,
                    child: Text(d['name'] as String))).toList(),
                onChanged: (v) => setState(() => _deptId = v),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                  labelText: 'Employment Type', prefixIcon: Icon(Icons.badge_rounded)),
              items: const [
                DropdownMenuItem(value: 'full_time',  child: Text('Full Time')),
                DropdownMenuItem(value: 'part_time',  child: Text('Part Time')),
                DropdownMenuItem(value: 'contract',   child: Text('Contract')),
                DropdownMenuItem(value: 'intern',     child: Text('Intern')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(context: context,
                  initialDate: _joinDate,
                  firstDate: DateTime(2000), lastDate: DateTime.now());
              if (d != null) setState(() => _joinDate = d);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Join Date', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                  Text(DateFormat('dd MMMM yyyy').format(_joinDate),
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ]),
              ]),
            ),
          ),
          _ff('Basic Salary (\$)', _sal, Icons.payments_rounded, type: TextInputType.number),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isEdit ? 'Update Employee' : 'Create Employee',
                      style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _ff(String label, TextEditingController ctrl, IconData icon,
      {TextInputType type = TextInputType.text,
      String? Function(String?)? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl, keyboardType: type, validator: validator,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
      );
}
