import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../providers/providers.dart';

const _stages = [
  _Stage('new',         'New',         Icons.fiber_new_rounded,    AppColors.info),
  _Stage('contacted',   'Contacted',   Icons.phone_rounded,        AppColors.primary),
  _Stage('qualified',   'Qualified',   Icons.thumb_up_rounded,     AppColors.warning),
  _Stage('proposal',    'Proposal',    Icons.description_rounded,  AppColors.hrColor),
  _Stage('negotiation', 'Negotiation', Icons.handshake_rounded,    AppColors.accent),
  _Stage('won',         'Won',         Icons.emoji_events_rounded, AppColors.success),
  _Stage('lost',        'Lost',        Icons.cancel_rounded,       AppColors.error),
];

class _Stage {
  final String key, label;
  final IconData icon;
  final Color color;
  const _Stage(this.key, this.label, this.icon, this.color);
}

_Stage _stageFor(String key) =>
    _stages.firstWhere((s) => s.key == key, orElse: () => _stages.first);

class CrmScreen extends ConsumerWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(crmStatsProvider);
    final leadsAsync = ref.watch(crmLeadsProvider);
    final currency   = NumberFormat.compactCurrency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ClientListScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats
          statsAsync.when(
            loading: () => _skel(80),
            error: (_, __) => const SizedBox.shrink(),
            data: (s) => Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.crmColor, Color(0xFFDB2777)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total Pipeline', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(currency.format(s['pipeline_value'] ?? 0),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _pStat('${s['won']} Won',      AppColors.success),
                    const SizedBox(width: 12),
                    _pStat('${s['lost']} Lost',    AppColors.error),
                    const SizedBox(width: 12),
                    _pStat('${s['in_progress']} Active', Colors.white),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${s['conversion_rate']}% Conv.',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _kpi('Total Leads', '${s['total_leads']}',  Icons.leaderboard_rounded, AppColors.primary),
                const SizedBox(width: 12),
                _kpi('Clients',     '${s['total_clients']}',Icons.business_rounded,     AppColors.crmColor),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // Pipeline board
          const Text('Pipeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          leadsAsync.when(
            loading: () => _skel(240),
            error: (_, __) => const SizedBox.shrink(),
            data: (leads) => SizedBox(
              height: 240,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _stages.where((s) => s.key != 'lost').map((stage) {
                  final stageLeads = leads.where((l) => l['stage'] == stage.key).toList();
                  return _PipelineCol(stage: stage, leads: stageLeads, ref: ref);
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Lead list
          const Text('All Leads', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => ref.read(crmSearchProvider.notifier).state = v,
            decoration: const InputDecoration(
                hintText: 'Search leads...', prefixIcon: Icon(Icons.search_rounded)),
          ),
          const SizedBox(height: 8),
          leadsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (leads) => Column(children: leads.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LeadCard(lead: l),
            )).toList()),
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LeadFormScreen())),
        backgroundColor: AppColors.crmColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Lead', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _pStat(String label, Color color) =>
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12));

  Widget _kpi(String label, String val, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ]),
    ),
  );
}

class _PipelineCol extends StatelessWidget {
  final _Stage stage;
  final List<Map<String, dynamic>> leads;
  final WidgetRef ref;
  const _PipelineCol({required this.stage, required this.leads, required this.ref});

  @override
  Widget build(BuildContext context) => Container(
    width: 160,
    margin: const EdgeInsets.only(right: 10),
    decoration: BoxDecoration(
        color: stage.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stage.color.withOpacity(0.2))),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Icon(stage.icon, size: 13, color: stage.color),
          const SizedBox(width: 5),
          Text(stage.label, style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.bold, color: stage.color)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: stage.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text('${leads.length}', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: stage.color)),
          ),
        ]),
      ),
      Expanded(child: leads.isEmpty
          ? Center(child: Text('Empty', style: TextStyle(
              color: stage.color.withOpacity(0.4), fontSize: 11)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              itemCount: leads.length,
              itemBuilder: (_, i) => _MiniCard(
                  lead: leads[i], color: stage.color, ref: ref),
            )),
    ]),
  );
}

