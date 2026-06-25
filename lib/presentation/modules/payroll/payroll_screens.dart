// lib/presentation/modules/payroll/payroll_screens.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/all_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAYROLL LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PayrollListScreen extends ConsumerWidget {
  const PayrollListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(payrollRunsProvider);
    final roleAsync = ref.watch(userRoleProvider);
    final currency = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      body: runsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (runs) => runs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payments_outlined,
                        size: 64, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    const Text('No payroll runs yet'),
                    const SizedBox(height: 16),
                    roleAsync.maybeWhen(
                      data: (role) =>
                          (role == 'admin' || role == 'hr')
                              ? ElevatedButton.icon(
                                  onPressed: () => context.push('/payroll/run'),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Run Payroll'),
                                )
                              : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: runs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final run = runs[i];
                  final monthName = DateFormat('MMMM yyyy').format(
                    DateTime(run['year'] as int, run['month'] as int),
                  );
                  final status = run['status'] as String;
                  final totalNet = (run['total_net'] as num? ?? 0).toDouble();

                  return GestureDetector(
                    onTap: () => context.push('/payroll/payslip/${run['id']}',
                        extra: run),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.payrollColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_rounded,
                                color: AppColors.payrollColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(monthName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text(
                                  '${run['employee_count'] ?? 0} employees  •  ${currency.format(totalNet)}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(status: status),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: roleAsync.maybeWhen(
        data: (role) => (role == 'admin' || role == 'hr')
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/payroll/run'),
                backgroundColor: AppColors.payrollColor,
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label: const Text('Run Payroll',
                    style: TextStyle(color: Colors.white)),
              )
            : const SizedBox.shrink(),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYROLL RUN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PayrollRunScreen extends ConsumerStatefulWidget {
  const PayrollRunScreen({super.key});

  @override
  ConsumerState<PayrollRunScreen> createState() => _PayrollRunScreenState();
}

class _PayrollRunScreenState extends ConsumerState<PayrollRunScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  Future<void> _runPayroll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Payroll Run'),
        content: Text(
          'Run payroll for ${_months[_selectedMonth - 1]} $_selectedYear?\n\n'
          'This will calculate salaries for all active employees.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run')),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await ref.read(payrollRunNotifierProvider.notifier).runPayroll(
          month: _selectedMonth,
          year: _selectedYear,
        );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payroll processed successfully! ✓'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to process payroll. Check if already run.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(payrollRunNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Run Payroll')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.payrollColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.payrollColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.payrollColor),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Payroll will auto-calculate gross salary, deductions, and net pay based on salary structures and attendance.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text('Select Period',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Month picker
            DropdownButtonFormField<int>(
              value: _selectedMonth,
              decoration: const InputDecoration(labelText: 'Month'),
              items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                      value: i + 1, child: Text(_months[i]))),
              onChanged: (v) => setState(() => _selectedMonth = v!),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(labelText: 'Year'),
              items: [2024, 2025, 2026]
                  .map((y) =>
                      DropdownMenuItem(value: y, child: Text('$y')))
                  .toList(),
              onChanged: (v) => setState(() => _selectedYear = v!),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _runPayroll,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.payrollColor),
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  isLoading
                      ? 'Processing...'
                      : 'Run ${_months[_selectedMonth - 1]} Payroll',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYSLIP DETAIL SCREEN — with PDF generation
