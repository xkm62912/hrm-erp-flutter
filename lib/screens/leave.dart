import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../providers/providers.dart';

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myLeaveRequestsProvider);
    final roleAsync     = ref.watch(userRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leaves'),
        actions: [
          roleAsync.maybeWhen(
            data: (role) => (role == 'admin' || role == 'hr' || role == 'manager')
                ? IconButton(
                    icon: const Icon(Icons.pending_actions_rounded),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LeaveApprovalScreen())),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (requests) => requests.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.event_busy_rounded, size: 64, color: AppColors.textHint),
                const SizedBox(height: 12),
                const Text('No leave requests yet',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _apply(context),
                  icon: const Icon(Icons.add), label: const Text('Apply Leave'),
                ),
              ]))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myLeaveRequestsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LeaveCard(req: requests[i]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _apply(context),
        backgroundColor: AppColors.leaveColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Apply Leave', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _apply(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const LeaveRequestScreen()));
}

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> req;
  const _LeaveCard({required this.req});

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':  return AppColors.success;
      case 'rejected':  return AppColors.error;
      case 'cancelled': return AppColors.textHint;
      default:          return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status    = req['status'] as String? ?? 'pending';
    final leaveType = (req['leave_types'] as Map?)?['name'] as String? ?? '';
    final from      = req['from_date'] as String? ?? '';
    final to        = req['to_date']   as String? ?? '';
    final days      = req['total_days'] as int? ?? 0;
    final color     = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 4, height: 60,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(leaveType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('$from → $to  •  $days day${days > 1 ? 's' : ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if ((req['reason'] as String? ?? '').isNotEmpty)
            Text(req['reason'] as String,
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text(status.toUpperCase(),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ── Leave Request Form ────────────────────────────────────────
class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key});
  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestState();
}

class _LeaveRequestState extends ConsumerState<LeaveRequestScreen> {
  final _formKey     = GlobalKey<FormState>();
  String? _typeId;
  DateTime? _from, _to;
  final _reasonCtrl  = TextEditingController();
  bool _loading      = false;

  int get _days => (_from != null && _to != null)
      ? _to!.difference(_from!).inDays + 1 : 0;

  Future<void> _pickDate(bool isFrom) async {
    final now  = DateTime.now();
    final init = isFrom ? now : (_from ?? now);
    final d    = await showDatePicker(context: context,
        initialDate: init, firstDate: now, lastDate: DateTime(now.year + 1));
    if (d != null) setState(() { isFrom ? _from = d : _to = d; });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_typeId == null) { _snack('Select a leave type', isErr: true); return; }
    if (_from == null || _to == null) { _snack('Select dates', isErr: true); return; }
    setState(() => _loading = true);
    final ok = await ref.read(leaveNotifierProvider.notifier)
        .submit(leaveTypeId: _typeId!, from: _from!, to: _to!, reason: _reasonCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      ref.invalidate(myLeaveRequestsProvider);
      ref.invalidate(myLeaveBalancesProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Leave request submitted!'), backgroundColor: AppColors.success));
    } else {
      _snack('Failed to submit. Try again.', isErr: true);
    }
  }

  void _snack(String msg, {bool isErr = false}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg),
          backgroundColor: isErr ? AppColors.error : AppColors.success));

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(leaveTypesProvider);
    final balAsync   = ref.watch(myLeaveBalancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // Balances
          balAsync.maybeWhen(
            data: (bals) => bals.isEmpty ? const SizedBox.shrink()
                : SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: bals.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final b = bals[i];
                        final bal = b['balance_days'] as int? ??
                            (b['entitled_days'] as int? ?? 0) - (b['used_days'] as int? ?? 0);
                        return Container(
                          width: 100,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text((b['leave_types'] as Map?)?['name'] as String? ?? '',
                                style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const Spacer(),
                            Text('$bal', style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            const Text('days left', style: TextStyle(fontSize: 9, color: AppColors.textHint)),
                          ]),
                        );
                      },
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Leave type
          typesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error loading leave types'),
            data: (types) => DropdownButtonFormField<String>(
              value: _typeId,
              hint: const Text('Select leave type'),
              decoration: const InputDecoration(labelText: 'Leave Type'),
              items: types.map((t) => DropdownMenuItem(
                  value: t['id'] as String,
                  child: Row(children: [
                    Text(t['name'] as String),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: (t['is_paid'] as bool? ?? true)
                              ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text((t['is_paid'] as bool? ?? true) ? 'Paid' : 'Unpaid',
                          style: TextStyle(fontSize: 10,
                              color: (t['is_paid'] as bool? ?? true) ? AppColors.success : AppColors.error)),
                    ),
                  ]))).toList(),
              onChanged: (v) => setState(() => _typeId = v),
            ),
          ),
          const SizedBox(height: 14),

          // Date range
          Row(children: [
            Expanded(child: _datePicker('From', _from, () => _pickDate(true))),
            const SizedBox(width: 12),
            Expanded(child: _datePicker('To',   _to,   () => _pickDate(false))),
          ]),
          if (_days > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.info.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
                const SizedBox(width: 8),
                Text('Total: $_days day${_days > 1 ? 's' : ''}',
                    style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          const SizedBox(height: 14),

          TextFormField(
            controller: _reasonCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Reason', hintText: 'Describe the reason...'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Request', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: date != null ? AppColors.primary : AppColors.border)),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded, size: 16,
                color: date != null ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 8),
            Text(date != null ? DateFormat('dd MMM').format(date) : label,
                style: TextStyle(
                    color: date != null ? AppColors.textPrimary : AppColors.textHint,
                    fontWeight: date != null ? FontWeight.w600 : FontWeight.normal)),
          ]),
        ),
      );
}

// ── Leave Approval ────────────────────────────────────────────
class LeaveApprovalScreen extends ConsumerWidget {
  const LeaveApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingApprovalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Approvals')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (reqs) => reqs.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
                SizedBox(height: 12),
                Text('All caught up!', style: TextStyle(color: AppColors.textSecondary)),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reqs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ApprovalCard(req: reqs[i], ref: ref),
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
    final approver = await sbClient
        .from('employees').select('id').eq('user_id', sbClient.auth.currentUser!.id).maybeSingle();
    if (approver == null) return;
    final ok = await ref.read(leaveNotifierProvider.notifier)
        .updateStatus(req['id'] as String, status, approver['id'] as String);
    if (context.mounted) {
      ref.invalidate(pendingApprovalsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved' ? 'Approved ✓' : 'Rejected ✗'),
          backgroundColor: status == 'approved' ? AppColors.success : AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp       = req['employees'] as Map? ?? {};
    final name      = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    final leaveType = (req['leave_types'] as Map?)?['name'] as String? ?? '';
    final from      = req['from_date']  as String? ?? '';
    final to        = req['to_date']    as String? ?? '';
    final days      = req['total_days'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(emp['designation'] as String? ?? '',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: const Text('PENDING',
                style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
        const Divider(height: 20),
        Text('$leaveType  •  $from → $to  ($days days)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        if ((req['reason'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(req['reason'] as String,
              style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _respond(context, 'rejected'),
            icon: const Icon(Icons.close_rounded, color: AppColors.error),
            label: const Text('Reject', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _respond(context, 'approved'),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          )),
        ]),
      ]),
    );
  }
}
