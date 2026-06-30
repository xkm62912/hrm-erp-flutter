import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/colors.dart';
import '../providers/providers.dart';

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(payrollRunsProvider);
    final roleAsync = ref.watch(userRoleProvider);
    final currency  = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      body: runsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (runs) => runs.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.payments_outlined, size: 64, color: AppColors.textHint),
                const SizedBox(height: 12),
                const Text('No payroll runs yet', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                roleAsync.maybeWhen(
                  data: (role) => (role == 'admin' || role == 'hr')
                      ? ElevatedButton.icon(
                          onPressed: () => _openRun(context),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Run Payroll'))
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
              ]))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(payrollRunsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: runs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final run  = runs[i];
                    final mName = DateFormat('MMMM yyyy').format(
                        DateTime(run['year'] as int, run['month'] as int));
                    final net  = (run['total_net'] as num? ?? 0).toDouble();
                    final st   = run['status'] as String? ?? 'draft';
                    return GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PayslipScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                                color: AppColors.payrollColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.receipt_long_rounded,
                                color: AppColors.payrollColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(mName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('${run['employee_count'] ?? 0} employees  •  ${currency.format(net)}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ])),
                          _statusChip(st),
                        ]),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: roleAsync.maybeWhen(
        data: (role) => (role == 'admin' || role == 'hr')
            ? FloatingActionButton.extended(
                onPressed: () => _openRun(context),
                backgroundColor: AppColors.payrollColor,
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label: const Text('Run Payroll', style: TextStyle(color: Colors.white)))
            : null,
        orElse: () => null,
      ),
    );
  }

  void _openRun(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const PayrollRunScreen()));

  Widget _statusChip(String status) {
    Color c;
    switch (status) {
      case 'approved': c = AppColors.success; break;
      case 'paid':     c = AppColors.info;    break;
      case 'processing': c = AppColors.warning; break;
      default:         c = AppColors.textHint;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Payroll Run Screen ────────────────────────────────────────
class PayrollRunScreen extends ConsumerStatefulWidget {
  const PayrollRunScreen({super.key});
  @override
  ConsumerState<PayrollRunScreen> createState() => _PayrollRunState();
}

class _PayrollRunState extends ConsumerState<PayrollRunScreen> {
  int _month = DateTime.now().month;
  int _year  = DateTime.now().year;
  final _months = ['January','February','March','April','May','June',
                   'July','August','September','October','November','December'];

  Future<void> _run() async {
    final confirm = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm Payroll Run'),
          content: Text('Run payroll for ${_months[_month-1]} $_year?\n'
              'This calculates salaries for all active employees.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Run')),
          ],
        ));
    if (confirm != true) return;
    final ok = await ref.read(payrollNotifierProvider.notifier).runPayroll(_month, _year);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(payrollRunsProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payroll processed ✓'), backgroundColor: AppColors.success));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed — payroll may already exist for this month'),
          backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(payrollNotifierProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Run Payroll')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.payrollColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.payrollColor.withOpacity(0.2))),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.payrollColor),
              SizedBox(width: 12),
              Expanded(child: Text(
                  'Payroll auto-calculates gross, deductions, and net pay based on '
                  'salary structures and attendance for the selected month.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            ]),
          ),
          const SizedBox(height: 32),
          DropdownButtonFormField<int>(
            value: _month,
            decoration: const InputDecoration(labelText: 'Month'),
            items: List.generate(12, (i) =>
                DropdownMenuItem(value: i+1, child: Text(_months[i]))),
            onChanged: (v) => setState(() => _month = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _year,
            decoration: const InputDecoration(labelText: 'Year'),
            items: [2024,2025,2026].map((y) =>
                DropdownMenuItem(value: y, child: Text('$y'))).toList(),
            onChanged: (v) => setState(() => _year = v!),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _run,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.payrollColor),
              icon: isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(isLoading ? 'Processing...' : 'Run ${_months[_month-1]} Payroll',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── My Payslip Screen ─────────────────────────────────────────
class PayslipScreen extends ConsumerWidget {
  const PayslipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslipAsync = ref.watch(myLatestPayslipProvider);
    final currency     = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Payslip'),
        actions: [
          payslipAsync.maybeWhen(
            data: (p) => p != null
                ? IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    onPressed: () => _generatePdf(context, p))
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: payslipAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) => p == null
            ? const Center(child: Text('No payslip found'))
            : ListView(padding: const EdgeInsets.all(16), children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(children: [
                    const Text('NET PAY', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(currency.format(p['net_salary'] ?? 0),
                        style: const TextStyle(color: Colors.white,
                            fontSize: 34, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(() {
                      final run = p['payroll_runs'] as Map?;
                      if (run == null) return '';
                      return DateFormat('MMMM yyyy').format(
                          DateTime(run['year'] as int, run['month'] as int));
                    }(),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _stat('Working Days', '${p['working_days'] ?? 0}'),
                      Container(height: 30, width: 1, color: Colors.white30),
                      _stat('Paid Days',    '${p['paid_days']    ?? 0}'),
                      Container(height: 30, width: 1, color: Colors.white30),
                      _stat('Absent',       '${p['absent_days']  ?? 0}'),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // Earnings
                _section('Earnings', AppColors.success, [
                  _item('Basic Salary',     p['basic_salary'],         currency),
                  _item('House Allowance',  p['house_allowance'],      currency),
                  _item('Transport',        p['transport_allowance'],  currency),
                  _item('Medical',          p['medical_allowance'],    currency),
                  _item('Other',            p['other_allowances'],     currency),
                ], total: p['gross_salary'], totalLabel: 'Gross Salary', currency: currency),

                const SizedBox(height: 12),

                // Deductions
                _section('Deductions', AppColors.error, [
                  _item('Tax',              p['tax_deduction'],        currency),
                  _item('Insurance',        p['insurance_deduction'],  currency),
                  _item('Provident Fund',   p['provident_fund'],       currency),
                  _item('Absent Deduction', p['absent_deduction'],     currency),
                ], total: p['total_deductions'], totalLabel: 'Total Deductions', currency: currency),

                const SizedBox(height: 80),
              ]),
      ),
    );
  }

  Widget _stat(String label, String val) => Column(children: [
    Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]);

  Map<String, dynamic> _item(String label, dynamic val, NumberFormat fmt) =>
      {'label': label, 'value': val, 'formatted': fmt.format(val ?? 0)};

  Widget _section(String title, Color color, List<Map<String, dynamic>> items,
      {dynamic total, required String totalLabel, required NumberFormat currency}) {
    final nonZero = items.where((i) => (i['value'] as num? ?? 0) > 0).toList();
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(color == AppColors.success ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          ]),
        ),
        const Divider(height: 1),
        ...nonZero.map((i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: Text(i['label'] as String,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            Text(i['formatted'] as String,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        )),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text(totalLabel, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
            Text(currency.format(total ?? 0),
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          ]),
        ),
      ]),
    );
  }

  Future<void> _generatePdf(BuildContext context, Map<String, dynamic> p) async {
    final currency = NumberFormat.currency(symbol: '\$');
    final run      = p['payroll_runs'] as Map? ?? {};
    final mName    = run.isNotEmpty
        ? DateFormat('MMMM yyyy').format(DateTime(run['year'] as int, run['month'] as int))
        : '';

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E3A5F'),
                borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('PAYSLIP', style: pw.TextStyle(
                  color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(mName, style: pw.TextStyle(color: PdfColors.grey300, fontSize: 13)),
            ]),
          ),
          pw.SizedBox(height: 24),
          _pdfRow('Basic Salary',       currency.format(p['basic_salary']        ?? 0)),
          _pdfRow('House Allowance',    currency.format(p['house_allowance']     ?? 0)),
          _pdfRow('Transport',          currency.format(p['transport_allowance'] ?? 0)),
          _pdfRow('Medical',            currency.format(p['medical_allowance']   ?? 0)),
          pw.Divider(),
          _pdfRow('Gross Salary',       currency.format(p['gross_salary']        ?? 0), bold: true),
          pw.SizedBox(height: 12),
          _pdfRow('Tax Deduction',      currency.format(p['tax_deduction']       ?? 0)),
          _pdfRow('Insurance',          currency.format(p['insurance_deduction'] ?? 0)),
          _pdfRow('Provident Fund',     currency.format(p['provident_fund']      ?? 0)),
          _pdfRow('Absent Deduction',   currency.format(p['absent_deduction']    ?? 0)),
          pw.Divider(),
          _pdfRow('Total Deductions',   currency.format(p['total_deductions']    ?? 0), bold: true),
          pw.SizedBox(height: 20),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0FDF4'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromHex('#22C55E'))),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('NET PAY', style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 16,
                  color: PdfColor.fromHex('#15803D'))),
              pw.Text(currency.format(p['net_salary'] ?? 0), style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 20,
                  color: PdfColor.fromHex('#15803D'))),
            ]),
          ),
          pw.Spacer(),
          pw.Center(child: pw.Text(
              'Computer-generated payslip. Does not require a signature.',
              style: pw.TextStyle(color: PdfColors.grey, fontSize: 9))),
        ],
      ),
    ));
    await Printing.sharePdf(bytes: await doc.save(), filename: 'payslip-$mName.pdf');
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : const pw.TextStyle()),
          pw.Text(value, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : const pw.TextStyle()),
        ]),
      );
}
