// lib/presentation/modules/crm/crm_screens.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/all_providers.dart';

// Pipeline stages
const _stages = [
  _Stage('new', 'New', Icons.fiber_new_rounded, AppColors.info),
  _Stage('contacted', 'Contacted', Icons.phone_rounded, AppColors.primary),
  _Stage('qualified', 'Qualified', Icons.thumb_up_rounded, AppColors.warning),
  _Stage('proposal', 'Proposal', Icons.description_rounded, AppColors.hrColor),
  _Stage('negotiation', 'Negotiation', Icons.handshake_rounded, AppColors.accent),
  _Stage('won', 'Won', Icons.emoji_events_rounded, AppColors.success),
  _Stage('lost', 'Lost', Icons.cancel_rounded, AppColors.error),
];

class _Stage {
  final String key, label;
  final IconData icon;
  final Color color;
  const _Stage(this.key, this.label, this.icon, this.color);
}

_Stage _stageFor(String key) =>
    _stages.firstWhere((s) => s.key == key, orElse: () => _stages.first);

// ─────────────────────────────────────────────────────────────────────────────
// CRM DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────
class CrmDashboardScreen extends ConsumerWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(crmStatsProvider);
    final currency = NumberFormat.compactCurrency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_rounded),
            onPressed: () => context.push('/crm/clients'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stats ─────────────────────────────────────────────────────
            statsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => Column(
                children: [
                  // Pipeline value banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.crmColor, Color(0xFFDB2777)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Pipeline Value',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          currency
                              .format(stats['pipeline_value'] ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _pipelineStat(
                                '${stats['won']} Won', AppColors.success),
                            const SizedBox(width: 12),
                            _pipelineStat(
                                '${stats['lost']} Lost', AppColors.error),
                            const SizedBox(width: 12),
                            _pipelineStat(
                                '${stats['in_progress']} Active',
                                Colors.white),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${stats['conversion_rate']}% Conv.',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // KPI row
                  Row(
                    children: [
                      _CrmKpiCard(
                          'Total Leads',
                          '${stats['total_leads']}',
                          Icons.leaderboard_rounded,
                          AppColors.primary),
                      const SizedBox(width: 12),
                      _CrmKpiCard(
                          'Clients',
                          '${stats['total_clients']}',
                          Icons.business_rounded,
                          AppColors.crmColor),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Pipeline Board ─────────────────────────────────────────────
            const Text('Pipeline',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _PipelineBoard(),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/crm/leads/add'),
        backgroundColor: AppColors.crmColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Add Lead', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _pipelineStat(String label, Color color) => Text(
        label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 12),
      );
}

class _CrmKpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _CrmKpiCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pipeline Board (horizontal scroll, stage columns) ───────────────────────
class _PipelineBoard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(crmLeadsProvider());

    return leadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (leads) => SizedBox(
        height: 280,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _stages
              .where((s) => s.key != 'lost')
              .map((stage) {
                final stageLeads =
                    leads.where((l) => l['stage'] == stage.key).toList();
                return _PipelineColumn(
                    stage: stage, leads: stageLeads, ref: ref);
              })
              .toList(),
        ),
      ),
    );
  }
}

