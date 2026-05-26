import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/staffModel_310.dart';
import 'package:unipos/data/models/restaurant/db/attendance_model.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';

import 'package:unipos/util/restaurant/restaurant_auth_helper.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  // Track which staff is currently being toggled (to show loading state)
  String? _loadingStaffId;

  @override
  void initState() {
    super.initState();
    staffStore.loadStaff();
    attendanceStore.loadTodayRecords();
  }

  Future<bool> _verifyPin(StaffModel staff) async {
    final TextEditingController pinController = TextEditingController();
    bool _obscureText = true;
    bool _hasError = false;

    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Enter PIN for ${staff.firstName}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: pinController,
                  label: 'PIN',
                  hint: 'Enter PIN',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureText,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () => setDialogState(() => _obscureText = !_obscureText),
                  ),
                ),
                if (_hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Incorrect PIN',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade600),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (RestaurantAuthHelper.verifyPassword(pinController.text.trim(), staff.pinNo.trim())) {
                    Navigator.pop(context, true);
                  } else {
                    setDialogState(() {
                      _hasError = true;
                      pinController.clear();
                    });
                  }
                },
                child: Text('Verify', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    return result ?? false;
  }

  Future<void> _toggle(StaffModel staff) async {
    final isVerified = await _verifyPin(staff);
    if (!isVerified) return;

    final fullName = '${staff.firstName} ${staff.lastName}'.trim();
    setState(() => _loadingStaffId = staff.id);

    final open = attendanceStore.getActiveRecord(fullName);
    if (open != null) {
      await attendanceStore.clockOut(open.id);
      if (mounted) _showSnack('${staff.firstName} clocked out', Colors.orange.shade700);
    } else {
      final sessionId = await DayManagementService.getCurrentSessionId();
      await attendanceStore.clockIn(
        staffName: fullName,
        staffRole: staff.isCashier,
        sessionId: sessionId,
      );
      if (mounted) _showSnack('${staff.firstName} clocked in at ${_fmt(DateTime.now())}', Colors.green.shade700);
    }

    setState(() => _loadingStaffId = null);
  }

  Future<void> _toggleBreak(StaffModel staff) async {
    final isVerified = await _verifyPin(staff);
    if (!isVerified) return;

    final fullName = '${staff.firstName} ${staff.lastName}'.trim();
    setState(() => _loadingStaffId = staff.id);

    final open = attendanceStore.getActiveRecord(fullName);
    if (open != null) {
      if (open.isOnBreak) {
        await attendanceStore.endBreak(open.id);
        if (mounted) _showSnack('${staff.firstName} ended break', Colors.green.shade700);
      } else {
        await attendanceStore.startBreak(open.id);
        if (mounted) _showSnack('${staff.firstName} started break', Colors.blue.shade700);
      }
    }
    setState(() => _loadingStaffId = null);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Staff Attendance',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              staffStore.loadStaff();
              attendanceStore.loadTodayRecords();
            },
          ),
        ],
      ),
      body: Observer(builder: (_) {
        // Exclude the currently logged-in staff — their session IS their attendance
        final loggedInName = RestaurantSession.staffName?.toLowerCase().trim();
        final allStaff = staffStore.staff.where((s) {
          if (!s.isActive) return false;
          if (loggedInName == null) return true; // admin logged in — show all staff
          final fullName = '${s.firstName} ${s.lastName}'.trim().toLowerCase();
          return fullName != loggedInName;
        }).toList();

        if (allStaff.isEmpty) {
          return Center(
            child: Text('No staff found',
                style: GoogleFonts.poppins(color: Colors.grey.shade500)),
          );
        }

        // Summary row
        final inCount = allStaff.where((s) {
          final name = '${s.firstName} ${s.lastName}'.trim();
          return attendanceStore.getActiveRecord(name) != null;
        }).length;

        return Column(
          children: [
            // ── Summary bar ───────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryTile('Total Staff', '${allStaff.length}', Colors.white70),
                  _divider(),
                  _summaryTile('Clocked In', '$inCount', Colors.greenAccent.shade100),
                  _divider(),
                  _summaryTile('Not In', '${allStaff.length - inCount}', Colors.orange.shade200),
                ],
              ),
            ),

            // ── Staff list ────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: allStaff.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final staff = allStaff[i];
                  final fullName = '${staff.firstName} ${staff.lastName}'.trim();
                  final openRecord = attendanceStore.getActiveRecord(fullName);
                  final isIn = openRecord != null;
                  final isOnBreak = isIn && openRecord.isOnBreak;
                  final isLoading = _loadingStaffId == staff.id;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isOnBreak 
                            ? Colors.blue.shade200
                            : (isIn ? Colors.green.shade200 : Colors.grey.shade200),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isOnBreak 
                                ? Colors.blue.shade50
                                : (isIn ? Colors.green.shade50 : Colors.grey.shade100),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              staff.firstName.isNotEmpty
                                  ? staff.firstName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isOnBreak 
                                    ? Colors.blue.shade700
                                    : (isIn ? Colors.green.shade700 : Colors.grey.shade600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name + role + time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName,
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(staff.isCashier,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: Colors.grey.shade500)),
                              if (isIn)
                                Text(
                                  isOnBreak 
                                      ? 'On Break • Worked ${_liveDuration(openRecord)}'
                                      : 'In since ${openRecord.formattedClockIn}  •  ${_liveDuration(openRecord)}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: isOnBreak ? Colors.blue.shade700 : Colors.green.shade700),
                                ),
                            ],
                          ),
                        ),

                        // Action Buttons
                        isLoading
                            ? const SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                children: [
                                  if (isIn)
                                    GestureDetector(
                                      onTap: () => _toggleBreak(staff),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isOnBreak
                                              ? Colors.green.shade600
                                              : Colors.blue.shade600,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isOnBreak ? 'RESUME' : 'BREAK',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () => _toggle(staff),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isIn
                                            ? Colors.orange.shade600
                                            : Colors.green.shade600,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isIn ? 'OUT' : 'IN',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _summaryTile(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w800, color: valueColor)),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _divider() => Container(
        height: 32,
        width: 1,
        color: Colors.white.withOpacity(0.3),
      );

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _liveDuration(AttendanceModel record) {
    final now = DateTime.now();
    int activeMinutes = now.difference(record.clockIn).inMinutes - (record.breakTotalMinutes ?? 0);
    if (record.isOnBreak && record.breakStartTime != null) {
      activeMinutes -= now.difference(record.breakStartTime!).inMinutes;
    }
    
    // Prevent negative duration just in case
    if (activeMinutes < 0) activeMinutes = 0;
    
    final h = activeMinutes ~/ 60;
    final m = activeMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}

