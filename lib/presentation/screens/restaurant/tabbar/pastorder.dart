import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/util/color.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../util/restaurant_print_helper.dart';
import 'orderDetails.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
class Pastorder extends StatefulWidget {
  const Pastorder({super.key});

  @override
  State<Pastorder> createState() => _PastorderState();
}

class _PastorderState extends State<Pastorder> {
  // Filters
  String _orderType = 'All';
  final List<String> _orderTypeOptions = const ['All', 'Take Away', 'Delivery', 'Dine In'];
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {})); // live filter
    pastOrderStore.loadPastOrders(); // Load past orders from store
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _money(num? v) => '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((v ?? 0).toDouble())}';

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year;
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy • $hh:%02d'.replaceFirst('%02d', min);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool _withinRange(DateTime? dt) {
    if (dt == null) return true;
    if (_dateRange == null) return true;
    final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, 0, 0, 0);
    final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
    return (dt.isAfter(start) || dt.isAtSameMomentAs(start)) &&
        (dt.isBefore(end) || dt.isAtSameMomentAs(end));
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
      builder: (ctx, child) {
        // color theming to match your primary color
        final scheme = Theme.of(ctx).colorScheme.copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        );
        return Theme(data: Theme.of(ctx).copyWith(colorScheme: scheme), child: child!);
      },
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDEE1E6)),
    );

    return Column(
      children: [
        // 🔽 Filters row (Order Type, Search, Date Range) — no AppBar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              // Order Type
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _orderType,
                  items: _orderTypeOptions
                      .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e, style: GoogleFonts.poppins(fontSize: 14)),
                  ))
                      .toList(),
                  onChanged: (val) => setState(() => _orderType = val ?? 'All'),
                  decoration: InputDecoration(
                    labelText: 'Order Type',
                    labelStyle: GoogleFonts.poppins(fontSize: 12),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Search
              Expanded(
                flex: 1,
                child: AppTextField(
                  controller: _searchCtrl,
                  hint: 'Search name / KOT / bill no',
                  icon: Icons.search,
                ),
              ),
            ],
          ),
        ),

        // 🔽 Date range row
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDEE1E6)),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateRange == null
                                ? 'Date range'
                                : '${_fmtDate(_dateRange!.start)} — ${_fmtDate(_dateRange!.end)}',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_dateRange != null)
                          InkWell(
                            onTap: () => setState(() => _dateRange = null),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.close_rounded, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Quick "Today" shortcut (optional, handy)
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final now = DateTime.now();
                    final start = DateTime(now.year, now.month, now.day);
                    final end = DateTime(now.year, now.month, now.day);
                    setState(() => _dateRange = DateTimeRange(start: start, end: end));
                  },
                  icon: const Icon(Icons.today_outlined, size: 18),
                  label: Text('Today', style: GoogleFonts.poppins(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDEE1E6)),
                    foregroundColor: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 🔽 Orders list
        Expanded(
          child: Observer(
            builder: (_) {
              final all = pastOrderStore.pastOrders.toList();

              if (pastOrderStore.isLoading && all.isEmpty) {
                return Center(child: CircularProgressIndicator());
              }

              if (all.isEmpty) {
                return Center(child: Text('No past orders found', style: GoogleFonts.poppins()));
              }

              // newest first
              all.sort((a, b) => (b.orderAt ?? DateTime(2000)).compareTo(a.orderAt ?? DateTime(2000)));


              final q = _searchCtrl.text.trim().toLowerCase();
              final filtered = all.where((o) {
                final typeOk = _orderType == 'All' ||
                    (o.orderType ?? '').toLowerCase() == _orderType.toLowerCase();
                final dateOk = _withinRange(o.orderAt);
                final kotStr = o.kotNumbers.map((k) => k.toString()).join(' ');
                final billStr = o.billNumber != null ? 'inv${o.billNumber} ${o.billNumber}' : '';
                final text = [
                  o.customerName,
                  kotStr,
                  billStr,
                  o.orderType,
                  o.paymentmode,
                  o.tableNo,
                ].where((e) => e != null && e!.isNotEmpty).map((e) => e!.toLowerCase()).join(' ');
                final searchOk = q.isEmpty || text.contains(q);
                return typeOk && dateOk && searchOk;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No matching orders for selected filters',
                    style: GoogleFonts.poppins(),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final o = filtered[index];
                  final isRefunded = o.isRefunded == true;
                  final isVoided = (o.orderStatus ?? '').contains('VOID');
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => Orderdetails(Order: o)),
                      ).then((_) => setState(() {}));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: isVoided
                              ? Colors.grey.shade400
                              : const Color(0xFFDEE1E6),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row — KOT chips + bill number + date
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Text('KOT:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                                    ...o.getKotNumbers().map((kotNum) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade300),
                                      ),
                                      child: Text('#$kotNum',
                                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                                    )),
                                    if (o.billNumber != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.green.shade300),
                                        ),
                                        child: Text('INV${o.billNumber}',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                                      ),
                                  ],
                                ),
                              ),
                              Text(_fmtDateTime(o.orderAt),
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Name + total + reprint button
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (o.customerName?.isNotEmpty == true) ? o.customerName! : 'Guest',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_money(o.totalPrice),
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              // Reprint button
                              if (!isVoided)
                                InkWell(
                                  onTap: () async {
                                    try {
                                      await RestaurantPrintHelper.printPastOrder(
                                        context: context,
                                        pastOrder: o,
                                      );
                                    } catch (e) {
                                      // handled inside helper
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.print_outlined, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text('Print', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Type + table + payment + status badges
                          Row(
                            children: [
                              Text(o.orderType ?? '',
                                  style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12)),
                              if ((o.tableNo ?? '').isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text('• Table ${o.tableNo}',
                                    style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12)),
                              ],
                              const Spacer(),
                              if ((o.paymentmode ?? '').isNotEmpty)
                                Text(o.paymentmode!,
                                    style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12)),
                              if (isVoided) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Voided',
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                                ),
                              ] else if (isRefunded) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Refunded',
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade700)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}


