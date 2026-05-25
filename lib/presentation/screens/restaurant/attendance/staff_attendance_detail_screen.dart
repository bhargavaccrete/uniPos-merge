import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/attendance_model.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';
import 'package:uuid/uuid.dart';

class StaffAttendanceDetailScreen extends StatefulWidget {
  final String staffName;
  final String staffRole;
  final DateTime from;
  final DateTime to;
  final List<AttendanceModel> initialRecords;

  const StaffAttendanceDetailScreen({
    super.key,
    required this.staffName,
    required this.staffRole,
    required this.from,
    required this.to,
    required this.initialRecords,
  });

  @override
  State<StaffAttendanceDetailScreen> createState() => _StaffAttendanceDetailScreenState();
}

class _StaffAttendanceDetailScreenState extends State<StaffAttendanceDetailScreen> {
  late List<AttendanceModel> records;

  @override
  void initState() {
    super.initState();
    records = List.from(widget.initialRecords);
  }

  void _refreshRecords() async {
    final result = await attendanceStore.getRecordsBetweenDates(
      widget.from,
      widget.to,
    );
    final filteredResult = result.where((r) => r.staffName == widget.staffName).toList();
    setState(() {
      records = filteredResult;
    });
  }

  Future<void> _showAddShiftDialog(DateTime day) async {
    TimeOfDay inTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay outTime = const TimeOfDay(hour: 17, minute: 0);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final hInset = !AppResponsive.isMobile(ctx)
              ? ((AppResponsive.screenWidth(ctx) - AppResponsive.dialogWidth(ctx)) / 2).clamp(40.0, 200.0)
              : 24.0;
          return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
          title: Text('Add Missing Shift\n${_fullDayLabel(day)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Clock In'),
                subtitle: Text('${inTime.hour.toString().padLeft(2, '0')}:${inTime.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.access_time, size: 18),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: inTime);
                  if (t != null) setState(() => inTime = t);
                },
              ),
              ListTile(
                title: const Text('Clock Out'),
                subtitle: Text('${outTime.hour.toString().padLeft(2, '0')}:${outTime.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.access_time, size: 18),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: outTime);
                  if (t != null) setState(() => outTime = t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final clockIn = DateTime(day.year, day.month, day.day, inTime.hour, inTime.minute);                DateTime clockOut = DateTime(day.year, day.month, day.day, outTime.hour, outTime.minute);
                
                if (clockOut.isBefore(clockIn)) {
                  clockOut = clockOut.add(const Duration(days: 1)); // Overnight shift
                }

                final record = AttendanceModel(
                  id: const Uuid().v4(),
                  staffName: widget.staffName,
                  staffRole: widget.staffRole,
                  clockIn: clockIn,
                  clockOut: clockOut,
                  totalMinutes: clockOut.difference(clockIn).inMinutes,
                  date: '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                );

                await attendanceStore.addRecord(record);
                Navigator.pop(ctx);
                _refreshRecords();
              },
              child: Text('Add Shift', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
        },
      ),
    );
  }

