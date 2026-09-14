import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/Button.dart'
    show CommonButton;
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'variant_selection_screen.dart';
import 'choice_selection_screen.dart';
import 'extra_selection_screen.dart';
import 'tax_selection_screen.dart';
import 'default_choice_picker.dart';
import 'package:billberrylite/util/common/responsive_route.dart';

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
  List<String> defaultChoiceOptionIds =
      []; // per-item default-selected choice options
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
      selectedVariants = List<Map<String, dynamic>>.from(
        itemData['variants'] ?? [],
      );
      selectedChoiceIds = List<String>.from(itemData['choiceIds'] ?? []);
      selectedExtraIds = List<String>.from(itemData['extraIds'] ?? []);
      defaultChoiceOptionIds = List<String>.from(
        itemData['defaultChoiceOptionIds'] ?? [],
      );
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
              padding: EdgeInsets.fromLTRB(
                AppResponsive.largeSpacing(context),
                AppResponsive.largeSpacing(context),
                AppResponsive.largeSpacing(context),
                AppResponsive.extraLargeSpacing(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*   _buildHeader(),
                  const SizedBox(height: 24),*/

                  // Add Variants Option
                  if (itemData['productType'] != ProductType.rawMaterial &&
                      itemData['productType'] != ProductType.semiFinished) ...[
                    _buildOptionCard(
                      icon: Icons.straighten_outlined,
                      title: 'Add Variants',
                      description:
                          'Add different sizes (S, M, L) with custom prices',
                      count: selectedVariants.length,
                      onTap: () async {
                        final result = await pushResponsive(
                          context,
                          VariantSelectionScreen(
                            selectedVariants: selectedVariants,
                            trackInventory: _trackInventory,
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            selectedVariants = result;
                          });
                        }
                      },
                    ),
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                  ],

                  // Add Choices Option
                  _buildOptionCard(
                    icon: Icons.checklist_outlined,
                    title: 'Add Choices',
                    description:
                        'Add choice groups like spice level, cooking style',
                    count: selectedChoiceIds.length,
                    onTap: () async {
                      final result = await pushResponsive(
                        context,
                        ChoiceSelectionScreen(
                          selectedChoiceIds: selectedChoiceIds,
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
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                    _buildOptionCard(
                      icon: Icons.task_alt_outlined,
                      title: 'Default Selection',
                      description:
                          'Pre-tick choice options this item normally comes with',
                      count: defaultChoiceOptionIds.length,
                      onTap: _pickDefaults,
                    ),
                  ],

                  SizedBox(height: AppResponsive.mediumSpacing(context)),

                  // Add Extras Option
                  _buildOptionCard(
                    icon: Icons.add_circle_outline,
                    title: 'Add Extras',
                    description: 'Add extra toppings and add-ons with prices',
                    count: selectedExtraIds.length,
                    onTap: () async {
                      final result = await pushResponsive(
                        context,
                        ExtraSelectionScreen(
                          selectedExtraIds: selectedExtraIds,
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
  /*  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enhance your item',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.headingFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'These options are optional — add what fits this item.',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }*/

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
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
      ),
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
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: CommonButton(
                onTap: () =>
                    Navigator.pop(context, {...payload, 'shouldSave': true}),
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
      context,
      selectedChoiceIds,
      defaultChoiceOptionIds,
    );
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
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: Container(
        padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasSelection ? AppColors.primary : AppColors.divider,
            width: hasSelection ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          color: hasSelection
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surfaceLight,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: AppResponsive.iconSize(context),
              ),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: AppResponsive.smallIconSize(context),
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
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        child: Container(
          padding: AppResponsive.cardPadding(context),
          decoration: BoxDecoration(
            border: Border.all(
              color: isConfigured ? AppColors.primary : AppColors.divider,
              width: isConfigured ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: isConfigured ? 0.14 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppResponsive.borderRadius(context),
                  ),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: AppResponsive.iconSize(context),
                ),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
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
        size: AppResponsive.smallIconSize(context),
        color: AppColors.textSecondary,
      );
    }

    // Configured: count pill + a check so it reads as "done, with N added".
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.smallSpacing(context),
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.poppins(
              color: AppColors.white,
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Icon(
          Icons.check_circle,
          size: AppResponsive.smallIconSize(context),
          color: AppColors.success,
        ),
      ],
    );
  }
}
