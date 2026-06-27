import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/all_providers.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final todayAsync = ref.watch(todayAttendanceProvider);
    final monthlyAsync = ref.watch(monthlyAttendanceProvider(AttendanceFilter(month: today.month, year: today.year)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayAttendanceProvider);
          ref.invalidate(monthlyAttendanceProvider(AttendanceFilter(month: today.month, year: today.year)));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clock Card
              todayAsync.when(
                loading: () => const _ClockSkeleton(),
                error: (e, _) => Text('Error: $e'),
                data: (record) => _ClockCard(record: record),
              ),
              const SizedBox(height: 24),

              // Monthly Summary
              const Text('This Month',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              monthlyAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (records) => _MonthlySummary(records: records),
              ),
              const SizedBox(height: 24),

              // Calendar
              const Text('Attendance Calendar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              monthlyAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (records) => _AttendanceCalendar(
                  month: today.month,
                  year: today.year,
                  records: records,
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Clock Card ────────────────────────────────────────────────────────────────
class _ClockCard extends ConsumerWidget {
  final Map<String, dynamic>? record;
  const _ClockCard({this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isCheckedIn = record?['check_in'] != null && record?['check_out'] == null;
    final isCompleted = record?['check_in'] != null && record?['check_out'] != null;
    final actionState = ref.watch(attendanceActionProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Text(DateFormat('EEEE, MMMM d, y').format(now),
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (_, __) => Text(
              DateFormat('HH:mm:ss').format(DateTime.now()),
              style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _timeInfo('Check In',
                record?['check_in'] != null
                  ? DateFormat('HH:mm').format(DateTime.parse(record!['check_in'] as String).toLocal())
                  : '--:--',
                Icons.login_rounded),
              Container(height: 36, width: 1, color: Colors.white30),
              _timeInfo('Check Out',
                record?['check_out'] != null
                  ? DateFormat('HH:mm').format(DateTime.parse(record!['check_out'] as String).toLocal())
                  : '--:--',
                Icons.logout_rounded),
              Container(height: 36, width: 1, color: Colors.white30),
              _timeInfo('Hours',
                record?['check_in'] != null
                  ? _calcHours(record!)
                  : '0h 0m',
                Icons.access_time_rounded),
            ],
          ),
          const SizedBox(height: 22),
          if (!isCompleted)
            SizedBox(
              width: 180, height: 48,
              child: ElevatedButton.icon(
                onPressed: actionState.isLoading ? null : () async {
                  if (isCheckedIn) {
                    await ref.read(attendanceActionProvider.notifier).checkOut();
                  } else {
                    await ref.read(attendanceActionProvider.notifier).checkIn();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCheckedIn ? Colors.red[400] : Colors.green[400],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: actionState.isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(isCheckedIn ? Icons.logout_rounded : Icons.login_rounded),
                label: Text(isCheckedIn ? 'Check Out' : 'Check In',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, color: Colors.green),
                SizedBox(width: 8),
                Text('Day Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _timeInfo(String label, String value, IconData icon) => Column(children: [
    Icon(icon, color: Colors.white60, size: 16),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
  ]);

  String _calcHours(Map<String, dynamic> r) {
    final checkIn = DateTime.parse(r['check_in'] as String);
    final checkOut = r['check_out'] != null ? DateTime.parse(r['check_out'] as String) : DateTime.now();
    final diff = checkOut.difference(checkIn);
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }
}

class _ClockSkeleton extends StatelessWidget {
  const _ClockSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    height: 260,
    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
  );
}

// ── Monthly Summary ───────────────────────────────────────────────────────────
class _MonthlySummary extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _MonthlySummary({required this.records});

  @override
  Widget build(BuildContext context) {
    final present = records.where((r) => r['status'] == 'present').length;
    final absent  = records.where((r) => r['status'] == 'absent').length;
    final late    = records.where((r) => r['status'] == 'late').length;
    final half    = records.where((r) => r['status'] == 'half_day').length;
    return Row(children: [
      _SummaryTile('Present', present, AppColors.success, Icons.check_circle_rounded),
      const SizedBox(width: 8),
      _SummaryTile('Absent',  absent,  AppColors.error,   Icons.cancel_rounded),
      const SizedBox(width: 8),
      _SummaryTile('Late',    late,    AppColors.warning,  Icons.watch_later_rounded),
      const SizedBox(width: 8),
      _SummaryTile('Half',    half,    AppColors.info,     Icons.brightness_5_rounded),
    ]);
  }
}

class _SummaryTile extends StatelessWidget {
  final String label; final int count; final Color color; final IconData icon;
  const _SummaryTile(this.label, this.count, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
      ]),
    ),
  );
}

// ── Calendar Heatmap ──────────────────────────────────────────────────────────
class _AttendanceCalendar extends StatelessWidget {
  final int month, year;
  final List<Map<String, dynamic>> records;
  const _AttendanceCalendar({required this.month, required this.year, required this.records});

  Color _color(String? s) {
    switch (s) {
      case 'present':  return AppColors.success;
      case 'absent':   return AppColors.error;
      case 'late':     return AppColors.warning;
      case 'half_day': return AppColors.info;
      case 'holiday':  return Colors.purple;
      default:         return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final recordMap = { for (final r in records) r['date'] as String: r };
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
          .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)))))
          .toList()),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemCount: daysInMonth + startWeekday,
          itemBuilder: (_, i) {
            if (i < startWeekday) return const SizedBox.shrink();
            final day = i - startWeekday + 1;
            final dateStr = '$year-${month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
            final record = recordMap[dateStr];
            final isToday = day == today.day && month == today.month && year == today.year;
            return Container(
              decoration: BoxDecoration(
                color: _color(record?['status'] as String?),
                shape: BoxShape.circle,
                border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
              ),
              child: Center(child: Text('$day', style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: record != null ? Colors.white : Colors.black54,
              ))),
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, children: [
          _legend(AppColors.success, 'Present'),
          _legend(AppColors.error, 'Absent'),
          _legend(AppColors.warning, 'Late'),
          _legend(AppColors.info, 'Half Day'),
        ]),
      ]),
    );
  }

  Widget _legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}
