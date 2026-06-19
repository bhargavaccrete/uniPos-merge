import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart' show CommonButton;
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';
import 'variant_selection_screen.dart';
import 'choice_selection_screen.dart';
import 'extra_selection_screen.dart';
import 'tax_selection_screen.dart';
import 'default_choice_picker.dart';
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
  List<String> defaultChoiceOptionIds = []; // per-item default-selected choice options
  String? selectedTaxId;
  double? selectedTaxRate;
  bool _trackInventory = false;

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
      defaultChoiceOptionIds = List<String>.from(itemData['defaultChoiceOptionIds'] ?? []);
      selectedTaxId = itemData['taxId'];
      selectedTaxRate = itemData['taxRate'];
      _trackInventory = itemData['trackInventory'] == true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Add More Info',
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Scrollable content region
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Add Variants Option
                  _buildOptionCard(
                    icon: Icons.straighten_outlined,
                    title: 'Add Variants',
                    description:
                        'Add different sizes (S, M, L) with custom prices',
                    count: selectedVariants.length,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VariantSelectionScreen(
                            selectedVariants: selectedVariants,
                            trackInventory: _trackInventory,
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

                  const SizedBox(height: 14),

                  // Add Choices Option
                  _buildOptionCard(
                    icon: Icons.checklist_outlined,
                    title: 'Add Choices',
                    description:
                        'Add choice groups like spice level, cooking style',
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

                  // Default Selection — only meaningful once choice groups are attached.
                  if (selectedChoiceIds.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildOptionCard(
                      icon: Icons.task_alt_outlined,
                      title: 'Default Selection',
                      description:
                          'Pre-tick choice options this item normally comes with',
                      count: defaultChoiceOptionIds.length,
                      onTap: _pickDefaults,
                    ),
                  ],

                  const SizedBox(height: 14),

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
                ],
              ),
            ),
          ),

          // Pinned footer action bar
          _buildFooter(),
        ],
      ),
    );
  }

  /// Intro header shown above the option cards.
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enhance your item',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'These options are optional — add what fits this item.',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Pinned bottom action bar with Back / Save & Continue.
  Widget _buildFooter() {
    final payload = {
      ...itemData,
      'variants': selectedVariants,
      'choiceIds': selectedChoiceIds,
      'extraIds': selectedExtraIds,
      'defaultChoiceOptionIds': defaultChoiceOptionIds,
      'taxId': selectedTaxId,
      'taxRate': selectedTaxRate,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: CommonButton(
                onTap: () => Navigator.pop(context, payload),
                bgcolor: AppColors.white,
                bordercolor: AppColors.primary,
                bordercircular: 10,
                height: AppResponsive.buttonHeight(context),
                child: Text(
                  'Back',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: CommonButton(
                onTap: () => Navigator.pop(context, {
                  ...payload,
                  'shouldSave': true,
                }),
                bordercircular: 10,
                height: AppResponsive.buttonHeight(context),
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
      ),
    );
  }

  /// Opens the shared picker to choose this item's default choice options.
  Future<void> _pickDefaults() async {
    final result = await showDefaultChoicePicker(
        context, selectedChoiceIds, defaultChoiceOptionIds);
    if (result != null && mounted) {
      setState(() => defaultChoiceOptionIds = result);
    }
  }

  Widget _buildTaxCard({
    required IconData icon,
    required String title,
    required String description,
    required bool hasSelection,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasSelection ? AppColors.primary : AppColors.divider,
            width: hasSelection ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: hasSelection ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surfaceLight,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
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
    final bool isConfigured = count > 0;

    // Material gives the surface color + branded shadow + rounded clip;
    // the InkWell ripple paints on it (visible), and the inner Container
    // only draws the border so the configured state reads clearly.
    return Material(
      color: AppColors.white,
      elevation: 2,
      shadowColor: AppColors.cardShadow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isConfigured ? AppColors.primary : AppColors.divider,
              width: isConfigured ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(alpha: isConfigured ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildTrailingStatus(count),
            ],
          ),
        ),
      ),
    );
  }

  /// Right-side indicator of an option card. Communicates, at a glance,
  /// whether the option has been configured and how much.
  Widget _buildTrailingStatus(int count) {
    if (count == 0) {
      return Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.textSecondary,
      );
    }

    // Configured: count pill + a check so it reads as "done, with N added".
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.poppins(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.check_circle, size: 18, color: AppColors.success),
      ],
    );
  }
}