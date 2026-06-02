import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:unipos/util/common/app_responsive.dart';

class Taxragistration extends StatefulWidget {
  @override
  State<Taxragistration> createState() => _TaxragistrationState();
}

class _TaxragistrationState extends State<Taxragistration> {
  final List<Map<String, String>> _registrations = [];

  void _showAddDialog() {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    final isTabletDialog = !AppResponsive.isMobile(context);
    final hInset = isTabletDialog
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Tax Registration',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: nameController,
              label: 'Tax Name',
              hint: 'e.g. GST',
              icon: Icons.receipt_outlined,
            ),
            SizedBox(height: 12),
            AppTextField(
              controller: numberController,
              label: 'Registration Number',
              hint: 'e.g. 27AAPFU0939F1ZV',
              icon: Icons.tag_rounded,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final number = numberController.text.trim();
              if (name.isEmpty || number.isEmpty) return;
              setState(() {
                _registrations.add({'name': name, 'number': number});
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Add',
              style:
                  GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      numberController.dispose();
    });
  }

  void _deleteRegistration(int index) {
    setState(() {
      _registrations.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: buildPrimaryAppBar(
        title: 'Tax Registration',
        titleFontSize: AppResponsive.headingFontSize(context),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.mediumSpacing(context),
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: AppResponsive.iconSize(context),
                    color: Colors.white,
                  ),
                ),
                if (isTablet) ...[
                  SizedBox(width: 10),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
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
          Expanded(
            child: _registrations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: AppResponsive.largeAvatarSize(context),
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        Text(
                          'No tax registrations added yet',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the button below to add one',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: AppResponsive.padding(context),
                    itemCount: _registrations.length,
                    itemBuilder: (context, index) {
                      final entry = _registrations[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
                        padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                size: AppResponsive.iconSize(context),
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(width: AppResponsive.mediumSpacing(context)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry['name']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.bodyFontSize(context),
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Reg. No: ${entry['number']!}',
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.smallFontSize(context),
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _deleteRegistration(index),
                              icon: Icon(Icons.delete_rounded),
                              color: Colors.red,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.red.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: SizedBox(
              width: double.infinity,
              height: AppResponsive.buttonHeight(context),
              child: ElevatedButton.icon(
                onPressed: _showAddDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.add_circle_rounded, size: AppResponsive.iconSize(context)),
                label: Text(
                  'Add Tax Name & Number',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.buttonFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
