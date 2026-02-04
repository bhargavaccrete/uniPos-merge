/*
// In a new file: lib/screens/Reports/salesByCategory/CategoryReportView.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
// Import your local files
import '../../../../../constants/restaurant/color.dart';
import 'CategoryReportData.dart';
import 'package:unipos/util/color.dart';
class CategoryReportView extends StatefulWidget {
  final List<CategoryReportData> reportData;

  const CategoryReportView({
    Key? key,
    required this.reportData,
  }) : super(key: key);

  @override
  State<CategoryReportView> createState() => _CategoryReportViewState();
}

class _CategoryReportViewState extends State<CategoryReportView> {
  final TextEditingController _searchController = TextEditingController();
  List<CategoryReportData> _filteredData = [];

  @override
  void initState() {
    super.initState();
    _filteredData = widget.reportData;
    _searchController.addListener(_filterItems);
  }

  @override
  void didUpdateWidget(covariant CategoryReportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent widget passes new data (e.g., from a new filter), 
    // update the view to reflect the new data.
    if (widget.reportData != oldWidget.reportData) {
      _filteredData = widget.reportData;
      // Also apply the current search filter to the new data
      _filterItems();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredData = widget.reportData.where((category) {
        final categoryNameLower = category.categoryName.toLowerCase();
        return categoryNameLower.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: CommonTextForm( // Assuming this is your custom text field widget
            controller: _searchController,
            hintText: "Search Category",
            HintColor: Colors.grey,
            icon: Icon(Icons.search, color: AppColors.primary, size: 30),
            obsecureText: false,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                    columns: [
                      DataColumn(label: Text('Category', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Items Sold', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text('Total (${CurrencyHelper.currentSymbol})', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), numeric: true),
                    ],
                    rows: _filteredData.map((category) {
                      return DataRow(
                        cells: [
                          DataCell(Text(category.categoryName)),
                          DataCell(Center(child: Text(category.totalItemsSold.toString()))),
                          DataCell(Center(child: Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(category.totalRevenue)}'))),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}*/
