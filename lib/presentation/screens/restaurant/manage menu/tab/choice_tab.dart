import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_choice.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/images.dart';
import 'package:uuid/uuid.dart';

class ChoiceTab extends StatefulWidget {
  const ChoiceTab({super.key});

  @override
  State<ChoiceTab> createState() => _ChoiceTabState();
}

class _ChoiceTabState extends State<ChoiceTab> {
  TextEditingController ChoiceController = TextEditingController();
  TextEditingController OptionController = TextEditingController();
  // List<ChoicesModel> choiceList = [];
  List<ChoiceOption> tempOptions = [];




  ChoicesModel? editingChoice;

  void openBottomSheet({ChoicesModel? choicemodel}) {
    setState(() {
      if (choicemodel != null) {
        ChoiceController.text = choicemodel.name;
        tempOptions = List<ChoiceOption>.from(choicemodel.choiceOption); // show existing options
        editingChoice = choicemodel;
      } else {
        ChoiceController.clear();
        OptionController.clear();
        tempOptions = []; // new list
        editingChoice = null;
      }
    });

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: showModel(),
      ),
    );
  }

  // add or edit
  Future<void> _addOrEditChoice(List<ChoiceOption> option) async {
    final trimmedName = ChoiceController.text.trim();

    //   Do Not procced if input is empty
    if (trimmedName.isEmpty) return;

    if (editingChoice != null) {
      final updateChoice = ChoicesModel(
        id: editingChoice!.id,
        name: trimmedName,
        choiceOption: option,
      );
      await HiveChoice.updateChoice(updateChoice);
    } else {
      final newchoice = ChoicesModel(id: Uuid().v4(), name: trimmedName, choiceOption: option);
      await HiveChoice.addChoice(newchoice);
    }
    ChoiceController.clear();
    OptionController.clear();
    editingChoice = null;

    Navigator.pop(context);
    // await loadHive();
  }

  // delete
  Future<void> _delete(ChoicesModel choice) async {
    await HiveChoice.deleteChoice(choice);
    Navigator.pop(context);

  }

  @override
  void dispose() {
    ChoiceController.dispose();
    OptionController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          // color: Colors.red,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),

          child: Column(
            children: [
              ValueListenableBuilder(
                  valueListenable: Hive.box<ChoicesModel>('choice').listenable(),
                  builder: (context, choicebox, _) {
                    final allchoice = choicebox.values.toList();

                    if (allchoice.isEmpty) {
                      return Container(
                        height: height * 0.7,
                        // color: Colors.red,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(notfoundanimation, height: height * 0.3),
                            Text(
                              'No Choices Found',
                              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500),
                            )
                          ],
                        ),
                      );
                    }
                    return Container(
                      height: height * 0.7,
                      child: ListView.builder(
                          itemCount: allchoice.length,
                          itemBuilder: (context, index) {
                            return Card(
                              child: ListTile(
                                title: Text(
                                  allchoice[index].name,
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                                // trailing:
                                trailing: Container(
                                  width: 60,
                                  child: Row(
                                    children: [
                                      InkWell(
                                          onTap: () => openBottomSheet(choicemodel: allchoice[index]),
                                          child: Container(
                                              padding: EdgeInsets.all(1),
                                              decoration: BoxDecoration(
                                                color: Colors.grey,
                                                borderRadius: BorderRadius.circular(5),
                                                // shape:BoxShape.circle,
                                              ),
                                              child: Icon(Icons.edit))),
                                      SizedBox(
                                        width: 5,
                                      ),
                                      InkWell(
                                          onTap: () {
                                            showModalBottomSheet(
                                                context: context,
                                                builder: (context) {
                                                  return Container(
                                                    height: height * 0.4,
                                                    width: double.infinity,
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          Icons.delete,
                                                          size: 100,
                                                          color: primarycolor,
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        Text(
                                                          'Delete choice',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: 5,
                                                        ),
                                                        Text(
                                                          'Are you sure you want to Delete this choice',
                                                          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        Container(
                                                          padding: EdgeInsets.all(10),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child: CommonButton(
                                                                    bordercircular: 5,
                                                                    height: 40,
                                                                    width: 30,
                                                                    bordercolor: Colors.grey,
                                                                    bgcolor: Colors.white,
                                                                    onTap: () {
                                                                      Navigator.pop(context);
                                                                    },
                                                                    child: Text('Cancel')),
                                                              ),
                                                              SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: CommonButton(
                                                                    bordercircular: 5,
                                                                    height: 40,
                                                                    width: 30,
                                                                    bordercolor: Colors.red,
                                                                    bgcolor: Colors.red,
                                                                    onTap: () {
                                                                      _delete(allchoice[index]);
                                                                    },
                                                                    child: Text(
                                                                      'Delete',
                                                                      style: GoogleFonts.poppins(color: Colors.white),
                                                                    )),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  );
                                                });
                                            // setState(() {
                                            //   variants.removeAt(index);
                                            // });
                                          },
                                          child: Container(
                                              padding: EdgeInsets.all(1),
                                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
                                              child: Icon(Icons.delete, color: Colors.white)))
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                    );
                  }),

              /*      choiceList.isEmpty?
              Container(
                height: height * 0.7,
                // color: Colors.red,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset('assets/animation/notfoundanimation.json',
                        height: height * 0.3),
                    Text(
                      'No Choices Found',
                      style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w500),
                    )
                  ],
                ),
              )
                  : Container(
                   height:  height * 0.7,
                   child: ListView.builder(
                     itemCount: choiceList.length,
                       itemBuilder: (context, index){
                       return
                         Card(
                           child:
                           ListTile(
                             title: Text(
                               choiceList[index].name,
                               style: GoogleFonts.poppins(fontSize: 16),
                             ),
                             // trailing:
                             trailing: Container(
                               width: 60,
                               child: Row(
                                 children: [
                                   InkWell(
                                       onTap: () =>
                                           openBottomSheet(index: index),
                                       child: Container(
                                           padding: EdgeInsets.all(1),
                                           decoration: BoxDecoration(
                                             color: Colors.grey,
                                             borderRadius:
                                             BorderRadius.circular(5),
                                             // shape:BoxShape.circle,
                                           ),
                                           child: Icon(Icons.edit))),
                                   SizedBox(
                                     width: 5,
                                   ),
                                   InkWell(
                                       onTap: () {
                                         showModalBottomSheet(
                                             context: context,
                                             builder: (context) {
                                               return Container(
                                                 height: height * 0.4,
                                                 width: double.infinity,
                                                 child: Column(
                                                   mainAxisAlignment:
                                                   MainAxisAlignment
                                                       .center,
                                                   children: [
                                                     Icon(
                                                       Icons.delete,
                                                       size: 100,
                                                       color: primarycolor,
                                                     ),
                                                     SizedBox(
                                                       height: 10,
                                                     ),
                                                     Text(
                                                       'Delete Variant',
                                                       style: GoogleFonts
                                                           .poppins(
                                                         fontSize: 16,
                                                       ),
                                                     ),
                                                     SizedBox(
                                                       height: 5,
                                                     ),
                                                     Text(
                                                       'Are you sure you want to Delete this Variante',
                                                       style: GoogleFonts
                                                           .poppins(
                                                           color: Colors
                                                               .grey,
                                                           fontSize: 12),
                                                     ),
                                                     SizedBox(
                                                       height: 10,
                                                     ),
                                                     Container(
                                                       padding:
                                                       EdgeInsets.all(
                                                           10),
                                                       child: Row(
                                                         children: [
                                                           Expanded(
                                                             child:
                                                             CommonButton(
                                                                 bordercircular:
                                                                 5,
                                                                 height:
                                                                 40,
                                                                 width:
                                                                 30,
                                                                 bordercolor:
                                                                 Colors
                                                                     .grey,
                                                                 bgcolor:
                                                                 Colors
                                                                     .white,
                                                                 onTap:
                                                                     () {
                                                                   Navigator.pop(
                                                                       context);
                                                                 },
                                                                 child: Text(
                                                                     'Cancel')),
                                                           ),
                                                           SizedBox(
                                                             width: 10,
                                                           ),
                                                           Expanded(
                                                             child:
                                                             CommonButton(
                                                                 bordercircular:
                                                                 5,
                                                                 height:
                                                                 40,
                                                                 width:
                                                                 30,
                                                                 bordercolor:
                                                                 Colors
                                                                     .red,
                                                                 bgcolor:
                                                                 Colors
                                                                     .red,
                                                                 onTap:
                                                                     () {
                                                                   _delete(
                                                                       index);
                                                                 },
                                                                 child:
                                                                 Text(
                                                                   'Delete',
                                                                   style:
                                                                   GoogleFonts.poppins(color: Colors.white),
                                                                 )),
                                                           ),
                                                         ],
                                                       ),
                                                     )
                                                   ],
                                                 ),
                                               );
                                             });
                                         // setState(() {
                                         //   variants.removeAt(index);
                                         // });
                                       },
                                       child: Container(
                                           padding: EdgeInsets.all(1),
                                           decoration: BoxDecoration(
                                               color: Colors.red,
                                               borderRadius:
                                               BorderRadius.circular(5)),
                                           child: Icon(Icons.delete,
                                               color: Colors.white)))
                                 ],
                               ),
                             ),
                           ),
                         );
                       }),
                 ) ,
              */

              Container(
                alignment: Alignment.center,
                child: CommonButton(
                    bordercircular: 30,
                    width: width * 0.5,
                    height: height * 0.06,
                    onTap: () => openBottomSheet(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          child: Icon(Icons.add),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          'Add Choices',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                        )
                      ],
                    )),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget showModel() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    // Grab the existing options if we're editing
    // final currentOptions = editingIndex != null
    //     ? List<ChoiceOption>.from(choiceList[editingIndex!].choiceOption)
    //     : <ChoiceOption>[];

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          height: height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    editingChoice != null ? 'Edit Choices' : 'Add Choices',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 10),

              // Choice Name field
              TextField(
                controller: ChoiceController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Choice Name (English)",
                ),
              ),
              SizedBox(height: 10),

              // Add Options row
              Row(
                children: [
                  Container(
                    width: width * 0.4,
                    child: TextField(
                      controller: OptionController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Add Options",
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: CommonButton(
                      borderwidth: 1,
                      bordercircular: 2,
                      height: height * 0.06,
                      bgcolor: Colors.white,
                      onTap: () {
                        final trimmed = OptionController.text.trim();
                        if (trimmed.isEmpty) return;

                        setState(() {
                          tempOptions.add(ChoiceOption(id: Uuid().v4(), name: trimmed));
                        });
                        OptionController.clear();
                      },
                      child: Center(
                        child: Text(
                          'Add More',
                          style: GoogleFonts.poppins(color: primarycolor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Saved options as chips
              if (tempOptions.isNotEmpty) ...[
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tempOptions.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final opt = entry.value;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(opt.name, style: GoogleFonts.poppins(fontSize: 14)),
                            SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  tempOptions.removeAt(idx);
                                });
                              },
                              child: Icon(Icons.delete, size: 18, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              Spacer(),

              // Save button
              Center(
                child: CommonButton(
                  bordercircular: 10,
                  height: height * 0.05,
                  width: width * 0.5,
                  // onTap: () async {
                  //   // Update your model with the new options list:
                  //   final trimmedName = ChoiceController.text.trim();
                  //   if (trimmedName.isEmpty) return;
                  //
                  //   final updated = ChoicesModel(
                  //     id: editingIndex != null
                  //         ? choiceList[editingIndex!].id
                  //         : Uuid().v4(),
                  //     name: trimmedName,
                  //     choiceOption: currentOptions,
                  //   );
                  //
                  //   if (editingIndex != null) {
                  //     await HiveChoice.updatechoice(updated);
                  //   } else {
                  //     await HiveChoice.addchoice(updated);
                  //   }
                  //
                  //   // Clear and reload
                  //   ChoiceController.clear();
                  //   OptionController.clear();
                  //   editingIndex = null;
                  //   Navigator.pop(context);
                  //   await loadHive();
                  // },
                  onTap: () => _addOrEditChoice(tempOptions),
                  child: Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
