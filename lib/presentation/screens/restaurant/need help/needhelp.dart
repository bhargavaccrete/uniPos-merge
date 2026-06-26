import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

class NeedhelpDrawer extends StatelessWidget {
  const NeedhelpDrawer({super.key});

  // ── Placeholder support details (swap with real ones later) ──────────
  static const String _phone = '+91 1234567890';
  static const String _email = 'support@billberry.com';
  static const String _telegram = 'BillBerrySupport';

  Future<void> _launch(BuildContext context, Uri uri) async {
    // Capture before the await — context may unmount across the async gap.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No app available to handle this action')),
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
      appBar: buildPrimaryAppBar(
        title: 'Need Help?',
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroBanner(),
            const SizedBox(height: 24),

            _sectionTitle('Contact Us'),
            const SizedBox(height: 12),
            _contactCard(
              context: context,
              icon: Icons.call_rounded,
              color: const Color(0xFF2E7D32),
              title: 'Call Support',
              value: _phone,
              onTap: () => _launch(context, Uri.parse('tel:${_digits(_phone)}')),
            ),
            const SizedBox(height: 12),
            _contactCard(
              context: context,
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366),
              title: 'WhatsApp',
              value: _phone,
              onTap: () => _launch(context, Uri.parse('https://wa.me/${_digits(_phone)}')),
            ),
            const SizedBox(height: 12),
            _contactCard(
              context: context,
              icon: Icons.send_rounded,
              color: const Color(0xFF229ED9),
              title: 'Telegram',
              value: '@$_telegram',
              onTap: () => _launch(context, Uri.parse('https://t.me/$_telegram')),
            ),
            const SizedBox(height: 12),
            _contactCard(
              context: context,
              icon: Icons.mail_rounded,
              color: const Color(0xFFD84315),
              title: 'Email Us',
              value: _email,
              onTap: () => _launch(
                context,
                Uri.parse('mailto:$_email?subject=${Uri.encodeComponent('Bill Berry Lite Support')}'),
              ),
            ),

            const SizedBox(height: 28),
            _sectionTitle('Frequently Asked'),
            const SizedBox(height: 12),
            ..._faqs.map(_faqTile),
          ],
        ),
      ),
    );
  }

  // ── Hero banner ──────────────────────────────────────────────────────
  Widget _heroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'re here to help',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reach our support team or browse common questions below.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAQ ──────────────────────────────────────────────────────────────
  static const List<_Faq> _faqs = [
    _Faq(
      'How do I back up my data?',
      'Open the side drawer → Import/Export → Download Backup. Backups are always encrypted, so set a backup password the first time.',
    ),
    _Faq(
      'How do I add or edit menu items?',
      'From the Dashboard, tap Manage Menu. You can add categories, items, variants, choices and extras there.',
    ),
    _Faq(
      'How do I connect a thermal printer?',
      'Open the drawer → Printer Settings → Add Printer, then select WiFi, Bluetooth or USB and assign it as the Billing or Kitchen printer.',
    ),
    _Faq(
      'How do I close the day (End of Day)?',
      'Tap End of Day on the Dashboard to count cash, review the day\'s sales and settle. New orders are blocked until a pending EOD is completed.',
    ),
  ];

  Widget _faqTile(_Faq faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
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
              fontSize: 13.5,
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
                  fontSize: 12.5,
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