// ─────────────────────────────────────────────────────────────────────────────
class PayslipDetailScreen extends ConsumerWidget {
  final String payslipId;
  const PayslipDetailScreen({super.key, required this.payslipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In a real app, fetch individual payslip by ID
    // For this example, we use the latest payslip if it matches
    final payslipAsync = ref.watch(myLatestPayslipProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslip'),
        actions: [
          payslipAsync.maybeWhen(
            data: (payslip) => payslip != null
                ? IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    onPressed: () => _generateAndSharePDF(context, payslip),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: payslipAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (payslip) => payslip == null
            ? const Center(child: Text('Payslip not found'))
            : _PayslipView(payslip: payslip),
      ),
    );
  }

  Future<void> _generateAndSharePDF(
      BuildContext context, Map<String, dynamic> payslip) async {
    final pdf = await _buildPayslipPDF(payslip);
    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'payslip.pdf');
  }

  Future<pw.Document> _buildPayslipPDF(
      Map<String, dynamic> payslip) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(symbol: '\$');
    final run = payslip['payroll_runs'] as Map? ?? {};
    final monthName = run['month'] != null
        ? DateFormat('MMMM yyyy')
            .format(DateTime(run['year'] as int, run['month'] as int))
        : 'N/A';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1E3A5F'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PAYSLIP',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Text(monthName,
                        style: const pw.TextStyle(
                            color: PdfColors.white70, fontSize: 14)),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Company & Employee Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Company', style: _pdfLabel()),
                        pw.Text('HRM Corp Ltd.',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('123 Business Ave, Suite 400'),
                        pw.Text('New York, NY 10001'),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Employee', style: _pdfLabel()),
                        pw.Text('Working Days: ${payslip['working_days'] ?? 0}'),
                        pw.Text('Paid Days: ${payslip['paid_days'] ?? 0}'),
                        pw.Text('Absent Days: ${payslip['absent_days'] ?? 0}'),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Earnings table
              pw.Text('Earnings',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 8),
              _pdfRow('Basic Salary',
                  currency.format(payslip['basic_salary'] ?? 0)),
              _pdfRow('House Allowance',
                  currency.format(payslip['house_allowance'] ?? 0)),
              _pdfRow('Transport Allowance',
                  currency.format(payslip['transport_allowance'] ?? 0)),
              _pdfRow('Medical Allowance',
                  currency.format(payslip['medical_allowance'] ?? 0)),
              _pdfRow('Other Allowances',
                  currency.format(payslip['other_allowances'] ?? 0)),
              pw.Divider(),
              _pdfRow('Gross Salary',
                  currency.format(payslip['gross_salary'] ?? 0),
                  bold: true),

              pw.SizedBox(height: 16),

              // Deductions
              pw.Text('Deductions',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 8),
              _pdfRow(
                  'Tax', currency.format(payslip['tax_deduction'] ?? 0)),
              _pdfRow('Insurance',
                  currency.format(payslip['insurance_deduction'] ?? 0)),
              _pdfRow('Provident Fund',
                  currency.format(payslip['provident_fund'] ?? 0)),
              _pdfRow('Absent Deduction',
                  currency.format(payslip['absent_deduction'] ?? 0)),
              pw.Divider(),
              _pdfRow('Total Deductions',
                  currency.format(payslip['total_deductions'] ?? 0),
                  bold: true),

              pw.SizedBox(height: 20),

              // Net Pay
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F0FDF4'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#22C55E')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET PAY',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                          color: PdfColor.fromHex('#15803D'),
                        )),
                    pw.Text(
                      currency.format(payslip['net_salary'] ?? 0),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 20,
                        color: PdfColor.fromHex('#15803D'),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'This is a computer-generated payslip and does not require a signature.',
                  style: const pw.TextStyle(
                      color: PdfColors.grey, fontSize: 9),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.TextStyle _pdfLabel() =>
      const pw.TextStyle(color: PdfColors.grey, fontSize: 10);

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: bold
                  ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                  : const pw.TextStyle()),
          pw.Text(value,
              style: bold
                  ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                  : const pw.TextStyle()),
        ],
      ),
    );
  }
}

// ─── Payslip View Widget ──────────────────────────────────────────────────────
class _PayslipView extends StatelessWidget {
  final Map<String, dynamic> payslip;
  const _PayslipView({required this.payslip});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final run = payslip['payroll_runs'] as Map? ?? {};
    final monthName = run['month'] != null
        ? DateFormat('MMMM yyyy')
            .format(DateTime(run['year'] as int, run['month'] as int))
        : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: Colors.white54, size: 40),
                const SizedBox(height: 8),
                const Text('NET PAY',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  currency.format(payslip['net_salary'] ?? 0),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(monthName,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _headerStat('Working Days',
                        '${payslip['working_days'] ?? 0}'),
                    _vDivider(),
                    _headerStat(
                        'Paid Days', '${payslip['paid_days'] ?? 0}'),
                    _vDivider(),
                    _headerStat(
                        'Absent', '${payslip['absent_days'] ?? 0}'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Earnings
          _SalarySection(
            title: 'Earnings',
            color: AppColors.success,
            icon: Icons.add_circle_rounded,
            items: [
              _Item('Basic Salary', payslip['basic_salary']),
              _Item('House Allowance', payslip['house_allowance']),
              _Item('Transport Allowance', payslip['transport_allowance']),
              _Item('Medical Allowance', payslip['medical_allowance']),
              _Item('Other Allowances', payslip['other_allowances']),
            ],
            total: payslip['gross_salary'],
            totalLabel: 'Gross Salary',
          ),

          const SizedBox(height: 12),

          // Deductions
          _SalarySection(
            title: 'Deductions',
            color: AppColors.error,
            icon: Icons.remove_circle_rounded,
            items: [
              _Item('Tax', payslip['tax_deduction']),
              _Item('Insurance', payslip['insurance_deduction']),
              _Item('Provident Fund', payslip['provident_fund']),
              _Item('Absent Deduction', payslip['absent_deduction']),
            ],
            total: payslip['total_deductions'],
            totalLabel: 'Total Deductions',
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      );

  Widget _vDivider() =>
      Container(height: 30, width: 1, color: Colors.white30);
}

class _Item {
  final String label;
  final dynamic value;
  const _Item(this.label, this.value);
}

class _SalarySection extends StatelessWidget {
  final String title, totalLabel;
  final Color color;
  final IconData icon;
  final List<_Item> items;
  final dynamic total;
  const _SalarySection({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
    required this.total,
    required this.totalLabel,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: color)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items
              .where((i) => (i.value as num? ?? 0) > 0)
              .map((i) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(i.label,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13))),
                        Text(
                          currency.format(i.value ?? 0),
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ],
                    ),
                  )),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(totalLabel,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Text(
                  currency.format(total ?? 0),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get color {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'paid':
        return AppColors.info;
      case 'processing':
        return AppColors.warning;
      default:
        return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