class _PipelineColumn extends StatelessWidget {
  final _Stage stage;
  final List<Map<String, dynamic>> leads;
  final WidgetRef ref;
  const _PipelineColumn(
      {required this.stage, required this.leads, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: stage.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stage.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(stage.icon, size: 14, color: stage.color),
                const SizedBox(width: 6),
                Text(stage.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: stage.color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: stage.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${leads.length}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: stage.color)),
                ),
              ],
            ),
          ),
          // Lead cards
          Expanded(
            child: leads.isEmpty
                ? Center(
                    child: Text('No leads',
                        style: TextStyle(
                            color: stage.color.withOpacity(0.4),
                            fontSize: 11)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: leads.length,
                    itemBuilder: (_, i) => _MiniLeadCard(
                        lead: leads[i], stageColor: stage.color, ref: ref),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniLeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final Color stageColor;
  final WidgetRef ref;
  const _MiniLeadCard(
      {required this.lead, required this.stageColor, required this.ref});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(symbol: '\$');
    final dealValue = (lead['deal_value'] as num? ?? 0).toDouble();

    return GestureDetector(
      onLongPress: () => _showMoveDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: stageColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lead['company_name'] as String? ?? '',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              lead['contact_name'] as String? ?? '',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (dealValue > 0) ...[
              const SizedBox(height: 4),
              Text(
                currency.format(dealValue),
                style: TextStyle(
                    color: stageColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMoveDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Move to Stage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ..._stages.map((s) => ListTile(
                  leading: Icon(s.icon, color: s.color),
                  title: Text(s.label),
                  dense: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await ref
                        .read(crmLeadNotifierProvider.notifier)
                        .updateStage(lead['id'] as String, s.key);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEAD LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class LeadListScreen extends ConsumerStatefulWidget {
  const LeadListScreen({super.key});

  @override
  ConsumerState<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends ConsumerState<LeadListScreen> {
  String _search = '';
  String? _stageFilter;

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(crmLeadsProvider(
      stage: _stageFilter,
      search: _search,
    ));

    return Scaffold(
      appBar: AppBar(title: const Text('Leads')),
      body: Column(
        children: [
          // Search & Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Search leads...',
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  icon: const Icon(Icons.filter_list_rounded),
                  onSelected: (v) => setState(() => _stageFilter = v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: null, child: Text('All')),
                    ..._stages.map((s) => PopupMenuItem(
                          value: s.key,
                          child: Row(
                            children: [
                              Icon(s.icon, color: s.color, size: 16),
                              const SizedBox(width: 8),
                              Text(s.label),
                            ],
                          ),
                        )),
                  ],
                ),
              ],
            ),
          ),

          // Lead list
          Expanded(
            child: leadsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (leads) => leads.isEmpty
                  ? const Center(
                      child: Text('No leads found',
                          style:
                              TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: leads.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _LeadCard(lead: leads[i]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/crm/leads/add'),
        backgroundColor: AppColors.crmColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Add Lead', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(symbol: '\$');
    final stage = _stageFor(lead['stage'] as String? ?? 'new');
    final dealValue = (lead['deal_value'] as num? ?? 0).toDouble();
    final assignee = lead['employees'] as Map? ?? {};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: stage.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(stage.icon, color: stage.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead['company_name'] as String? ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(lead['contact_name'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                if (assignee.isNotEmpty)
                  Text(
                    'Assigned: ${assignee['first_name']} ${assignee['last_name']}',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 10),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (dealValue > 0)
                Text(
                  currency.format(dealValue),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.payrollColor,
                      fontSize: 13),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stage.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(stage.label,
                    style: TextStyle(
                        color: stage.color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEAD FORM SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class LeadFormScreen extends ConsumerStatefulWidget {
  final String? leadId;
  const LeadFormScreen({super.key, this.leadId});

  @override
  ConsumerState<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends ConsumerState<LeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dealValueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedStage = 'new';

  bool get _isEdit => widget.leadId != null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'company_name': _companyCtrl.text.trim(),
      'contact_name': _contactCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'deal_value': double.tryParse(_dealValueCtrl.text) ?? 0,
      'stage': _selectedStage,
      'notes': _notesCtrl.text.trim(),
    };

    final ok = await ref
        .read(crmLeadNotifierProvider.notifier)
        .saveLead(data, leadId: widget.leadId);

    if (!mounted) return;
    if (ok) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to save lead'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(crmLeadNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Lead' : 'New Lead')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _Field(label: 'Company Name *', ctrl: _companyCtrl,
                  icon: Icons.business_rounded,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null),
              _Field(label: 'Contact Name', ctrl: _contactCtrl,
                  icon: Icons.person_rounded),
              _Field(label: 'Email', ctrl: _emailCtrl,
                  icon: Icons.email_rounded,
                  type: TextInputType.emailAddress),
              _Field(label: 'Phone', ctrl: _phoneCtrl,
                  icon: Icons.phone_rounded, type: TextInputType.phone),
              _Field(label: 'Deal Value (\$)', ctrl: _dealValueCtrl,
                  icon: Icons.monetization_on_rounded,
                  type: TextInputType.number),

              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedStage,
                decoration: const InputDecoration(labelText: 'Stage'),
                items: _stages
                    .map((s) => DropdownMenuItem(
                          value: s.key,
                          child: Row(
                            children: [
                              Icon(s.icon, color: s.color, size: 16),
                              const SizedBox(width: 8),
                              Text(s.label),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStage = v!),
              ),

              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.crmColor),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isEdit ? 'Update Lead' : 'Create Lead',
                          style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType type;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.icon,
    this.type = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          keyboardType: type,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CLIENT LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ClientListScreen extends ConsumerWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(crmClientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (clients) => clients.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.business_outlined,
                        size: 64, color: AppColors.textHint),
                    SizedBox(height: 12),
                    Text('No clients yet',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: clients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final client = clients[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppColors.crmColor.withOpacity(0.1),
                          child: Text(
                            ((client['company_name'] as String?) ?? '?')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.crmColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client['company_name'] as String? ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              if (client['contact_name'] != null)
                                Text(
                                  client['contact_name'] as String,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textHint),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
