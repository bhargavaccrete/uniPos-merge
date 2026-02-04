/*
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/color.dart';
import '../../../../../constants/restaurant/color.dart';
import 'ItemsReportData.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
class ThisWeekItems extends StatefulWidget {
  // 1. This widget accepts the report data
  final List<ItemReportData> reportData;

  const ThisWeekItems({
    Key? key,
    required this.reportData,
  }) : super(key: key);

  @override
  State<ThisWeekItems> createState() => _ThisWeekItemsState();
}

class _ThisWeekItemsState extends State<ThisWeekItems> {
  // Use a private controller for good practice
  final TextEditingController _searchController = TextEditingController();
  // 2. State variable to hold the currently visible (filtered) data
  List<ItemReportData> _filteredData = [];

  @override
  void initState() {
    super.initState();
    // Initially, the filtered list is the complete list passed to the widget
    _filteredData = widget.reportData;
    // 3. Add a listener that calls _filterItems whenever the search text changes
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    // 4. Clean up the controller and listener to prevent memory leaks
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      // We always filter from the original, complete list of data
      _filteredData = widget.reportData.where((item) {
        final itemNameLower = item.itemName.toLowerCase();
        return itemNameLower.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: width * 0.6,
                child: CommonTextForm(
                    controller: _searchController, // Connect the controller
                    hintText: "Search Item",
                    HintColor: Colors.grey,
                    icon: Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 30,
                    ),
                    obsecureText: false),
              ),
              const SizedBox(height: 20),
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
                  bordercircular: 5,
                  onTap: () {
                    // TODO: Implement Excel export logic.
                    // You can use the `_filteredData` list to export the currently visible items.
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.note_add_outlined, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Export TO Excel',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      )
                    ],
                  )),
              const SizedBox(height: 25),

              // Use LayoutBuilder to prevent overflow errors with DataTable
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                          headingRowHeight: 50,
                          columnSpacing: 20,
                          headingRowColor:
                          WidgetStateProperty.all(AppColors.primary),
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columns: [
                            // 5. Columns are updated to match the data
                            DataColumn(
                                label: Text('Item Name',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold, color: Colors.white))),
                            DataColumn(
                                label: Text('Quantity',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold, color: Colors.white))),
                            DataColumn(
                                label: Text('Total (${CurrencyHelper.currentSymbol})',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold, color: Colors.white))),
                          ],
                          // 6. Rows are now dynamically generated from your filtered data list
                          rows: _filteredData.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return DataRow(
                              color: MaterialStateProperty.resolveWith<Color?>(
                                      (Set<MaterialState> states) {
                                    if (index.isEven) {
                                      return Colors.white;
                                    }
                                    return Colors.grey.withOpacity(0.1);
                                  }),
                              cells: [
                                DataCell(Text(item.itemName)),
                                DataCell(Center(
                                    child:
                                    Text(item.totalQuantity.toString()))),
                                DataCell(Center(
                                    child: Text(
                                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.totalRevenue)}'))),
                              ],
                            );
                          }).toList()),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}*/
