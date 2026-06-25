// ─────────────────────────────────────────────────────────────────────────────
// leave_request_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/all_providers.dart';

class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedLeaveTypeId;
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _totalDays {
    if (_fromDate == null || _toDate == null) return 0;
    return _toDate!.difference(_fromDate!).inDays + 1;
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (now) : (_fromDate ?? now),
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLeaveTypeId == null) {
      _showSnack('Please select a leave type', isError: true);
      return;
    }
    if (_fromDate == null || _toDate == null) {
      _showSnack('Please select dates', isError: true);
      return;
    }

    final ok = await ref.read(leaveRequestNotifierProvider.notifier).submitRequest(
          leaveTypeId: _selectedLeaveTypeId!,
          fromDate: _fromDate!,
          toDate: _toDate!,
          reason: _reasonCtrl.text.trim(),
        );

    if (!mounted) return;
    if (ok) {
      _showSnack('Leave request submitted!');
      context.pop();
    } else {
      _showSnack('Failed to submit request', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final leaveTypesAsync = ref.watch(leaveTypesProvider);
    final balancesAsync = ref.watch(myLeaveBalancesProvider);
    final isLoading = ref.watch(leaveRequestNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Leave Balances ───────────────────────────────────────────
              balancesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (balances) => balances.isEmpty
                    ? const SizedBox.shrink()
                    : _LeaveBalanceRow(balances: balances),
              ),

              const SizedBox(height: 20),
              _label('Leave Type *'),
              const SizedBox(height: 8),
              leaveTypesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error loading leave types'),
                data: (types) => DropdownButtonFormField<String>(
                  value: _selectedLeaveTypeId,
                  hint: const Text('Select leave type'),
                  decoration: const InputDecoration(),
                  items: types
                      .map((t) => DropdownMenuItem(
                            value: t['id'] as String,
                            child: Row(
                              children: [
                                Text(t['name'] as String),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (t['is_paid'] as bool)
                                        ? AppColors.success.withOpacity(0.1)
                                        : AppColors.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (t['is_paid'] as bool) ? 'Paid' : 'Unpaid',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: (t['is_paid'] as bool)
                                            ? AppColors.success
                                            : AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedLeaveTypeId = v),
                ),
              ),

              const SizedBox(height: 16),
              _label('Date Range *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerBtn(
                      label: 'From',
                      date: _fromDate,
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePickerBtn(
                      label: 'To',
                      date: _toDate,
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),

              if (_totalDays > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.info, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Total: $_totalDays day${_totalDays > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              _label('Reason'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Briefly describe the reason for leave...',
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textSecondary));
}

// ─── Leave Balance Row ────────────────────────────────────────────────────────
class _LeaveBalanceRow extends StatelessWidget {
  final List<Map<String, dynamic>> balances;
  const _LeaveBalanceRow({required this.balances});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: balances.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final b = balances[i];
          final balance = b['balance_days'] as int? ?? 0;
          final entitled = b['entitled_days'] as int? ?? 0;
          return Container(
            width: 110,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (b['leave_types'] as Map?)?['name'] ?? '',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text('$balance',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                Text('of $entitled days',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textHint)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Date Picker Button ───────────────────────────────────────────────────────
class _DatePickerBtn extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DatePickerBtn(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: date != null ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16,
                color: date != null ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null
                    ? DateFormat('dd MMM').format(date!)
                    : label,
                style: TextStyle(
                    fontSize: 13,
                    color: date != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                    fontWeight: date != null ? FontWeight.w600 : FontWeight.normal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// leave_list_screen.dart — employee's own leave history
// ─────────────────────────────────────────────────────────────────────────────
class LeaveListScreen extends ConsumerWidget {
  const LeaveListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myLeaveRequestsProvider);
    final roleAsync = ref.watch(userRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leaves'),
        actions: [
          roleAsync.maybeWhen(
            data: (role) => (role == 'admin' || role == 'hr' || role == 'manager')
                ? IconButton(
                    icon: const Icon(Icons.pending_actions_rounded),
                    tooltip: 'Pending Approvals',
                    onPressed: () => context.push('/leave/approval'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (requests) => requests.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy_rounded,
                        size: 64, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    const Text('No leave requests found',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/leave/request'),
                      icon: const Icon(Icons.add),
                      label: const Text('Apply Leave'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _LeaveRequestCard(req: requests[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/leave/request'),
        backgroundColor: AppColors.leaveColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Apply Leave', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _LeaveRequestCard extends StatelessWidget {
  final Map<String, dynamic> req;
  const _LeaveRequestCard({required this.req});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'cancelled':
        return AppColors.textHint;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = req['status'] as String? ?? 'pending';
    final leaveType = (req['leave_types'] as Map?)?['name'] ?? '';
    final from = req['from_date'] as String? ?? '';
    final to = req['to_date'] as String? ?? '';
    final days = req['total_days'] as int? ?? 0;
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leaveType,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  '$from → $to  •  $days day${days > 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                if (req['reason'] != null && (req['reason'] as String).isNotEmpty)
                  Text(req['reason'] as String,
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// leave_approval_screen.dart — manager/hr approval workflow
// ─────────────────────────────────────────────────────────────────────────────
class LeaveApprovalScreen extends ConsumerWidget {
  const LeaveApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingLeaveApprovalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Approvals')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (requests) => requests.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 64, color: AppColors.success),
                    SizedBox(height: 12),
                    Text('All caught up! No pending requests.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _ApprovalCard(req: requests[i], ref: ref),
              ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final WidgetRef ref;
  const _ApprovalCard({required this.req, required this.ref});

  Future<void> _respond(BuildContext context, String status) async {
    // Get approver employee ID
    final client = ref.read(supabaseClientProvider);
    final approver = await client
        .from('employees')
        .select('id')
        .eq('user_id', client.auth.currentUser!.id)
        .maybeSingle();
    if (approver == null) return;

    await ref.read(leaveRequestNotifierProvider.notifier).updateStatus(
          req['id'] as String,
          status,
          approver['id'] as String,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Leave ${status == 'approved' ? 'Approved ✓' : 'Rejected ✗'}'),
        backgroundColor:
            status == 'approved' ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = req['employees'] as Map? ?? {};
    final empName =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    final designation = employee['designation'] as String? ?? '';
    final leaveType = (req['leave_types'] as Map?)?['name'] ?? '';
    final from = req['from_date'] as String? ?? '';
    final to = req['to_date'] as String? ?? '';
    final days = req['total_days'] as int? ?? 0;
    final reason = req['reason'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee info
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  empName.isNotEmpty ? empName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(empName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(designation,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('PENDING',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const Divider(height: 20),

          // Leave details
          Row(
            children: [
              _detail(Icons.event_rounded, leaveType),
              const SizedBox(width: 16),
              _detail(Icons.calendar_month_rounded,
                  '$from → $to  ($days days)'),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            _detail(Icons.notes_rounded, reason),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _respond(context, 'rejected'),
                  icon: const Icon(Icons.close_rounded, color: AppColors.error),
                  label: const Text('Reject',
                      style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _respond(context, 'approved'),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textHint),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}
