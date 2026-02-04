import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
import 'apply_tax_screen.dart';

class Addtax extends StatefulWidget {
  @override
  State<Addtax> createState() => _AddtaxState();
}

class _AddtaxState extends State<Addtax> {
  bool _ischecked1 = false;

  final TextEditingController _taxNameController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    taxStore.loadTaxes();
  }

  @override
  void dispose() {
    _taxNumberController.dispose();
    _taxNameController.dispose();
    super.dispose();
  }

  void _clearControllers(){
    _taxNumberController.clear();
    _taxNameController.clear();
  }

  Future<void> _addOrUpdateTax({Tax? existingTax})async{
    final taxName = _taxNameController.text.trim();
    final taxPercentage = double.tryParse(_taxNumberController.text.trim());

    if(taxName.isEmpty || taxPercentage == null){
      NotificationService.instance.showInfo(
        'Enter a valid Tax Name/Number',
      );
      return ;
    }

    bool success;
    if(existingTax != null){
      final updatedTax = Tax(
        id: existingTax.id,
        taxname: taxName,
        taxperecentage: taxPercentage,
      );
      success = await taxStore.updateTax(updatedTax);
    }else {
      final newTax = Tax(
        id: Uuid().v4(),
        taxname: taxName,
        taxperecentage: taxPercentage,
      );
      success = await taxStore.addTax(newTax);

      // Apply tax to all items if checkbox is checked
      if(_ischecked1 && success) {
        await _applyTaxToAllItems(taxPercentage);
      }
    }

    if(success) {
      _clearControllers();
      setState(() {
        _ischecked1 = false;
      });
      if(mounted) {
        Navigator.pop(context);
      }
    }
  }


  Future<void> _delete(String id)async{
    final success = await taxStore.deleteTax(id);
    if(success && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _applyTaxToAllItems(double taxPercentage) async {
    final rate = taxPercentage / 100.0;

    for (final item in itemStore.items) {
      item.applyTax(rate);
      await itemStore.updateItem(item);
    }

    NotificationService.instance.showInfo(
      'Tax applied to all items',
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black87),
          title: Text(
            'Manage Taxes',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 22 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 10 : 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      size: isTablet ? 22 : 20,
                      color: AppColors.primary,
                    ),
                  ),
                  if (isTablet) ...[
                    SizedBox(width: 10),
                    Text(
                      'Admin',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Tax List
            Expanded(
              child: Observer(
                builder: (context) {
                  if (taxStore.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  final allTax = taxStore.taxes;

                  if (allTax.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calculate_outlined,
                            size: isTablet ? 80 : 64,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: isTablet ? 20 : 16),
                          Text(
                            'No taxes configured yet',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add your first tax to get started',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    itemCount: allTax.length,
                    itemBuilder: (context, index) {
                      final tax = allTax[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: isTablet ? 12 : 10),
                        padding: EdgeInsets.all(isTablet ? 16 : 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
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
                                        tax.taxname,
                                        style: GoogleFonts.poppins(
                                          fontSize: isTablet ? 17 : 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isTablet ? 10 : 8,
                                          vertical: isTablet ? 5 : 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Tax Rate: ${tax.taxperecentage}%',
                                          style: GoogleFonts.poppins(
                                            fontSize: isTablet ? 14 : 13,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => _model(isTablet, existingTax: tax),
                                      icon: Icon(Icons.edit_rounded),
                                      color: Colors.orange,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _showDeleteConfirmation(context, isTablet, tax.id),
                                      icon: Icon(Icons.delete_rounded),
                                      color: Colors.red,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: isTablet ? 14 : 12),
                            SizedBox(
                              width: double.infinity,
                              height: isTablet ? 48 : 44,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ApplyTaxScreen(taxToApply: tax),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: Icon(Icons.check_circle_outline_rounded, size: isTablet ? 20 : 18),
                                label: Text(
                                  'Apply Tax on Items',
                                  style: GoogleFonts.poppins(
                                    fontSize: isTablet ? 15 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),


            // Add Tax Button
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: SizedBox(
                width: double.infinity,
                height: isTablet ? 54 : 50,
                child: ElevatedButton.icon(
                  onPressed: () => _model(isTablet),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Icons.add_circle_rounded, size: isTablet ? 24 : 22),
                  label: Text(
                    'Add New Tax',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 17 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ));
  }


  void _showDeleteConfirmation(BuildContext context, bool isTablet, String taxId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Tax?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this tax? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _delete(taxId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _model(bool isTablet, {Tax? existingTax}) {
    bool isEdit = existingTax != null;

    if (isEdit) {
      _taxNameController.text = existingTax.taxname;
      _taxNumberController.text = existingTax.taxperecentage.toString();
    } else {
      _clearControllers();
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: isTablet ? 24 : 20,
                right: isTablet ? 24 : 20,
                top: isTablet ? 24 : 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isEdit
                                ? Colors.orange.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
                            size: isTablet ? 28 : 24,
                            color: isEdit ? Colors.orange : AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Tax' : 'Add New Tax',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded),
                          color: Colors.grey.shade700,
                        ),
                      ],
                    ),
                    Divider(height: 32, color: Colors.grey.shade200),
                    Row(
                      children: [
                        Expanded(
                          child: CommonTextForm(
                            obsecureText: false,
                            controller: _taxNameController,
                            labelText: 'Tax Name*',
                            LabelColor: AppColors.primary,
                            BorderColor: AppColors.primary,
                            borderc: 12,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: CommonTextForm(
                            controller: _taxNumberController,
                            labelText: 'Tax %',
                            LabelColor: AppColors.primary,
                            BorderColor: AppColors.primary,
                            borderc: 12,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            obsecureText: false,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (!isEdit)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _ischecked1,
                              activeColor: AppColors.primary,
                              onChanged: (bool? value) {
                                setModalState(() => _ischecked1 = value ?? false);
                              },
                            ),
                            Expanded(
                              child: Text(
                                'Apply to all existing items',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 14 : 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: isTablet ? 28 : 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 24 : 20,
                              vertical: isTablet ? 14 : 12,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 15 : 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => _addOrUpdateTax(existingTax: existingTax),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEdit ? Colors.orange : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 28 : 24,
                              vertical: isTablet ? 14 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isEdit ? 'Update' : 'Add Tax',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 15 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

