import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/data/models/restaurant/db/taxmodel_314.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_tax.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import 'package:uuid/uuid.dart';

class TaxSelectionScreen extends StatefulWidget {
  final String? selectedTaxId;
  final double? currentTaxRate;

  const TaxSelectionScreen({
    super.key,
    this.selectedTaxId,
    this.currentTaxRate,
  });

  @override
  State<TaxSelectionScreen> createState() => _TaxSelectionScreenState();
}

class _TaxSelectionScreenState extends State<TaxSelectionScreen> {
  List<Tax> availableTaxes = [];
  String? selectedTaxId;
  double? selectedTaxRate;

  @override
  void initState() {
    super.initState();
    _loadTaxes();
    selectedTaxId = widget.selectedTaxId;
    selectedTaxRate = widget.currentTaxRate;
  }

  void _loadTaxes() async {
    final taxBox = await TaxBox.getTaxBox();
    setState(() {
      availableTaxes = taxBox.values.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Tax',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: primarycolor),
            onPressed: () => _showAddTaxDialog(),
            tooltip: 'Add New Tax',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: availableTaxes.isEmpty
                ? _buildEmptyState()
                : _buildTaxList(),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              'No Taxes Available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add a tax to get started',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 30),
            CommonButton(
              onTap: () => _showAddTaxDialog(),
              height: 50,
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Add Tax',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: availableTaxes.length + 1, // +1 for "No Tax" option
      itemBuilder: (context, index) {
        // First item is "No Tax" option
        if (index == 0) {
          return _buildTaxCard(
            null,
            'No Tax',
            0.0,
            selectedTaxId == null,
          );
        }

        final tax = availableTaxes[index - 1];
        return _buildTaxCard(
          tax.id,
          tax.taxname,
          tax.taxperecentage,
          selectedTaxId == tax.id,
        );
      },
    );
  }

  Widget _buildTaxCard(String? taxId, String name, double? percentage, bool isSelected) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? primarycolor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            selectedTaxId = taxId;
            selectedTaxRate = percentage != null ? percentage / 100.0 : null;
          });
        },
        leading: Icon(
          isSelected ? Icons.check_circle : Icons.circle_outlined,
          color: isSelected ? primarycolor : Colors.grey,
        ),
        title: Text(
          name,
          style: GoogleFonts.poppins(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${(percentage ?? 0.0).toStringAsFixed(2)}%',
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: taxId != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteTax(taxId),
              )
            : null,
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CommonButton(
              onTap: () => Navigator.pop(context),
              bgcolor: Colors.white,
              bordercolor: primarycolor,
              bordercircular: 10,
              height: ResponsiveHelper.responsiveHeight(context, 0.06),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: primarycolor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: CommonButton(
              onTap: () {
                Navigator.pop(context, {
                  'taxId': selectedTaxId,
                  'taxRate': selectedTaxRate,
                });
              },
              bordercircular: 10,
              height: ResponsiveHelper.responsiveHeight(context, 0.06),
              child: Text(
                'Apply Tax',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaxDialog() async {
    final nameController = TextEditingController();
    final percentageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New Tax',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Tax Name',
                labelStyle: GoogleFonts.poppins(),
                border: const OutlineInputBorder(),
                hintText: 'e.g., GST, VAT, Sales Tax',
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: percentageController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tax Percentage',
                labelStyle: GoogleFonts.poppins(),
                border: const OutlineInputBorder(),
                hintText: 'e.g., 18',
                suffixText: '%',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              percentageController.dispose();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final percentage = double.tryParse(percentageController.text.trim());

              if (name.isEmpty || percentage == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid tax details')),
                );
                return;
              }

              final newTax = Tax(
                id: const Uuid().v4(),
                taxname: name,
                taxperecentage: percentage,
              );

              // Save the tax
              await TaxBox.addTax(newTax);

              // Unfocus keyboard
              FocusScope.of(context).unfocus();

              // Close the dialog
              Navigator.of(context).pop();

              // Dispose controllers after dialog is closed
              await Future.delayed(const Duration(milliseconds: 100));
              nameController.dispose();
              percentageController.dispose();

              // Auto-select the newly added tax
              if (mounted) {
                setState(() {
                  selectedTaxId = newTax.id;
                  selectedTaxRate = newTax.taxperecentage != null
                      ? newTax.taxperecentage! / 100.0
                      : null;
                });
                _loadTaxes();
              }

              // Show success message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name added and selected successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primarycolor,
            ),
            child: Text(
              'Add Tax',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTax(String taxId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Tax?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this tax?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Yes, Delete',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TaxBox.deleteTax(taxId);
      if (selectedTaxId == taxId) {
        setState(() {
          selectedTaxId = null;
          selectedTaxRate = null;
        });
      }
      _loadTaxes();
    }
  }
}
