import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

class CustomizationDrawer extends StatefulWidget {
  const CustomizationDrawer({super.key});

  @override
  State<CustomizationDrawer> createState() => _CustomizationDrawerState();
}

class _CustomizationDrawerState extends State<CustomizationDrawer> {
  // Icon + description per setting key (fallbacks used for unknown keys).
  static const Map<String, IconData> _icons = {
    'Item Image': Icons.image_outlined,
    'Item Price': Icons.sell_outlined,
    'Menu Grid View': Icons.grid_view_rounded,
    'Keep Categories Open': Icons.unfold_more_rounded,
    'Round Off': Icons.calculate_outlined,
    'Visual Keyboard': Icons.keyboard_outlined,
    'Generate KOT': Icons.receipt_long_outlined,
    'Tax Is Inclusive': Icons.percent_rounded,
    'Low Stock Alerts': Icons.inventory_2_outlined,
  };

  static const Map<String, String> _descriptions = {
    'Item Image': 'Show item photos in the menu grid',
    'Item Price': 'Show price on menu items',
    'Menu Grid View': 'Show menu items as a grid instead of a list',
    'Keep Categories Open': "Opening a category won't close the others (list view)",
    'Round Off': 'Round bill totals to the nearest value',
    'Visual Keyboard': 'On-screen number pad for inputs',
    'Generate KOT': 'Auto-print kitchen order tickets',
    'Tax Is Inclusive': 'Item prices already include tax',
    'Low Stock Alerts': 'Notify when item stock runs low',
  };

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Personalization',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Customize menu display & behavior',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.9),
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: AppSettings.settingsNotifier,
        builder: (context, child) {
          final settings = AppSettings.values;

          return Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: isTablet ? 700 : double.infinity),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                   /* _infoBanner(isTablet),
                    const SizedBox(height: 24),*/
                    ...AppSettings.groupedSettings.entries.map((group) {
                      return _buildSettingGroup(
                          group.key, group.value, settings, isTablet);
                    }),
                    const SizedBox(height: 8),
                    _autoSaveFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Info banner ──────────────────────────────────────────────────────────
/*  Widget _infoBanner(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize Your App',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 15 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toggle options to control menu display, ordering and inventory behavior',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }*/

  // ── Group ────────────────────────────────────────────────────────────────
  Widget _buildSettingGroup(String groupTitle, List<String> keys,
      Map<String, bool> settings, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header — accent bar + label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                groupTitle,
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 17 : 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),

        // Cards
        ...keys.where((key) {
          // "Keep Categories Open" only applies to the LIST menu — hide it when
          // grid view is on (grid has no expandable categories).
          if (key == 'Keep Categories Open' &&
              (settings['Menu Grid View'] ?? false)) {
            return false;
          }
          return true;
        }).map((key) {
          final isEnabled = settings[key] ?? false;
          return _settingCard(key, isEnabled, isTablet);
        }),

        const SizedBox(height: 20),
      ],
    );
  }

  // ── Setting card ─────────────────────────────────────────────────────────
  Widget _settingCard(String key, bool isEnabled, bool isTablet) {
    final icon = _icons[key] ?? Icons.tune_rounded;
    final description = _descriptions[key] ?? '';
    final showChild = key == 'Round Off' && isEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.divider,
          width: isEnabled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnabled
                ? AppColors.primary.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: isEnabled ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => AppSettings.updateSetting(key, !isEnabled),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 16 : 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.surfaceMedium,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: isEnabled
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            key,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 15 : 14,
                              fontWeight: FontWeight.w600,
                              color: isEnabled
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              description,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.9,
                      child: Switch(
                        value: isEnabled,
                        onChanged: (v) => AppSettings.updateSetting(key, v),
                        activeColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Round Off value picker — shown only when Round Off is on.
          if (showChild) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  isTablet ? 16 : 14, 12, isTablet ? 16 : 14, 14),
              child: _buildRoundOffDropdown(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoundOffDropdown() {
    const options = ['0.50', '1.00', '5.00', '10.00'];
    return ValueListenableBuilder<String>(
      valueListenable: AppSettings.roundOffNotifier,
      builder: (context, currentValue, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Round off to nearest',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((value) {
                final selected = currentValue == value;
                return GestureDetector(
                  onTap: () => AppSettings.updateRoundOffValue(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.divider,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  // ── Auto-save footer ───────────────────────────────────────────────────────
  Widget _autoSaveFooter() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMedium,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text(
              'Settings auto-save',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
