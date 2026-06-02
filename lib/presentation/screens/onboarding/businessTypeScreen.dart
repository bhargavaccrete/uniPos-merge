import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';

const _typeFeatures = {
  'retail': ['Barcode Scanning', 'Stock Management', 'Customer Loyalty'],
  'restaurant': ['Table Management', 'Kitchen Display', 'Menu Builder'],
};

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
    final isWide = AppResponsive.isTablet(context) || AppResponsive.isDesktop(context);
    final hPad = AppResponsive.getValue<double>(context, mobile: 20, tablet: 40, desktop: 56);
    final vPad = AppResponsive.getValue<double>(context, mobile: 20, tablet: 28, desktop: 32);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 0),
            child: isWide
                ? _buildWideContent(context)
                : _buildMobileContent(context),
          ),
        ),
        _buildNavBar(context, hPad, vPad),
      ],
    );
  }

  // ── Mobile layout ─────────────────────────────────────────────────────────────

  Widget _buildMobileContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(context, compact: true),
        const SizedBox(height: 6),
        _buildHint(context),
        const SizedBox(height: 24),
        _buildCards(context),
        const SizedBox(height: 20),
        _buildInfoBanner(context),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Wide (tablet/desktop) layout ──────────────────────────────────────────────

  Widget _buildWideContent(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppResponsive.getValue<double>(context, mobile: 600, tablet: 700, desktop: 820),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle(context, compact: false),
            const SizedBox(height: 8),
            _buildHint(context),
            const SizedBox(height: 32),
            _buildCards(context),
            const SizedBox(height: 24),
            _buildInfoBanner(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Title ─────────────────────────────────────────────────────────────────────

  Widget _buildTitle(BuildContext context, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What kind of business are you running?',
          style: GoogleFonts.poppins(
            fontSize: compact
                ? AppResponsive.getValue<double>(context, mobile: 22, tablet: 26, desktop: 28)
                : AppResponsive.getValue<double>(context, mobile: 24, tablet: 28, desktop: 32),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  // ── Subtitle hint ─────────────────────────────────────────────────────────────

  Widget _buildHint(BuildContext context) {
    return Text(
      'Pick one — UniPOS will adapt its layout, workflows, and features for you.',
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.getValue<double>(context, mobile: 13, tablet: 14, desktop: 15),
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    );
  }

  // ── Cards (stacked full-width) ────────────────────────────────────────────────

  Widget _buildCards(BuildContext context) {
    final types = store.businessTypes;
    final gap = AppResponsive.getValue<double>(context, mobile: 12, tablet: 16, desktop: 16);

    return Column(
      children: [
        for (int i = 0; i < types.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Observer(builder: (_) {
            final isSelected = store.selectedBusinessTypeId == types[i]['id'];
            return _BusinessTypeCard(
              type: types[i],
              isSelected: isSelected,
              onTap: () => store.selectBusinessType(types[i]['id']!, types[i]['name']!),
            );
          }),
        ],
      ],
    );
  }

  // ── Info banner ───────────────────────────────────────────────────────────────

  Widget _buildInfoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 15, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You cannot change your business type after setup.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.getValue<double>(context, mobile: 12, tablet: 13, desktop: 13),
                color: Colors.amber.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav bar ────────────────────────────────────────────────────────────

  Widget _buildNavBar(BuildContext context, double hPad, double vPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, vPad),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.6))),
      ),
      child: Observer(
        builder: (_) => Row(
          children: [
            SizedBox(
              width: 88,
              child: OutlinedButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back, size: 15),
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
                      borderRadius:
                          BorderRadius.circular(AppResponsive.borderRadius(context))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: store.canProceedFromBusinessType
                    ? () async {
                        await store.saveBusinessType();
                        onNext();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                  padding: EdgeInsets.symmetric(
                      vertical: AppResponsive.getValue<double>(
                          context, mobile: 14, tablet: 16, desktop: 16)),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppResponsive.borderRadius(context))),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continue',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 15, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Business Type Card ────────────────────────────────────────────────────────

class _BusinessTypeCard extends StatelessWidget {
  final Map<String, String> type;
  final bool isSelected;
  final VoidCallback onTap;

  const _BusinessTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  IconData _icon() {
    switch (type['icon']) {
      case 'store':
        return Icons.storefront_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  Color get _accentColor {
    switch (type['id']) {
      case 'restaurant':
        return const Color(0xFFEF6C00);
      default:
        return AppColors.primary;
    }
  }

  List<String> _features() => _typeFeatures[type['id']] ?? [];

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final iconSize = AppResponsive.getValue<double>(context, mobile: 28, tablet: 34, desktop: 38);
    final pad = AppResponsive.getValue<double>(context, mobile: 16, tablet: 20, desktop: 24);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : AppColors.divider,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 18, offset: const Offset(0, 5))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon block
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(iconSize * 0.3),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(),
                  size: iconSize,
                  color: isSelected ? Colors.white : AppColors.textSecondary),
            ),

            const SizedBox(width: 14),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + check row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          type['name'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue<double>(
                                context, mobile: 15, tablet: 17, desktop: 19),
                            fontWeight: FontWeight.w700,
                            color: isSelected ? accent : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Radio circle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? accent : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? accent : AppColors.divider,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    type['description'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue<double>(
                          context, mobile: 12, tablet: 13, desktop: 14),
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),

                  if (_features().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _features()
                          .map((f) => _chip(context, f, accent))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? accent.withValues(alpha: 0.1) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? accent.withValues(alpha: 0.3) : AppColors.divider,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isSelected ? accent : AppColors.textSecondary,
        ),
      ),
    );
  }
}
