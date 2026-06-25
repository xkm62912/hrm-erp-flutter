import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/all_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final trendAsync = ref.watch(attendanceTrendProvider);
    final payrollTrendAsync = ref.watch(payrollTrendProvider);
    final deptAsync = ref.watch(departmentDistributionProvider);
    final roleAsync = ref.watch(userRoleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(attendanceTrendProvider);
          ref.invalidate(payrollTrendProvider);
          ref.invalidate(departmentDistributionProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Greeting ────────────────────────────────────────────────
              _GreetingHeader(roleAsync: roleAsync),
              const SizedBox(height: 20),

              // ── KPI Cards ────────────────────────────────────────────────
              statsAsync.when(
                loading: () => _KpiSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (s) => _KpiGrid(stats: s),
              ),

              const SizedBox(height: 24),

              // ── Quick Actions ────────────────────────────────────────────
              const _QuickActions(),
              const SizedBox(height: 24),

              // ── Attendance Trend Chart ────────────────────────────────────
              const _SectionTitle('Attendance This Week'),
              const SizedBox(height: 12),
              trendAsync.when(
                loading: () => _ChartSkeleton(height: 220),
                error: (_, __) => const SizedBox.shrink(),
                data: (trend) => _AttendanceBarChart(trend: trend),
              ),

              const SizedBox(height: 24),

              // ── Payroll Trend ────────────────────────────────────────────
              const _SectionTitle('Payroll (Last 6 Months)'),
              const SizedBox(height: 12),
              payrollTrendAsync.when(
                loading: () => _ChartSkeleton(height: 200),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) => _PayrollLineChart(data: data),
              ),

              const SizedBox(height: 24),

              // ── Department Distribution ───────────────────────────────────
              const _SectionTitle('Headcount by Department'),
              const SizedBox(height: 12),
              deptAsync.when(
                loading: () => _ChartSkeleton(height: 200),
                error: (_, __) => const SizedBox.shrink(),
                data: (depts) => _DepartmentPieChart(depts: depts),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Greeting ─────────────────────────────────────────────────────────────────
class _GreetingHeader extends StatelessWidget {
  final AsyncValue<String?> roleAsync;
  const _GreetingHeader({required this.roleAsync});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const Text('Welcome back 👋',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        roleAsync.maybeWhen(
          data: (role) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (role ?? 'employee').toUpperCase(),
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── KPI Grid ─────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _KpiGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(symbol: '\$');
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _KpiCard(
          label: 'Total Employees',
          value: stats['total_employees'].toString(),
          icon: Icons.people_alt_rounded,
          color: AppColors.primary,
          trend: '+3 this month',
        ),
        _KpiCard(
          label: 'Present Today',
          value: stats['present_today'].toString(),
          icon: Icons.how_to_reg_rounded,
          color: AppColors.success,
          trend: '82% attendance',
        ),
        _KpiCard(
          label: 'Pending Leaves',
          value: stats['pending_leaves'].toString(),
          icon: Icons.event_busy_rounded,
          color: AppColors.warning,
          trend: 'Awaiting approval',
        ),
        _KpiCard(
          label: 'Payroll (Month)',
          value: currency.format(stats['payroll_this_month'] ?? 0),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.payrollColor,
          trend: 'Approved',
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value, trend;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.trend});

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.trending_up_rounded, color: color, size: 16),
            ],
          ),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          Text(trend,
              style: TextStyle(fontSize: 10, color: color),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action('Add Employee', Icons.person_add_rounded, AppColors.primary,
          '/employees/add'),
      _Action('Apply Leave', Icons.event_note_rounded, AppColors.leaveColor,
          '/leave/request'),
      _Action('Run Payroll', Icons.play_circle_rounded, AppColors.payrollColor,
          '/payroll/run'),
      _Action('CRM', Icons.handshake_rounded, AppColors.crmColor, '/crm'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Quick Actions'),
        const SizedBox(height: 12),
        Row(
          children: actions
              .map((a) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _QuickActionBtn(action: a),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _Action {
  final String label, path;
  final IconData icon;
  final Color color;
  const _Action(this.label, this.icon, this.color, this.path);
}

class _QuickActionBtn extends StatelessWidget {
  final _Action action;
  const _QuickActionBtn({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(action.path),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: action.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: action.color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(action.icon, color: action.color, size: 26),
            const SizedBox(height: 6),
            Text(action.label,
                style: TextStyle(
                    fontSize: 10,
                    color: action.color,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2),
          ],
        ),
      ),
    );
  }
}

// ─── Attendance Bar Chart ─────────────────────────────────────────────────────
class _AttendanceBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  const _AttendanceBarChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (trend
                      .map((t) => ((t['present'] as int?) ?? 0).toDouble())
                      .reduce((a, b) => a > b ? a : b) *
                  1.3)
              .ceilToDouble(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final d = trend[groupIndex];
                return BarTooltipItem(
                  '${d['day']}\nPresent: ${d['present']}\nAbsent: ${d['absent']}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= trend.length) return const SizedBox.shrink();
                  return Text(trend[i]['day'] as String,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary));
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(trend.length, (i) {
            final present = ((trend[i]['present'] as int?) ?? 0).toDouble();
            final absent = ((trend[i]['absent'] as int?) ?? 0).toDouble();
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                  toY: present,
                  color: AppColors.success,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
              BarChartRodData(
                  toY: absent,
                  color: AppColors.error.withOpacity(0.6),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ]);
          }),
        ),
      ),
    );
  }
}

