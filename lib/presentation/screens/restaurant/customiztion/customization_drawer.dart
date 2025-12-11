import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Or wherever AppSettings is located
import 'package:flutter/widgets.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/startorder.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/togglelist.dart';
import 'package:unipos/util/restaurant/staticswitch.dart';

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
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    // Use a ListenableBuilder to listen for changes in AppSettings
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primarycolor,
        automaticallyImplyLeading: false,
        leading: InkWell(
            onTap: (){
              Navigator.push(context, MaterialPageRoute(builder: (context)=> Startorder()));
            },
            child: Icon(Icons.arrow_back)),
        title:  Text('Setting & Customization',style: GoogleFonts.poppins(color: Colors.white,fontSize:  16, fontWeight: FontWeight.w600),),
      ),
      // body: ListenableBuilder(
      //   listenable: AppSettings.settingsNotifier,
      //   builder: (context, child) {
      //     final setting = AppSettings.values;
      //     // This builder will re-run whenever a setting is changed.
      //     return SingleChildScrollView(
      //       padding: const EdgeInsets.all(10),
      //       child: Column(
      //         mainAxisSize: MainAxisSize.min,
      //         // Build the list from the static AppSettings values
      //         children: AppSettings.groupedSettings.entries.map((group) {
      //           final groupTitle = group.key;
      //           final settingKeys = group.value;
      //
      //           return Padding(
      //             padding: const EdgeInsets.all(8.0),
      //             child: Container(
      //               width: width,
      //               child: SwitchList(
      //                 heightconatiner: height * 0.07,
      //                 fontsize: 10,
      //                 title: entry.key,
      //                 isvalue: entry.value, // Get the current value
      //                 onChanged: (bool newValue) {
      //                   // Update the setting in the static class
      //                   AppSettings.updateSetting(entry.key, newValue);
      //                   setState(() {
      //
      //                   });
      //                 },
      //               ),
      //             ),
      //           );
      //         }).toList(),
      //       ),
      //     );
      //   },
      // ),
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
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primarycolor
                          ),
                        ),
                      ),
                    ),
                    Divider(),
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
