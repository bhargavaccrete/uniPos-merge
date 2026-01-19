import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
class CustomerListByRevenue extends StatefulWidget {
  const CustomerListByRevenue({super.key});

  @override
  State<CustomerListByRevenue> createState() => _CustomerListByRevenueState();
}

class _CustomerListByRevenueState extends State<CustomerListByRevenue> {
  List<CustomerRevenueData> _customers = [];
  bool _isLoading = true;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCustomerRevenue();
  }

  Future<void> _loadCustomerRevenue() async {
    setState(() => _isLoading = true);

    try {
      final orderBox = Hive.box<pastOrderModel>('pastorderBox');
      final allOrders = orderBox.values.toList();

      // Create a map to track revenue per customer
      final Map<String, CustomerRevenueData> customerMap = {};

      for (final order in allOrders) {
        // Skip fully refunded orders
        if (order.orderStatus == 'FULLY_REFUNDED') continue;

        final customerName = order.customerName.trim();
        if (customerName.isEmpty) continue;

        // Calculate net revenue (total - refund)
        final netRevenue = order.totalPrice - (order.refundAmount ?? 0.0);

        if (customerMap.containsKey(customerName)) {
          customerMap[customerName]!.revenue += netRevenue;
          customerMap[customerName]!.orderCount += 1;
        } else {
          customerMap[customerName] = CustomerRevenueData(
            srNo: 0, // Will be assigned after sorting
            name: customerName,
            mobile: '-', // Placeholder for phone number
            revenue: netRevenue,
            orderCount: 1,
          );
        }
      }

      // Convert to list and sort by revenue (descending)
      final List<CustomerRevenueData> customers = customerMap.values.toList();
      customers.sort((a, b) => b.revenue.compareTo(a.revenue));

      // Assign serial numbers
      for (int i = 0; i < customers.length; i++) {
        customers[i].srNo = i + 1;
      }

      // Calculate total revenue
      final totalRev = customers.fold(0.0, (sum, customer) => sum + customer.revenue);

      setState(() {
        _customers = customers;
        _totalRevenue = totalRev;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customer revenue: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Customer List By Revenue',
            textScaler: TextScaler.linear(1),
            style: GoogleFonts.poppins(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w500)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            )),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Customers: ${_customers.length}',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Total Revenue: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalRevenue)}',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _loadCustomerRevenue,
                          icon: Icon(Icons.refresh, color: AppColors.primary),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    CommonButton(
                        width: width * 0.6,
                        height: height * 0.06,
                        bordercircular: 5,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Export feature coming soon')),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Export TO Excel',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            )
                          ],
                        )),

                    SizedBox(height: 25),

                    if (_customers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(Icons.monetization_on_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No customer revenue data found',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SingleScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 50,
                          columnSpacing: 3,
                          headingRowColor:
                              WidgetStateProperty.all(Colors.grey[300]),
                          decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(20)),
                          border: TableBorder.all(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.white),
                          columns: [
                            DataColumn(
                                headingRowAlignment: MainAxisAlignment.center,
                                label: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          bottomLeft: Radius.circular(10))),
                                  alignment: Alignment.center,
                                  width: width * 0.15,
                                  child: Text(
                                    "Sr No",
                                    textAlign: TextAlign.center,
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                )),
                            DataColumn(
                                label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                              ),
                              alignment: Alignment.center,
                              width: width * 0.3,
                              child: Text(
                                "Customer\n  Name",
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            )),
                            DataColumn(
                                label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                              ),
                              alignment: Alignment.center,
                              width: width * 0.2,
                              child: Text(
                                "Orders",
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            )),
                            DataColumn(
                                label: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(10),
                                    bottomRight: Radius.circular(10)),
                                color: Colors.grey.shade300,
                              ),
                              alignment: Alignment.center,
                              width: width * 0.3,
                              child: Text(
                                "Revenue (${CurrencyHelper.currentSymbol})",
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            )),
                          ],
                          rows: _customers
                              .map((customer) => DataRow(cells: [
                                    DataCell(Center(
                                        child: Text(
                                      customer.srNo.toString(),
                                      style:
                                          GoogleFonts.poppins(fontSize: 13),
                                    ))),
                                    DataCell(Center(
                                        child: Text(
                                      customer.name,
                                      style:
                                          GoogleFonts.poppins(fontSize: 13),
                                    ))),
                                    DataCell(Center(
                                        child: Text(
                                      customer.orderCount.toString(),
                                      style:
                                          GoogleFonts.poppins(fontSize: 13),
                                    ))),
                                    DataCell(Center(
                                        child: Text(
                                      DecimalSettings.formatAmount(customer.revenue),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700),
                                    ))),
                                  ]))
                              .toList(),
                        ),
                      )
                  ],
                ),
              ),
            ),
    );
  }
}

class SingleScrollView extends StatelessWidget {
  final Axis scrollDirection;
  final Widget child;

  const SingleScrollView({
    super.key,
    required this.scrollDirection,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      child: child,
    );
  }
}

class CustomerRevenueData {
  int srNo;
  final String name;
  final String mobile;
  double revenue;
  int orderCount;

  CustomerRevenueData({
    required this.srNo,
    required this.name,
    required this.mobile,
    required this.revenue,
    required this.orderCount,
  });
}