class _MiniCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final Color color;
  final WidgetRef ref;
  const _MiniCard({required this.lead, required this.color, required this.ref});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(symbol: '\$');
    final val = (lead['deal_value'] as num? ?? 0).toDouble();
    return GestureDetector(
      onLongPress: () => _moveDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lead['company_name'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if ((lead['contact_name'] as String? ?? '').isNotEmpty)
            Text(lead['contact_name'] as String,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          if (val > 0)
            Text(currency.format(val),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ]),
      ),
    );
  }

  void _moveDialog(BuildContext context) => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Move to Stage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ..._stages.map((s) => ListTile(
          leading: Icon(s.icon, color: s.color),
          title: Text(s.label),
          dense: true,
          onTap: () async {
            Navigator.pop(context);
            await ref.read(crmLeadNotifierProvider.notifier)
                .updateStage(lead['id'] as String, s.key);
            ref.invalidate(crmLeadsProvider);
            ref.invalidate(crmStatsProvider);
          },
        )),
      ]),
    ),
  );
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(symbol: '\$');
    final stage    = _stageFor(lead['stage'] as String? ?? 'new');
    final val      = (lead['deal_value'] as num? ?? 0).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(color: stage.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(stage.icon, color: stage.color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lead['company_name'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(lead['contact_name'] as String? ?? '',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (val > 0) Text(currency.format(val),
              style: const TextStyle(fontWeight: FontWeight.bold,
                  color: AppColors.payrollColor, fontSize: 12)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: stage.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(stage.label, style: TextStyle(color: stage.color,
                fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );
  }
}

// ── Lead Form ─────────────────────────────────────────────────
class LeadFormScreen extends ConsumerStatefulWidget {
  final String? leadId;
  const LeadFormScreen({super.key, this.leadId});
  @override
  ConsumerState<LeadFormScreen> createState() => _LeadFormState();
}

class _LeadFormState extends ConsumerState<LeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _contact = TextEditingController();
  final _email   = TextEditingController();
  final _phone   = TextEditingController();
  final _value   = TextEditingController();
  final _notes   = TextEditingController();
  String _stage  = 'new';

  @override
  void dispose() {
    _company.dispose(); _contact.dispose(); _email.dispose();
    _phone.dispose(); _value.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      'company_name': _company.text.trim(),
      'contact_name': _contact.text.trim(),
      'email':        _email.text.trim(),
      'phone':        _phone.text.trim(),
      'deal_value':   double.tryParse(_value.text) ?? 0,
      'stage':        _stage,
      'notes':        _notes.text.trim(),
    };
    final ok = await ref.read(crmLeadNotifierProvider.notifier)
        .save(data, id: widget.leadId);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(crmLeadsProvider);
      ref.invalidate(crmStatsProvider);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(crmLeadNotifierProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: Text(widget.leadId != null ? 'Edit Lead' : 'New Lead')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _ff('Company Name *', _company, Icons.business_rounded,
              validator: (v) => v!.isEmpty ? 'Required' : null),
          _ff('Contact Name', _contact, Icons.person_rounded),
          _ff('Email', _email, Icons.email_rounded, type: TextInputType.emailAddress),
          _ff('Phone', _phone, Icons.phone_rounded, type: TextInputType.phone),
          _ff('Deal Value (\$)', _value, Icons.monetization_on_rounded,
              type: TextInputType.number),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: _stage,
              decoration: const InputDecoration(labelText: 'Stage'),
              items: _stages.map((s) => DropdownMenuItem(
                  value: s.key,
                  child: Row(children: [
                    Icon(s.icon, color: s.color, size: 16),
                    const SizedBox(width: 8),
                    Text(s.label),
                  ]))).toList(),
              onChanged: (v) => setState(() => _stage = v!),
            ),
          ),
          _ff('Notes', _notes, Icons.notes_rounded, maxLines: 3),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.crmColor),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(widget.leadId != null ? 'Update Lead' : 'Create Lead',
                      style: const TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _ff(String label, TextEditingController ctrl, IconData icon,
      {TextInputType type = TextInputType.text,
      String? Function(String?)? validator, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl, keyboardType: type,
          validator: validator, maxLines: maxLines,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
      );
}

// ── Client List ───────────────────────────────────────────────
class ClientListScreen extends ConsumerWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(crmClientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (clients) => clients.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.business_outlined, size: 64, color: AppColors.textHint),
                SizedBox(height: 12),
                Text('No clients yet', style: TextStyle(color: AppColors.textSecondary)),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: clients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c    = clients[i];
                  final name = c['company_name'] as String? ?? '';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: AppColors.crmColor.withOpacity(0.1),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.crmColor,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if ((c['contact_name'] as String? ?? '').isNotEmpty)
                          Text(c['contact_name'] as String,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ])),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}

Widget _skel(double h) => Container(
    height: h,
    decoration: BoxDecoration(
        color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)));
