import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../providers/providers.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today       = DateTime.now();
    final todayAsync  = ref.watch(todayAttendanceProvider);
    final monthAsync  = ref.watch(monthlyAttendanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayAttendanceProvider);
          ref.invalidate(monthlyAttendanceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Clock card
            todayAsync.when(
              loading: () => _skeleton(260),
              error: (e, _) => Text('$e'),
              data: (record) => _ClockCard(record: record, ref: ref),
            ),
            const SizedBox(height: 24),

            // Monthly summary
            const _STitle('This Month'),
            const SizedBox(height: 12),
            monthAsync.when(
              loading: () => _skeleton(60),
              error: (_, __) => const SizedBox.shrink(),
              data: (records) => _MonthlySummary(records: records),
            ),
            const SizedBox(height: 24),

            // Calendar
            const _STitle('Attendance Calendar'),
            const SizedBox(height: 12),
            monthAsync.when(
              loading: () => _skeleton(260),
              error: (_, __) => const SizedBox.shrink(),
              data: (records) => _Calendar(
                  month: today.month, year: today.year, records: records),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _ClockCard extends StatelessWidget {
  final Map<String, dynamic>? record;
  final WidgetRef ref;
  const _ClockCard({required this.record, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isIn  = record?['check_in'] != null && record?['check_out'] == null;
    final isDone= record?['check_in'] != null && record?['check_out'] != null;
    final action= ref.watch(attendanceActionProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Text(DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (_, __) => Text(
            DateFormat('HH:mm:ss').format(DateTime.now()),
            style: const TextStyle(color: Colors.white, fontSize: 40,
                fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _timeInfo('Check In',
              _fmt(record?['check_in'] as String?), Icons.login_rounded),
          Container(height: 36, width: 1, color: Colors.white30),
          _timeInfo('Check Out',
              _fmt(record?['check_out'] as String?), Icons.logout_rounded),
          Container(height: 36, width: 1, color: Colors.white30),
          _timeInfo('Hours', _hours(), Icons.access_time_rounded),
        ]),
        const SizedBox(height: 22),
        if (!isDone)
          SizedBox(
            width: 180, height: 48,
            child: ElevatedButton.icon(
              onPressed: action.isLoading ? null : () async {
                if (isIn) {
                  await ref.read(attendanceActionProvider.notifier).checkOut();
                } else {
                  await ref.read(attendanceActionProvider.notifier).checkIn();
                }
                ref.invalidate(todayAttendanceProvider);
                ref.invalidate(monthlyAttendanceProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isIn ? Colors.red.shade400 : Colors.green.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: action.isLoading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(isIn ? Icons.logout_rounded : Icons.login_rounded),
              label: Text(isIn ? 'Check Out' : 'Check In',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Day Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ]),
          ),
      ]),
    );
  }

  Widget _timeInfo(String label, String val, IconData icon) => Column(children: [
    Icon(icon, color: Colors.white60, size: 16),
    const SizedBox(height: 4),
    Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
  ]);

  String _fmt(String? iso) {
    if (iso == null) return '--:--';
    return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());
  }

  String _hours() {
    if (record?['check_in'] == null) return '0h 0m';
    final start = DateTime.parse(record!['check_in'] as String);
    final end   = record?['check_out'] != null
        ? DateTime.parse(record!['check_out'] as String) : DateTime.now();
    final diff  = end.difference(start);
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }
}

class _MonthlySummary extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _MonthlySummary({required this.records});
  @override
  Widget build(BuildContext context) {
    int present = 0, absent = 0, late = 0, half = 0;
    for (final r in records) {
      switch (r['status'] as String?) {
        case 'present':  present++; break;
        case 'absent':   absent++;  break;
        case 'late':     late++;    break;
        case 'half_day': half++;    break;
      }
    }
    return Row(children: [
      _tile('Present', present, AppColors.success, Icons.check_circle_rounded),
      const SizedBox(width: 8),
      _tile('Absent',  absent,  AppColors.error,   Icons.cancel_rounded),
      const SizedBox(width: 8),
      _tile('Late',    late,    AppColors.warning,  Icons.watch_later_rounded),
      const SizedBox(width: 8),
      _tile('Half',    half,    AppColors.info,     Icons.brightness_5_rounded),
    ]);
  }

  Widget _tile(String label, int count, Color color, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9)),
      ]),
    ),
  );
}

class _Calendar extends StatelessWidget {
  final int month, year;
  final List<Map<String, dynamic>> records;
  const _Calendar({required this.month, required this.year, required this.records});

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
    final first = DateTime(year, month, 1);
    final days  = DateTime(year, month + 1, 0).day;
    final start = first.weekday % 7;
    final map   = {for (final r in records) r['date'] as String: r};
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
            .map((d) => Expanded(child: Center(
                child: Text(d, style: const TextStyle(fontSize: 10, color: Colors.grey,
                    fontWeight: FontWeight.w600)))))
            .toList()),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemCount: days + start,
          itemBuilder: (_, i) {
            if (i < start) return const SizedBox.shrink();
            final day     = i - start + 1;
            final dateStr = '$year-${month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
            final rec     = map[dateStr];
            final isToday = day == today.day && month == today.month && year == today.year;
            return Container(
              decoration: BoxDecoration(
                color: _color(rec?['status'] as String?),
                shape: BoxShape.circle,
                border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
              ),
              child: Center(child: Text('$day', style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: rec != null ? Colors.white : Colors.black54,
              ))),
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 12, children: [
          _legend(AppColors.success, 'Present'),
          _legend(AppColors.error,   'Absent'),
          _legend(AppColors.warning, 'Late'),
          _legend(AppColors.info,    'Half Day'),
        ]),
      ]),
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}

class _STitle extends StatelessWidget {
  final String title;
  const _STitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
}

Widget _skeleton(double h) => Container(
    height: h,
    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)));