  Future<void> _showEditDialog(AttendanceModel record) async {
    TimeOfDay? newInTime = TimeOfDay.fromDateTime(record.clockIn);
    TimeOfDay? newOutTime = record.clockOut != null ? TimeOfDay.fromDateTime(record.clockOut!) : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final hInset = !AppResponsive.isMobile(ctx)
              ? ((AppResponsive.screenWidth(ctx) - AppResponsive.dialogWidth(ctx)) / 2).clamp(40.0, 200.0)
              : 24.0;
          return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
          title: Text('Edit Timesheet', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Clock In'),
                subtitle: Text('${newInTime!.hour.toString().padLeft(2, '0')}:${newInTime!.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: newInTime!);
                  if (t != null) setState(() => newInTime = t);
                },
              ),
              ListTile(
                title: const Text('Clock Out'),
                subtitle: Text(newOutTime == null ? 'Not Clocked Out' : '${newOutTime!.hour.toString().padLeft(2, '0')}:${newOutTime!.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: newOutTime ?? TimeOfDay.now());
                  if (t != null) setState(() => newOutTime = t);
                },
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton.icon(
              onPressed: () async {
                final deleteHInset = !AppResponsive.isMobile(context)
                    ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
                    : 24.0;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    insetPadding: EdgeInsets.symmetric(horizontal: deleteHInset, vertical: 24),
                    title: const Text('Delete Record?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await attendanceStore.deleteRecord(record.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _refreshRecords();
                }
              },
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final baseDate = record.clockIn;
                    final newClockIn = DateTime(baseDate.year, baseDate.month, baseDate.day, newInTime!.hour, newInTime!.minute);
                    
                    DateTime? newClockOut;
                    if (newOutTime != null) {
                      newClockOut = DateTime(baseDate.year, baseDate.month, baseDate.day, newOutTime!.hour, newOutTime!.minute);
                      // Handle overnight shifts if outTime is earlier than inTime
                      if (newClockOut.isBefore(newClockIn)) {
                        newClockOut = newClockOut.add(const Duration(days: 1));
                      }
                    }

                    await attendanceStore.updateRecord(
                      recordId: record.id,
                      newClockIn: newClockIn,
                      newClockOut: newClockOut,
                    );
                    
                    Navigator.pop(ctx);
                    _refreshRecords();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        );
        },
      ),
    );
  }

  List<DateTime> get _days {
    final days = <DateTime>[];
    var d = widget.from;
    
    final now = DateTime.now();
    var effectiveTo = widget.to;
    if (effectiveTo.isAfter(now)) {
      effectiveTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
    
    if (widget.from.isAfter(effectiveTo)) return [];

    while (!d.isAfter(effectiveTo)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    return days.reversed.toList();
  }

  List<AttendanceModel> _dayRecords(DateTime day) {
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return records.where((r) => r.date == key).toList();
  }

  int get _presentCount => _days.where((d) => _dayRecords(d).isNotEmpty).length;
  int get _absentCount => _days.length - _presentCount;
  int get _totalMinutes {
    final now = DateTime.now();
    return records.fold(0, (s, r) {
      if (r.totalMinutes != null) return s + r.totalMinutes!;
      if (!r.isOpen) return s;
      final gross = now.difference(r.clockIn).inMinutes;
      final breaks = (r.breakTotalMinutes ?? 0) +
          (r.isOnBreak && r.breakStartTime != null
              ? now.difference(r.breakStartTime!).inMinutes
              : 0);
      final active = gross - breaks;
      return s + (active < 0 ? 0 : active);
    });
  }

  String _fmtMins(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fullDayLabel(DateTime d) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.staffName,
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.staffRole,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Summary strip ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                _summaryTile('$_presentCount', 'Days Present', Colors.green.shade600, Icons.check_circle_outline),
                _vDivider(),
                _summaryTile('$_absentCount', 'Days Absent', _absentCount > 0 ? Colors.red.shade400 : Colors.grey.shade400, Icons.cancel_outlined),
                _vDivider(),
                _summaryTile(_fmtMins(_totalMinutes), 'Total Hours', Colors.blue.shade600, Icons.timer_outlined),
              ],
            ),
          ),

          // ── Period label ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.date_range, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  '${widget.from.day}/${widget.from.month}/${widget.from.year}  –  ${widget.to.day}/${widget.to.month}/${widget.to.year}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Text('${days.length} days', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Day-wise list ─────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final day = days[i];
                final dayRecs = _dayRecords(day);
                final isPresent = dayRecs.isNotEmpty;
                final today = _isToday(day);

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: today ? AppColors.primary.withOpacity(0.5) : isPresent ? Colors.green.shade200 : Colors.grey.shade200,
                      width: today ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isPresent ? Colors.green.shade50 : Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: today ? AppColors.primary : isPresent ? Colors.green.shade600 : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${day.day}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: isPresent || today ? Colors.white : Colors.grey.shade600)),
                                  Text(_monthShort(day.month), style: GoogleFonts.poppins(fontSize: 9, color: isPresent || today ? Colors.white70 : Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_fullDayLabel(day), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: today ? AppColors.primary : Colors.grey.shade800)),
                                  if (today) Text('Today', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.primary)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: isPresent ? Colors.green.shade600 : Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                              child: Text(isPresent ? 'Present' : 'Absent', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: isPresent ? Colors.white : Colors.red.shade700)),
                            ),
                            if (RestaurantSession.isAdmin)
                              IconButton(
                                icon: Icon(Icons.add_circle, color: AppColors.primary, size: 22),
                                onPressed: () => _showAddShiftDialog(day),
                              ),
                          ],
                        ),
                      ),
                      if (isPresent)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          child: Column(
                            children: dayRecs.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final r = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(top: idx == 0 ? 0 : 8),
                                child: Row(
                                  children: [
                                    if (dayRecs.length > 1)
                                      Container(
                                        width: 20, height: 20,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                                        child: Center(child: Text('${idx + 1}', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700))),
                                      ),
                                    Icon(Icons.login, size: 14, color: Colors.green.shade600),
                                    const SizedBox(width: 4),
                                    Text(_fmtTime(r.clockIn), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('→', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400)),
                                    ),
                                    Icon(Icons.logout, size: 14, color: r.isOpen ? Colors.orange.shade600 : Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(r.formattedClockOut, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: r.isOpen ? Colors.orange.shade700 : Colors.grey.shade700)),
                                    const Spacer(),
                                    if (RestaurantSession.isAdmin)
                                      IconButton(
                                        icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade600),
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                        onPressed: () => _showEditDialog(r),
                                      ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: r.isOpen ? Colors.orange.shade50 : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: r.isOpen ? Colors.orange.shade200 : Colors.blue.shade200),
                                      ),
                                      child: Text(_openShiftLabel(r), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: r.isOpen ? Colors.orange.shade800 : Colors.blue.shade700)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 16, color: Colors.grey.shade400),
                              const SizedBox(width: 6),
                              Text('No attendance recorded', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400)),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _openShiftLabel(AttendanceModel r) {
    if (!r.isOpen) return r.formattedDuration;
    final now = DateTime.now();
    // Same day → simple "Still In"
    if (now.day == r.clockIn.day && now.month == r.clockIn.month && now.year == r.clockIn.year) {
      return 'Still In';
    }
    // Crossed midnight — show date range e.g. "Still In\nApr 21→22"
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'Still In\n${months[r.clockIn.month - 1]} ${r.clockIn.day}→${now.day}';
  }

  Widget _summaryTile(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 48, color: Colors.grey.shade200);

  String _monthShort(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }
}
