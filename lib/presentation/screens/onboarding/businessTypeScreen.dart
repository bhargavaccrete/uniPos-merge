import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';

/// Business Type Selection Step
class BusinessTypeStep extends StatelessWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const BusinessTypeStep({
    Key? key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hPad = AppResponsive.getValue<double>(
        context, mobile: 20, tablet: 32, desktop: 40);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          _buildSubtitle(context),
          SizedBox(height: AppResponsive.extraLargeSpacing(context)),
          _buildTypeCards(context),
          SizedBox(height: AppResponsive.extraLargeSpacing(context)),
          _buildNavButtons(context),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.storefront_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Type',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.headingFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Choose how UniPOS should be configured',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(AppResponsive.borderRadius(context)),
        border:
            Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              color: AppColors.info,
              size: AppResponsive.iconSize(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This sets up your POS layout, workflows, and features. You cannot change this later.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Type Cards ──────────────────────────────────────────────────────────────

  Widget _buildTypeCards(BuildContext context) {
    final types = store.businessTypes;
    final isWide = AppResponsive.isTablet(context) ||
        AppResponsive.isDesktop(context);
    final gap = AppResponsive.mediumSpacing(context);

    if (isWide) {
      // Side-by-side on tablet/desktop
      return IntrinsicHeight(
        child: Row(
          children: [
            for (int i = 0; i < types.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: Observer(builder: (_) {
                  final isSelected =
                      store.selectedBusinessTypeId == types[i]['id'];
                  return _BusinessTypeCard(
                    type: types[i],
                    isSelected: isSelected,
                    isWide: true,
                    onTap: () =>
                        store.selectBusinessType(types[i]['id']!, types[i]['name']!),
                  );
                }),
              ),
            ],
          ],
        ),
      );
    }

    // Stacked on mobile
    return Column(
      children: [
        for (int i = 0; i < types.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Observer(builder: (_) {
            final isSelected =
                store.selectedBusinessTypeId == types[i]['id'];
            return _BusinessTypeCard(
              type: types[i],
              isSelected: isSelected,
              isWide: false,
              onTap: () =>
                  store.selectBusinessType(types[i]['id']!, types[i]['name']!),
            );
          }),
        ],
      ],
    );
  }

  // ── Nav Buttons ─────────────────────────────────────────────────────────────

  Widget _buildNavButtons(BuildContext context) {
    return Observer(
      builder: (_) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: Text('Back',
                  style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                padding: EdgeInsets.symmetric(
                    vertical: AppResponsive.getValue<double>(
                        context, mobile: 14, tablet: 16, desktop: 16)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppResponsive.borderRadius(context))),
              ),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: store.canProceedFromBusinessType
                  ? () async {
                      await store.saveBusinessType();
                      onNext();
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward,
                  size: 16, color: AppColors.white),
              label: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.4),
                padding: EdgeInsets.symmetric(
                    vertical: AppResponsive.getValue<double>(
                        context, mobile: 14, tablet: 16, desktop: 16)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppResponsive.borderRadius(context))),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Business Type Card ─────────────────────────────────────────────────────────

class _BusinessTypeCard extends StatelessWidget {
  final Map<String, String> type;
  final bool isSelected;
  final bool isWide;
  final VoidCallback onTap;

  const _BusinessTypeCard({
    required this.type,
    required this.isSelected,
    required this.isWide,
    required this.onTap,
  });

  IconData _icon() {
    switch (type['icon']) {
      case 'store':
        return Icons.store_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = AppResponsive.getValue<double>(
        context, mobile: 40, tablet: 52, desktop: 60);
    final titleFs = AppResponsive.getValue<double>(
        context, mobile: 15, tablet: 17, desktop: 18);
    final descFs = AppResponsive.captionFontSize(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(
            AppResponsive.getValue<double>(context, mobile: 18, tablet: 24, desktop: 28)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.white,
          borderRadius: BorderRadius.circular(
              AppResponsive.largeBorderRadius(context)),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: isWide
            ? _wideLayout(context, iconSize, titleFs, descFs)
            : _compactLayout(context, iconSize, titleFs, descFs),
      ),
    );
  }

  // Tablet: icon + text side-by-side
  Widget _wideLayout(
      BuildContext context, double iconSize, double titleFs, double descFs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _iconBadge(iconSize),
        const SizedBox(height: 16),
        _texts(context, titleFs, descFs, center: true),
        if (isSelected) ...[
          const SizedBox(height: 14),
          _selectedBadge(),
        ],
      ],
    );
  }

  // Mobile: icon left, text right
  Widget _compactLayout(
      BuildContext context, double iconSize, double titleFs, double descFs) {
    return Row(
      children: [
        _iconBadge(iconSize),
        const SizedBox(width: 16),
        Expanded(child: _texts(context, titleFs, descFs, center: false)),
        if (isSelected) ...[
          const SizedBox(width: 12),
          _selectedBadge(),
        ],
      ],
    );
  }

  Widget _iconBadge(double size) {
    return Container(
      padding: EdgeInsets.all(size * 0.25),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        _icon(),
        size: size,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }

  Widget _texts(BuildContext context, double titleFs, double descFs,
      {required bool center}) {
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          type['name'] ?? '',
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: titleFs,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          type['description'] ?? '',
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: descFs,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _selectedBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text('Selected',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ],
      ),
    );
  }
}
