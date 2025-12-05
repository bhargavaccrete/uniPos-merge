import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart' show CommonButton;
import 'package:unipos/util/restaurant/responsive_helper.dart';
import 'variant_selection_screen.dart';
import 'choice_selection_screen.dart';
import 'extra_selection_screen.dart';

class AddMoreInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  
  const AddMoreInfoScreen({super.key, this.initialData});

  @override
  State<AddMoreInfoScreen> createState() => _AddMoreInfoScreenState();
}

class _AddMoreInfoScreenState extends State<AddMoreInfoScreen> {
  Map<String, dynamic> itemData = {};
  
  // Selected data
  List<Map<String, dynamic>> selectedVariants = [];
  List<String> selectedChoiceIds = [];
  List<String> selectedExtraIds = [];
  
  @override
  void initState() {
    super.initState();
    // Initialize with passed data if available
    if (widget.initialData != null) {
      itemData = Map<String, dynamic>.from(widget.initialData!);
      // Load any existing selections
      selectedVariants = List<Map<String, dynamic>>.from(itemData['variants'] ?? []);
      selectedChoiceIds = List<String>.from(itemData['choiceIds'] ?? []);
      selectedExtraIds = List<String>.from(itemData['extraIds'] ?? []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add More Info',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enhance your item with additional options',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 30),
            
            // Add Variants Option
            _buildOptionCard(
              icon: Icons.straighten_outlined,
              title: 'Add Variants',
              description: 'Add different sizes (S, M, L) with custom prices',
              count: selectedVariants.length,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VariantSelectionScreen(
                      selectedVariants: selectedVariants,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    selectedVariants = result;
                  });
                }
              },
            ),
            
            SizedBox(height: 20),
            
            // Add Choices Option
            _buildOptionCard(
              icon: Icons.checklist_outlined,
              title: 'Add Choices',
              description: 'Add choice groups like spice level, cooking style',
              count: selectedChoiceIds.length,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChoiceSelectionScreen(
                      selectedChoiceIds: selectedChoiceIds,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    selectedChoiceIds = result;
                  });
                }
              },
            ),
            
            SizedBox(height: 20),
            
            // Add Extras Option
            _buildOptionCard(
              icon: Icons.add_circle_outline,
              title: 'Add Extras',
              description: 'Add extra toppings and add-ons with prices',
              count: selectedExtraIds.length,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExtraSelectionScreen(
                      selectedExtraIds: selectedExtraIds,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    selectedExtraIds = result;
                  });
                }
              },
            ),
            
            Spacer(),
            
            // Bottom Buttons
            Row(
              children: [
                Expanded(
                  child: CommonButton(
                    onTap: () => Navigator.pop(context, {
                      ...itemData,
                      'variants': selectedVariants,
                      'choiceIds': selectedChoiceIds,
                      'extraIds': selectedExtraIds,
                    }),
                    bgcolor: Colors.white,
                    bordercolor: primarycolor,
                    bordercircular: 10,
                    height: ResponsiveHelper.responsiveHeight(context, 0.06),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.poppins(
                        color: primarycolor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: CommonButton(
                    onTap: () => Navigator.pop(context, {
                      ...itemData,
                      'variants': selectedVariants,
                      'choiceIds': selectedChoiceIds,
                      'extraIds': selectedExtraIds,
                      'shouldSave': true,
                    }),
                    bordercircular: 10,
                    height: ResponsiveHelper.responsiveHeight(context, 0.06),
                    child: Text(
                      'Save & Continue',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primarycolor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: primarycolor,
                size: 24,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (count > 0) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primarycolor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}