// ─── Payroll Line Chart ───────────────────────────────────────────────────────
class _PayrollLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _PayrollLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _emptyChart('No payroll data yet');
    }

    final spots = List.generate(data.length, (i) {
      final net = (data[i]['total_net'] as num? ?? 0).toDouble();
      return FlSpot(i.toDouble(), net / 1000); // in thousands
    });

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.3;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          maxY: maxY,
          minY: 0,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                      '\$${(s.y * 1000).toStringAsFixed(0)}',
                      const TextStyle(color: Colors.white, fontSize: 12)))
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (v, _) => Text('\$${v.toInt()}k',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= data.length) return const SizedBox.shrink();
                  final monthNames = [
                    'Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'
                  ];
                  final month = (data[i]['month'] as int? ?? 1) - 1;
                  return Text(monthNames[month],
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary));
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.payrollColor,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.payrollColor.withOpacity(0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Department Pie Chart ─────────────────────────────────────────────────────
class _DepartmentPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> depts;
  const _DepartmentPieChart({required this.depts});

  @override
  State<_DepartmentPieChart> createState() => _DepartmentPieChartState();
}

class _DepartmentPieChartState extends State<_DepartmentPieChart> {
  int _touched = -1;

  static const _colors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.hrColor,
    AppColors.warning,
    AppColors.crmColor,
    AppColors.info,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.depts.isEmpty) return _emptyChart('No department data');

    final total =
        widget.depts.fold<int>(0, (s, d) => s + (d['count'] as int));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Pie
          SizedBox(
            height: 180,
            width: 180,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      _touched = response?.touchedSection?.touchedSectionIndex ?? -1;
                    });
                  },
                ),
                sections: List.generate(widget.depts.length, (i) {
                  final d = widget.depts[i];
                  final count = d['count'] as int;
                  final pct = (count / total * 100).toStringAsFixed(1);
                  final isTouched = i == _touched;
                  return PieChartSectionData(
                    value: count.toDouble(),
                    title: isTouched ? '$pct%' : '',
                    radius: isTouched ? 80 : 70,
                    color: _colors[i % _colors.length],
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  );
                }),
                centerSpaceRadius: 36,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                widget.depts.length > 6 ? 6 : widget.depts.length,
                (i) {
                  final d = widget.depts[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _colors[i % _colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${d['department']}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${d['count']}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary));
  }
}

Widget _emptyChart(String msg) => Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(msg,
          style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
    );

class _KpiSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: List.generate(
            4,
            (_) => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                )),
      );
}

class _ChartSkeleton extends StatelessWidget {
  final double height;
  const _ChartSkeleton({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
      );
}
