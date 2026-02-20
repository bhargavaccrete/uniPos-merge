import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

class Taxragistration extends StatefulWidget {
  @override
  State<Taxragistration> createState() => _TaxragistrationState();
}

class _TaxragistrationState extends State<Taxragistration> {
  final List<Map<String, String>> _registrations = [];

  void _showAddDialog() {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Tax Registration',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Tax Name',
                labelStyle: GoogleFonts.poppins(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.text,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Registration Number',
                labelStyle: GoogleFonts.poppins(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Tax Registration',
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
          Expanded(
            child: _registrations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: isTablet ? 80 : 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        Text(
                          'No tax registrations added yet',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the button below to add one',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14 : 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    itemCount: _registrations.length,
                    itemBuilder: (context, index) {
                      final entry = _registrations[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: isTablet ? 12 : 10),
                        padding: EdgeInsets.all(isTablet ? 16 : 14),
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
                                size: isTablet ? 26 : 22,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(width: isTablet ? 16 : 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry['name']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 16 : 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Reg. No: ${entry['number']!}',
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 13 : 12,
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
              height: isTablet ? 54 : 50,
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
                icon:
                    Icon(Icons.add_circle_rounded, size: isTablet ? 24 : 22),
                label: Text(
                  'Add Tax Name & Number',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 17 : 16,
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
