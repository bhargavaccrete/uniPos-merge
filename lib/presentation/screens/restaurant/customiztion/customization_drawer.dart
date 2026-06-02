import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Or wherever AppSettings is located
import 'package:flutter/widgets.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/togglelist.dart';
import 'package:unipos/util/restaurant/staticswitch.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';

class CustomizationDrawer extends StatefulWidget {
  const CustomizationDrawer({super.key});

  @override
  State<CustomizationDrawer> createState() => _CustomizationDrawerState();
}

class _CustomizationDrawerState extends State<CustomizationDrawer> {
  // String? _selectedRoundOffValue = '0.50';
  // The local 'switchValues' map is no longer needed here.
//  / ✅ PASTE THE ENTIRE FUNCTION HERE
  Widget _buildRoundOffDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ValueListenableBuilder<String>(
          valueListenable: AppSettings.roundOffNotifier,
          builder: (contex , currentValue,child){
            return  DropdownButtonFormField<String>(
              value: currentValue,
              decoration: const InputDecoration(
                labelText: 'Round Off To Nearest',
                border: OutlineInputBorder(),
              ),
              items: ['0.50', '1.00', '5.00', '10.00']
                  .map((value) =>
                  DropdownMenuItem(
                    value: value,
                    child: Text('$value'),
                  ))
                  .toList(),
              onChanged: (newValue) {
                if(newValue != null){
                  AppSettings.updateRoundOffValue(newValue);
                }
                // 💡 Remember to save this value permanently if needed
              },
            );
          }),
    );
  }
  @override
  Widget build(BuildContext context) {
    // Use a ListenableBuilder to listen for changes in AppSettings
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: 'Setting & Customization',
        titleFontSize: AppResponsive.headingFontSize(context),
      ),
      body: ListenableBuilder(
        listenable: AppSettings.settingsNotifier,
        builder: (context, child) {
          final settings = AppSettings.values;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: AppSettings.groupedSettings.entries.map((group) {
                final groupTitle = group.key;
                final settingKeys = group.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Container(
                        // alignment: Alignment.center,
                        child: Text(
                          groupTitle,
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary
                          ),
                        ),
                      ),
                    ),
                    Divider(color: AppColors.divider),
                    ...settingKeys.map((key) {
                      final currentValue = settings[key] ?? false;

                      return SwitchList(
                        title: key,
                        isvalue: currentValue,
                        onChanged: (newValue) {
                          AppSettings.updateSetting(key, newValue);
                        },
                        fontsize: 14,
                        // --- This is the new conditional logic ---
                        // If the key is "Round Off" and it's on, pass the dropdown as a child.
                        // Otherwise, pass null, and no extra space will be taken.
                        child: (key == "Round Off" && currentValue)
                            ? _buildRoundOffDropdown()
                            : null,
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),

    );


  }
}
