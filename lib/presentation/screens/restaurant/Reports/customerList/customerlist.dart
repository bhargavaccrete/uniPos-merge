import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class CustomerListReport extends StatefulWidget {
  const CustomerListReport({super.key});

  @override
  State<CustomerListReport> createState() => _CustomerListReportState();
}

class _CustomerListReportState extends State<CustomerListReport> {
  List<CustomerData> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    try {
      final orderBox = Hive.box<pastOrderModel>('pastorderBox');
      final allOrders = orderBox.values.toList();

      // Create a map to track unique customers with their phone numbers
      final Map<String, String?> customerMap = {};

      for (final order in allOrders) {
        final customerName = order.customerName.trim();
        if (customerName.isNotEmpty) {
          // Store customer name and try to extract phone if available from remark or other field
          if (!customerMap.containsKey(customerName)) {
            customerMap[customerName] = null; // Placeholder for phone number
          }
        }
      }

      // Convert to list
      final List<CustomerData> customers = [];
      int index = 1;
      for (final entry in customerMap.entries) {
        customers.add(CustomerData(
          srNo: index++,
          name: entry.key,
          mobile: entry.value ?? '-',
        ));
      }

      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customers: $e')),
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
        title: Text('Customer List Report',
            textScaler: TextScaler.linear(1),
            style: GoogleFonts.poppins(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w500)),
        centerTitle: true,
        backgroundColor: primarycolor,
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
          ? Center(child: CircularProgressIndicator(color: primarycolor))
          : SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Customers: ${_customers.length}',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        IconButton(
                          onPressed: _loadCustomers,
                          icon: Icon(Icons.refresh, color: primarycolor),
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
                            SnackBar(content: Text('Export feature coming soon')),
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
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No customers found',
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
                      Container(
                        decoration: BoxDecoration(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                              headingRowHeight: 50,
                              columnSpacing: 2,
                              headingRowColor:
                                  WidgetStateProperty.all(Colors.grey[300]),
                              border: TableBorder.all(color: Colors.white),
                              decoration: BoxDecoration(),
                              columns: [
                                DataColumn(
                                    columnWidth: FixedColumnWidth(width * 0.25),
                                    label: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(50),
                                            bottomLeft: Radius.circular(50),
                                          ),
                                        ),
                                        child: Text(
                                          'Sr No',
                                          textScaler: TextScaler.linear(1),
                                          style: GoogleFonts.poppins(fontSize: 14),
                                        ))),
                                DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,
                                    columnWidth: FixedColumnWidth(width * 0.4),
                                    label: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(10),
                                            bottomLeft: Radius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          "Customer Name",
                                          textScaler: TextScaler.linear(1),
                                          style: GoogleFonts.poppins(fontSize: 14),
                                        ))),
                                DataColumn(
                                    headingRowAlignment:
                                        MainAxisAlignment.center,
                                    columnWidth: FixedColumnWidth(width * 0.3),
                                    label: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(10),
                                            bottomLeft: Radius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          'Mobile',
                                          textScaler: TextScaler.linear(1),
                                          style: GoogleFonts.poppins(fontSize: 14),
                                        )))
                              ],
                              rows: _customers
                                  .map((customer) => DataRow(
                                        cells: [
                                          DataCell(
                                            Center(
                                                child: Text(
                                              customer.srNo.toString(),
                                              style: GoogleFonts.poppins(
                                                  fontSize: 13),
                                            )),
                                          ),
                                          DataCell(
                                            Center(
                                                child: Text(
                                              customer.name,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 13),
                                            )),
                                          ),
                                          DataCell(
                                            Center(
                                                child: Text(
                                              customer.mobile,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 13),
                                            )),
                                          ),
                                        ],
                                      ))
                                  .toList()),
                        ),
                      )
                  ],
                ),
              ),
            ),
    );
  }
}

class CustomerData {
  final int srNo;
  final String name;
  final String mobile;

  CustomerData({
    required this.srNo,
    required this.name,
    required this.mobile,
  });
}