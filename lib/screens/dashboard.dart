import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../providers/providers.dart';
import '../screens/login.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync  = ref.watch(dashboardStatsProvider);
    final trendAsync  = ref.watch(attendanceTrendProvider);
    final payrollAsync = ref.watch(payrollTrendProvider);
    final deptAsync   = ref.watch(deptDistributionProvider);
    final currency    = NumberFormat.compactCurrency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(attendanceTrendProvider);
          ref.invalidate(payrollTrendProvider);
          ref.invalidate(deptDistributionProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI Cards
            statsAsync.when(
              loading: () => _skeleton(120),
              error: (e, _) => Text('$e'),
              data: (s) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _kpiCard('Total Employees',   '${s['total_employees']}',    Icons.people_alt_rounded,    AppColors.primary),
                  _kpiCard('Present Today',     '${s['present_today']}',      Icons.how_to_reg_rounded,    AppColors.success),
                  _kpiCard('Pending Leaves',    '${s['pending_leaves']}',     Icons.event_busy_rounded,    AppColors.warning),
                  _kpiCard('Payroll (Month)',   currency.format(s['payroll_this_month']), Icons.payments_rounded, AppColors.payrollColor),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Attendance Trend
            const _SectionTitle('Attendance This Week'),
            const SizedBox(height: 12),
            trendAsync.when(
              loading: () => _skeleton(200),
              error: (_, __) => const SizedBox.shrink(),
              data: (trend) => _AttendanceChart(trend: trend),
            ),
            const SizedBox(height: 24),

            // Payroll Trend
            const _SectionTitle('Payroll Trend (6 Months)'),
            const SizedBox(height: 12),
            payrollAsync.when(
              loading: () => _skeleton(180),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) => _PayrollChart(data: data),
            ),
            const SizedBox(height: 24),

            // Dept Distribution
            const _SectionTitle('Headcount by Department'),
            const SizedBox(height: 12),
            deptAsync.when(
              loading: () => _skeleton(180),
              error: (_, __) => const SizedBox.shrink(),
              data: (depts) => _DeptChart(depts: depts),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
        ]),
        const Spacer(),
        Text(value, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(
            fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _skeleton(double h) => Container(
      height: h,
      decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16)));
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
}

class _AttendanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  const _AttendanceChart({required this.trend});
  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();
    final maxY = trend
        .map((t) => ((t['present'] as int? ?? 0) + (t['absent'] as int? ?? 0)).toDouble())
        .fold(1.0, (a, b) => a > b ? a : b) * 1.3;
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: BarChart(BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i >= trend.length) return const SizedBox.shrink();
                return Text(trend[i]['day'] as String,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
            ),
          ),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData:   FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(trend.length, (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: (trend[i]['present'] as int? ?? 0).toDouble(),
              color: AppColors.success, width: 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          BarChartRodData(toY: (trend[i]['absent'] as int? ?? 0).toDouble(),
              color: AppColors.error.withOpacity(0.6), width: 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
        ])),
      )),
    );
  }
}

class _PayrollChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _PayrollChart({required this.data});
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _empty('No payroll data yet');
    final spots = List.generate(data.length, (i) =>
        FlSpot(i.toDouble(), (data[i]['total_net'] as num? ?? 0).toDouble() / 1000));
    final maxY  = spots.map((s) => s.y).fold(1.0, (a, b) => a > b ? a : b) * 1.3;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: LineChart(LineChartData(
        maxY: maxY, minY: 0,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i >= data.length) return const SizedBox.shrink();
              final m = (data[i]['month'] as int? ?? 1) - 1;
              return Text(months[m], style: const TextStyle(fontSize: 9, color: AppColors.textSecondary));
            },
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 36,
            getTitlesWidget: (v, _) => Text('\$${v.toInt()}k',
                style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
          )),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData:   FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.payrollColor,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
              show: true, color: AppColors.payrollColor.withOpacity(0.1)),
        )],
      )),
    );
  }
}

class _DeptChart extends StatefulWidget {
  final List<Map<String, dynamic>> depts;
  const _DeptChart({required this.depts});
  @override
  State<_DeptChart> createState() => _DeptChartState();
}

class _DeptChartState extends State<_DeptChart> {
  int _touched = -1;
  static const _colors = [
    AppColors.primary, AppColors.accent, AppColors.hrColor,
    AppColors.warning, AppColors.crmColor, AppColors.info, AppColors.success,
  ];
  @override
  Widget build(BuildContext context) {
    if (widget.depts.isEmpty) return _empty('No data');
    final total = widget.depts.fold<int>(0, (s, d) => s + (d['count'] as int));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        SizedBox(
          height: 160, width: 160,
          child: PieChart(PieChartData(
            pieTouchData: PieTouchData(touchCallback: (_, r) =>
                setState(() => _touched = r?.touchedSection?.touchedSectionIndex ?? -1)),
            sections: List.generate(widget.depts.length, (i) {
              final count = widget.depts[i]['count'] as int;
              final pct   = (count / total * 100).toStringAsFixed(0);
              final isTouched = i == _touched;
              return PieChartSectionData(
                value: count.toDouble(),
                title: isTouched ? '$pct%' : '',
                radius: isTouched ? 72 : 62,
                color: _colors[i % _colors.length],
                titleStyle: const TextStyle(color: Colors.white,
                    fontSize: 11, fontWeight: FontWeight.bold),
              );
            }),
            centerSpaceRadius: 32,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            widget.depts.length > 6 ? 6 : widget.depts.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: _colors[i % _colors.length], shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(child: Text(widget.depts[i]['department'] as String,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis)),
                Text('${widget.depts[i]['count']}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        )),
      ]),
    );
  }
}

Widget _empty(String msg) => Container(
    height: 80, alignment: Alignment.center,
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border)),
    child: Text(msg, style: const TextStyle(color: AppColors.textHint)));
