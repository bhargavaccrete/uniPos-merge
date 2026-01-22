import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/util/color.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import 'orderDetails.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
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
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name / KOT / phone',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    isDense: true,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
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
                final text = [
                  o.customerName,
                  o.kotNumber?.toString(),
                  // o.customerPhone,
                  o.orderType,
                  o.paymentmode
                ].where((e) => e != null).map((e) => e!.toLowerCase()).join(' ');
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
                        border: Border.all(color: const Color(0xFFDEE1E6)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Text('KOT: ', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                    ...o.getKotNumbers().map((kotNum) => Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade300),
                                      ),
                                      child: Text(
                                        '#$kotNum',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                              Text(_fmtDateTime(o.orderAt),
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Name + total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Type + payment + refunded
                          Row(
                            children: [
                              Text(o.orderType ?? '',
                                  style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12)),
                              const Spacer(),
                              if ((o.paymentmode ?? '').isNotEmpty)
                                Text(o.paymentmode!,
                                    style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12)),
                              if (isRefunded) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Refunded',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11, color: Colors.red.shade700)),
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



/*
import 'package:flutter/material.dart';
import 'package:BillBerry/constant/color.dart';
import 'package:BillBerry/model/db/pastordermodel_13.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';

import 'orderDetails.dart';

class Pastorder extends StatefulWidget {
  const Pastorder({super.key});

  @override
  State<Pastorder> createState() => _PastorderState();
}

class _PastorderState extends State<Pastorder> {

  late Future<List<pastOrderModel>> _PastOrderFuture;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  _PastOrderFuture = HivePastOrder.getAllPastOrderModel();
  }


  DateTime? _fromDate;
  DateTime? _toDate;

  // celender
  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
      });
    }
  }

  String dropDownValue = 'All';

  List<String> dropdownItems = [
    'All',
    'Take Away',
    'Delivery',
    'Dine In',
  ];

  final outr = OutlineInputBorder(borderRadius: BorderRadius.circular(12));

  TextEditingController searchbar = TextEditingController();



  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
        body: Container(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  'Order Type',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 18),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  width: width * 0.4,
                  height: height * 0.06,
                  color: Colors.white,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton(
                        value: dropDownValue,
                        items: dropdownItems.map((String dropdownItems) {
                          return DropdownMenuItem(
                            value: dropdownItems,
                            child: Text(
                              dropdownItems,
                              style: GoogleFonts.poppins(fontSize: 16),
                              textScaler: TextScaler.linear(1),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            dropDownValue = newValue!;
                          });
                        }),
                  ),
                )
              ]),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: width * 0.6,
                    height: height * 0.06,
                    child: TextFormField(
                      decoration: InputDecoration(
                        hintText: 'Search Here',
                        hintStyle:
                            GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.primary,
                          size: 30,
                        ),
                        focusedBorder: outr,
                        enabledBorder: outr,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  // date picker
                  InkWell(
                    onTap: () {
                      _pickDate(context);
                    },
                    child: Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(5),
                        width: width * 0.3,
                        height: height * 0.06,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade800),
                            // color: Colors.red,
                            borderRadius: BorderRadius.circular(5)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fromDate == null
                                  ? ' DD/MM/YYYY'
                                  : '${_fromDate!.year}/${_fromDate!.month}/${_fromDate!.day}',
                              textAlign: TextAlign.center,
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ],
                        )),
                  ),
                ],
              ),
              SizedBox(
                height: 20,
              ),

              // Expanded(
              //     child:FutureBuilder<List<pastOrderModel>>(
              //         future: _PastOrderFuture,
              //         builder: (context, snapshot){
              //           if(snapshot.connectionState == ConnectionState.waiting){
              //             return Center(child: CircularProgressIndicator(),);
              //           }
              //           if(snapshot.hasError){
              //             return Center(child: Text('Error: ${snapshot.error}'),);
              //           }
              //           if(!snapshot.hasData || snapshot.data!.isEmpty){
              //             return  Container(child: Image.asset('assets/images/paste.jpg'));
              //           }
              //
              //           final allpastorder = snapshot.data!;
              //
              //           allpastorder.sort((a, b) => b.orderAt!.compareTo(a.orderAt!),);
              //
              //           final fillterProduct = dropDownValue == 'All'
              //           ?allpastorder
              //               :allpastorder
              //           .where((order)=> order.orderType == dropDownValue)
              //           .toList();
              //
              //           if (fillterProduct.isEmpty) {
              //             return Center(child: Text('No orders of type "$dropDownValue" found.'));
              //           }
              //
              //           return Container(
              //             // color: Colors.red,
              //             width: width * 0.7,
              //             height:  height * 0.5,
              //             child: ListView.builder(
              //
              //               // itemExtent: 2,
              //               padding: EdgeInsets.all(10),
              //               itemCount: fillterProduct.length,
              //             itemBuilder: (context, index){
              //               final past = fillterProduct[index];
              //               return InkWell(
              //                 onTap: (){
              //                   Navigator.push(context, MaterialPageRoute(builder: (context)=> Orderdetails(Order: past),),)
              //                       .then((_){
              //                         setState(() {
              //
              //                         });
              //                   });
              //                 },
              //                 child: Container(
              //                   margin: const EdgeInsets.only(bottom: 12.0),
              //                   width: width *0.6,
              //                   height: height * 0.15,
              //                   decoration: BoxDecoration(
              //                     border: Border.all(color: Colors.black,width: 2)
              //                   ),
              //                   padding: EdgeInsets.all(10),
              //                   child: Column(
              //                     crossAxisAlignment: CrossAxisAlignment.start,
              //                     children: [
              //                     Row(
              //                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //                       children: [
              //                         Text(past.kotNumber.toString(),style: GoogleFonts.poppins(fontSize: 10),),
              //                         Text(past.orderAt.toString(),style: GoogleFonts.poppins(fontSize: 10),),
              //                       ],
              //                     ) ,
              //                       SizedBox(height: 10,),
              //                       Row(
              //                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //                       children: [
              //                         Text(" Rs ${past.totalPrice.toString()}",style: GoogleFonts.poppins(fontSize: 10),),
              //
              //                         Text(past.orderType.toString(),style: GoogleFonts.poppins(fontSize: 10),),
              //                       ],
              //                     ),   SizedBox(height: 10,),
              //                       Row(
              //                         mainAxisAlignment:MainAxisAlignment.spaceBetween,
              //                         children: [
              //                           Text(past.customerName,style: GoogleFonts.poppins(fontSize: 10),),
              //
              //                           if(past.paymentmode != null && past.paymentmode!.isNotEmpty)
              //
              //                           Text(
              //                             past.paymentmode.toString(),
              //                             style: GoogleFonts.poppins(fontSize: 10),
              //                           ),
              //
              //                       ],
              //                       ),
              //
              //                      
              //                     ],
              //                   ),
              //                 ),
              //               );
              //             },
              //             ),
              //           );
              //         }) )




              Expanded(
                  child:ValueListenableBuilder(valueListenable: Hive.box<pastOrderModel>('pastorderBox').listenable(),

                      builder: (context, box, _){

                  final   allorder = box.values.toList();



                        if(allorder.isEmpty){
                          return  Container(child: Image.asset('assets/images/paste.jpg'));
                        }



                  allorder.sort((a, b) => b.orderAt!.compareTo(a.orderAt!),);

                        final fillterProduct = dropDownValue == 'All'
                            ?allorder
                            :allorder
                            .where((order)=> order.orderType == dropDownValue)
                            .toList();

                        if (fillterProduct.isEmpty) {
                          return Center(child: Text('No orders of type "$dropDownValue" found.'));
                        }

                        return Container(
                          // color: Colors.red,
                          width: width * 0.7,
                          height:  height * 0.5,
                          child: ListView.builder(

                            // itemExtent: 2,
                            padding: EdgeInsets.all(10),
                            itemCount: fillterProduct.length,
                            itemBuilder: (context, index){
                              final past = fillterProduct[index];
                              return InkWell(
                                onTap: (){
                                  Navigator.push(context, MaterialPageRoute(builder: (context)=> Orderdetails(Order: past),),)
                                      .then((_){
                                    setState(() {

                                    });
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  width: width *0.6,
                                  height: height * 0.15,
                                  decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black,width: 2)
                                  ),
                                  padding: EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(past.kotNumber.toString(),style: GoogleFonts.poppins(fontSize: 10),),
                                          Text(past.orderAt.toString(),style: GoogleFonts.poppins(fontSize: 10),),
                                        ],
                                      ) ,
                                      SizedBox(height: 10,),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(" Rs ${past.totalPrice.toString()}",style: GoogleFonts.poppins(fontSize: 10),),

                                          Text(past.orderType.toString(),style: GoogleFonts.poppins(fontSize: 10),),
                                        ],
                                      ),   SizedBox(height: 10,),
                                      Row(
                                        mainAxisAlignment:MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(past.customerName,style: GoogleFonts.poppins(fontSize: 10),),

                                          if(past.paymentmode != null && past.paymentmode!.isNotEmpty)

                                            Text(
                                              past.paymentmode.toString(),
                                              style: GoogleFonts.poppins(fontSize: 10),
                                            ),

                                        ],
                                      ),


                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }) )
              
              

            ],
          ),
        ));
  }
}
*/
