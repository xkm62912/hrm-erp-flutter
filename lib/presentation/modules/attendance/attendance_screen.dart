// lib/presentation/modules/attendance/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/attendance_repository.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final attendanceAsync = ref.watch(todayAttendanceProvider);
    final monthlyAsync = ref.watch(monthlyAttendanceProvider(
      (month: today.month, year: today.year),
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Today's Clock Card ─────────────────────────────────────────
            attendanceAsync.when(
              loading: () => const _ClockCardSkeleton(),
              error: (e, _) => Text('Error: $e'),
              data: (record) => _ClockCard(record: record),
            ),

            const SizedBox(height: 24),

            // ── This Month Summary ─────────────────────────────────────────
            const Text('This Month',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            monthlyAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (records) => _MonthlySummary(records: records),
            ),

            const SizedBox(height: 24),

            // ── Calendar Heatmap ───────────────────────────────────────────
            const Text('Attendance Calendar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            monthlyAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (records) => _AttendanceCalendar(
                month: today.month,
                year: today.year,
                records: records,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Clock In/Out Card ────────────────────────────────────────────────────────
class _ClockCard extends ConsumerWidget {
  final AttendanceRecord? record;
  const _ClockCard({this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isCheckedIn = record?.checkIn != null && record?.checkOut == null;
    final isCompleted = record?.checkIn != null && record?.checkOut != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Date
          Text(
            DateFormat('EEEE, MMMM d, y').format(now),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),

          // Time
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, _) => Text(
              DateFormat('HH:mm:ss').format(DateTime.now()),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Check in / out times
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _timeChip(
                  'Check In',
                  record?.checkIn != null
                      ? DateFormat('HH:mm').format(record!.checkIn!)
                      : '--:--',
                  Icons.login_rounded),
              Container(height: 40, width: 1, color: Colors.white30),
              _timeChip(
                  'Check Out',
                  record?.checkOut != null
                      ? DateFormat('HH:mm').format(record!.checkOut!)
                      : '--:--',
                  Icons.logout_rounded),
              Container(height: 40, width: 1, color: Colors.white30),
              _timeChip(
                  'Work Hours',
                  record != null ? _formatHours(record!) : '0h 0m',
                  Icons.access_time_rounded),
            ],
          ),

          const SizedBox(height: 24),

          // Action Button
          if (!isCompleted)
            SizedBox(
              width: 180,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (isCheckedIn) {
                    await ref.read(attendanceActionProvider.notifier).checkOut();
                  } else {
                    await ref.read(attendanceActionProvider.notifier).checkIn();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCheckedIn ? Colors.red[400] : Colors.green[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(isCheckedIn
                    ? Icons.logout_rounded
                    : Icons.login_rounded),
                label: Text(
                  isCheckedIn ? 'Check Out' : 'Check In',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Day Completed',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, String time, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(time,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  String _formatHours(AttendanceRecord record) {
    if (record.checkIn == null) return '0h 0m';
    final end = record.checkOut ?? DateTime.now();
    final diff = end.difference(record.checkIn!);
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }
}

class _ClockCardSkeleton extends StatelessWidget {
  const _ClockCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

// ─── Monthly Summary ──────────────────────────────────────────────────────────
class _MonthlySummary extends StatelessWidget {
  final List<AttendanceRecord> records;
  const _MonthlySummary({required this.records});

  @override
  Widget build(BuildContext context) {
    final present = records.where((r) => r.status == 'present').length;
    final absent = records.where((r) => r.status == 'absent').length;
    final late = records.where((r) => r.status == 'late').length;
    final halfDay = records.where((r) => r.status == 'half_day').length;

    return Row(
      children: [
        _SummaryCard('Present', present.toString(), AppColors.success,
            Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _SummaryCard(
            'Absent', absent.toString(), AppColors.error, Icons.cancel_rounded),
        const SizedBox(width: 8),
        _SummaryCard(
            'Late', late.toString(), AppColors.warning, Icons.watch_later_rounded),
        const SizedBox(width: 8),
        _SummaryCard('Half Day', halfDay.toString(), AppColors.info,
            Icons.brightness_5_rounded),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            Text(label,
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Attendance Calendar Heatmap ──────────────────────────────────────────────
class _AttendanceCalendar extends StatelessWidget {
  final int month;
  final int year;
  final List<AttendanceRecord> records;

  const _AttendanceCalendar({
    required this.month,
    required this.year,
    required this.records,
  });

  Color _statusColor(String? status) {
    switch (status) {
      case 'present':
        return AppColors.success;
      case 'absent':
        return AppColors.error;
      case 'late':
        return AppColors.warning;
      case 'half_day':
        return AppColors.info;
      case 'holiday':
        return Colors.purple;
      default:
        return Colors.grey[200]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    final recordMap = {
      for (final r in records) DateFormat('yyyy-MM-dd').format(r.date): r
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: daysInMonth + startWeekday,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();

              final day = index - startWeekday + 1;
              final dateStr =
                  '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final record = recordMap[dateStr];
              final isToday = day == DateTime.now().day &&
                  month == DateTime.now().month &&
                  year == DateTime.now().year;

              return Container(
                decoration: BoxDecoration(
                  color: _statusColor(record?.status),
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                      color: record != null ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Legend
          Wrap(
            spacing: 12,
            children: [
              _legend(AppColors.success, 'Present'),
              _legend(AppColors.error, 'Absent'),
              _legend(AppColors.warning, 'Late'),
              _legend(AppColors.info, 'Half Day'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
