import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

import '../../../widget/componets/restaurant/componets/manyListViewWithBottomSheet.dart';

class Taxragistration extends StatelessWidget{
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
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: Column(
                children: [
                  Container(
                    child: MultipleListView(
                      ShowText: "Tax Registration",
                      lists: [['TAX NAME : ','DRR','TAX NUMBER : ','25412']],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: SizedBox(
              width: double.infinity,
              height: isTablet ? 54 : 50,
              child: ElevatedButton.icon(
                onPressed: (){},
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