import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

/// Retail counterpart of the restaurant Need Help screen. Same layout and
/// support details; the FAQ answers point at retail's own navigation.
class RetailNeedHelpScreen extends StatelessWidget {
  const RetailNeedHelpScreen({super.key});

  // ── Support details ──────────────────────────────────────────────────
  static const String _phone = '+91 079 2321 3063';
  static const String _email = 'sales@accreteinfo.com';

  Future<void> _launch(BuildContext context, Uri uri) async {
    // Capture before the await — context may unmount across the async gap.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No app available to handle this action'),
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open this action')),
      );
    }
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Need Help?', centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroBanner(context),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            _sectionTitle(context, 'Contact Us'),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _contactCard(
              context: context,
              icon: Icons.call_rounded,
              color: AppColors.success,
              title: 'Call Support',
              value: _phone,
              onTap: () =>
                  _launch(context, Uri.parse('tel:${_digits(_phone)}')),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _contactCard(
              context: context,
              icon: Icons.mail_rounded,
              color: AppColors.orange,
              title: 'Email Us',
              value: _email,
              onTap: () => _launch(
                context,
                Uri.parse(
                  'mailto:$_email?subject=${Uri.encodeComponent('Bill Berry Lite Support')}',
                ),
              ),
            ),

            SizedBox(height: 28),
            _sectionTitle(context, 'Frequently Asked'),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            ..._faqs.map((f) => _faqTile(context, f)),
          ],
        ),
      ),
    );
  }

  // ── Hero banner ──────────────────────────────────────────────────────
  Widget _heroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: AppResponsive.largeSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'re here to help',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Reach our support team or browse common questions below.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.subheadingFontSize(context),
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ── Contact card ─────────────────────────────────────────────────────
  Widget _contactCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
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
                    SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAQ ──────────────────────────────────────────────────────────────
  static const List<_Faq> _faqs = [
    _Faq(
      'How do I add products?',
      'Open Products from the dashboard, then tap Add Product. Set the selling price, barcode and stock there; a product can carry variants (size, colour) with their own price and stock.',
    ),
    _Faq(
      'How do I connect a thermal printer?',
      'Settings → Printing → Connect Printer, then pick Bluetooth, WiFi or USB. Once paired, use Printer Settings to set paper size and invoice layout.',
    ),
    _Faq(
      'How do I back up my data?',
      'Settings → Data Management → Backup & Restore. Backups are always encrypted, so set a backup password the first time.',
    ),
    _Faq(
      'How do I close the day (End of Day)?',
      'Settings → Day Management. Start Day sets the opening cash; End of Day counts the drawer, reviews the day\'s sales and settles it.',
    ),
    _Faq(
      'How do I process a return or exchange?',
      'Open Sales History, tap the bill, then choose Return or Exchange. Returns refund the selected lines; an exchange records the return and the replacement sale together.',
    ),
  ];

  Widget _faqTile(BuildContext context, _Faq faq) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            faq.q,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.a,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}
