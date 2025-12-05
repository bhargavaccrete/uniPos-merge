import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';


class ExtraTabex extends StatefulWidget {
  const ExtraTabex({super.key});




  @override
  State<ExtraTabex> createState() => _ExtraTabexState();
}

class _ExtraTabexState extends State<ExtraTabex> {
  List<String> extras = [];
  List<String> toping = [];

  int? editingIndex;
  int? editingtIndex;

  void addOrEditExtra() {
    final name = ExtrasController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      if (editingIndex != null) {
        extras[editingIndex!] = name;
        editingIndex = null;
      } else {
        extras.add(name);
      }
      ExtrasController.clear();
    });
    Navigator.pop(context);
  }
void addtopingoredit() {
    final name = ToppingController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      if (editingtIndex != null) {
        toping[editingtIndex!] = name;
        editingtIndex = null;
      } else {
        toping.add(name);
      }
     ToppingController.clear();
    });
    Navigator.pop(context);
  }

  void openBottomSheet({int? index}) {
    if (index != null) {
      ExtrasController.text = extras[index];
      editingIndex = index;
    } else {
      ExtrasController.clear();
      editingIndex = null;
    }
    showModalBottomSheet(
        context: context,
        builder: (context) => Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: showmodel(),
            ));
  }
void openBottomSheettoping({int? index}) {
    if (index != null) {
      ToppingController.text = toping[index];
      editingtIndex = index;
    } else {
      ToppingController.clear();
      editingtIndex = null;
    }

  }

  TextEditingController ExtrasController = TextEditingController();
  TextEditingController ToppingController = TextEditingController();
  TextEditingController PriceController = TextEditingController();
  bool Cveg = false;
bool check = false;
bool checktoping = false;
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              extras.isEmpty
                  ? Container(
                      height: height * 0.7,
                      // color: Colors.red,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset(
                              'assets/animation/notfoundanimation.json',
                              height: height * 0.3),
                          Text(
                            'No Extras Found',
                            style: GoogleFonts.poppins(
                                fontSize: 20, fontWeight: FontWeight.w500),
                          )
                        ],
                      ),
                    )
                  : Container(
                      height: height * 0.7,
                      child: ListView.builder(
                          itemCount: extras.length,
                          itemBuilder: (context, index) {
                            return Card(
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(
                                      extras[index],
                                      style: GoogleFonts.poppins(fontSize: 16),
                                    ),
                                    // trailing:
                                    trailing: Container(
                                      width: 60,
                                      child: Row(
                                        children: [

                                          // edit
                                          InkWell(
                                              onTap: () =>
                                                  openBottomSheet(index: index),
                                              child: Container(
                                                  padding: EdgeInsets.all(1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                    // shape:BoxShape.circle,
                                                  ),
                                                  child: Icon(Icons.edit))),
                                          SizedBox(
                                            width: 5,
                                          ),
                                          // delete
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
                                                              color:
                                                                  primarycolor,
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
                                                                      fontSize:
                                                                          12),
                                                            ),
                                                            SizedBox(
                                                              height: 10,
                                                            ),
                                                            Container(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(10),
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
                                                                          Navigator.pop(
                                                                              context);
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
                                                                          setState(
                                                                              () {
                                                                            extras.removeAt(index);
                                                                            Navigator.pop(context);
                                                                          });
                                                                        },
                                                                        child: Text(
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
                                                          BorderRadius.circular(
                                                              5)),
                                                  child: Icon(Icons.delete,
                                                      color: Colors.white)))
                                        ],
                                      ),
                                    ),
                                  ),
                                  Divider(),

                                  toping.isEmpty?SizedBox():
SizedBox(
  height: height * 0.05,
  child: ListView.builder(
      itemCount: toping.length,
      itemBuilder: (context ,index){
       return Container(
          // color: Colors.green,
          padding: EdgeInsets.all(10),
          height:  height * 0.05,
          child: ListView.builder(
              itemCount: toping.length,
              itemBuilder: (context, index){
                return Container(
                  // color: Colors.red,
                  // height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Checkbox(value: checktoping,
                      //     onChanged:(value){
                      //   checktoping = value!;
                      //     }),
                      // SizedBox(width: 5,),
                      Text(toping[index]),

                      Row(children: [
                        Icon(Icons.edit),
                        Icon(Icons.delete)
                      ],)
                    ],
                  ),
                );
              }),
        );

  }),
),

                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: CommonButton(
                                      width: width * 0.8,
                                      height: height * 0.06,
                                      bordercircular: 5,
                                      bordercolor: primarycolor,
                                      bgcolor: Colors.white,
                                      child: Text(
                                        'Add Topping Names',
                                        style: GoogleFonts.poppins(
                                            color: primarycolor),
                                      ),
                                      onTap: () {
                                        openBottomSheettoping();
                                        showModalBottomSheet(
                                            context: context,
                                            builder: (context) {
                                              bool Cveg = false;
                                              return StatefulBuilder(builder:
                                                  (BuildContext context,
                                                      StateSetter
                                                          setModalState) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.all(15),
                                                  child: Container(
                                                    height: height * 0.4,
                                                    // padding: EdgeInsets.all(10),
                                                    child: Column(
                                                      // mainAxisAlignment: MainAxisAlignment.start,
                                                      // crossAxisAlignment:
                                                      //     CrossAxisAlignment
                                                      //         .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Add Extras',
                                                              style: GoogleFonts.poppins(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400),
                                                            ),
                                                            Icon(Icons.cancel)
                                                          ],
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        RichText(
                                                          textAlign: TextAlign.start,
                                                          text: TextSpan(
                                                              text:
                                                                  'Extra Category:',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          16),
                                                              children: [
                                                                TextSpan(
                                                                    text:
                                                                        extras[index],
                                                                    style: GoogleFonts.poppins(
                                                                        color:
                                                                            primarycolor,
                                                                        fontSize:
                                                                            16))
                                                              ]),
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        TextField(
                                                          controller:
                                                              ToppingController,
                                                          decoration:
                                                              InputDecoration(
                                                            focusColor:
                                                                Colors.red,
                                                            focusedBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            2)),
                                                            labelStyle:
                                                                GoogleFonts
                                                                    .poppins(
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                            border:
                                                                OutlineInputBorder(),
                                                            labelText:
                                                                "Extra Name ",
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: InkWell(
                                                                onTap: () {
                                                                  setModalState(
                                                                      () {
                                                                    Cveg = true;
                                                                  });
                                                                },
                                                                child:
                                                                    Container(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  width: width *
                                                                      0.4,
                                                                  height:
                                                                      height *
                                                                          0.06,
                                                                  padding:
                                                                      EdgeInsets
                                                                          .all(
                                                                              5),
                                                                  decoration: BoxDecoration(
                                                                      border: Border.all(
                                                                          color: Cveg
                                                                              ? primarycolor
                                                                              : Colors.grey)),
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Container(
                                                                          decoration: BoxDecoration(
                                                                              color: Colors.white,
                                                                              border: Border.all(color: Colors.green)),
                                                                          child: Icon(
                                                                            Icons.circle,
                                                                            color:
                                                                                Colors.green,
                                                                          )),
                                                                      SizedBox(
                                                                        width:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'Veg',
                                                                        style: GoogleFonts.poppins(
                                                                            fontSize:
                                                                                16),
                                                                      ),
                                                                      if (Cveg) ...[
                                                                        SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        Container(
                                                                            decoration:
                                                                                BoxDecoration(color: primarycolor, shape: BoxShape.circle),
                                                                            child: Icon(
                                                                              Icons.check,
                                                                              color: Colors.white,
                                                                              size: 25,
                                                                            ))
                                                                      ]
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 10,
                                                            ),
                                                            Expanded(
                                                              child: InkWell(
                                                                onTap: () {
                                                                  setModalState(
                                                                      () {
                                                                    Cveg =
                                                                        false;
                                                                  });
                                                                },
                                                                child:
                                                                    Container(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  width: width *
                                                                      0.4,
                                                                  height:
                                                                      height *
                                                                          0.06,
                                                                  padding:
                                                                      EdgeInsets
                                                                          .all(
                                                                              5),
                                                                  decoration: BoxDecoration(
                                                                      border: Border.all(
                                                                          color: !Cveg
                                                                              ? primarycolor
                                                                              : Colors.grey)),
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Container(
                                                                          decoration: BoxDecoration(
                                                                              color: Colors.white,
                                                                              border: Border.all(color: Colors.red)),
                                                                          child: Icon(
                                                                            Icons.circle,
                                                                            color:
                                                                                Colors.red,
                                                                          )),
                                                                      SizedBox(
                                                                        width:
                                                                            5,
                                                                      ),
                                                                      Text(
                                                                        'Non-Veg',
                                                                        style: GoogleFonts.poppins(
                                                                            fontSize:
                                                                                16),
                                                                      ),
                                                                      if (!Cveg) ...[
                                                                        SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        Container(
                                                                            decoration:
                                                                                BoxDecoration(color: primarycolor, shape: BoxShape.circle),
                                                                            child: Icon(
                                                                              Icons.check,
                                                                              color: Colors.white,
                                                                              size: 25,
                                                                            ))
                                                                      ]
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        Row(
                                                          children: [
                                                            Checkbox(value: check,
                                                                onChanged: (value){
                                                              setModalState(() {
                                                                check = value!;
                                                              });
                                                                }),

                                                            Text('Contains Size',style: GoogleFonts.poppins(fontSize: 14),),



                                                          ],
                                                        ),

                                                        TextField(
                                                          controller:
                                                          PriceController,
                                                          decoration:
                                                          InputDecoration(
                                                            focusColor:
                                                            Colors.red,
                                                            focusedBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                    2)),
                                                            labelStyle:
                                                            GoogleFonts
                                                                .poppins(
                                                              color:
                                                              Colors.grey,
                                                            ),
                                                            border:
                                                            OutlineInputBorder(),
                                                            labelText:
                                                            "Add Price",
                                                          ),
                                                        ),

                                                        SizedBox(height: 20,),
                                                        CommonButton(
                                                            width: width * 0.3,
                                                            height:  height * 0.05,
                                                            onTap: addtopingoredit,
                                                            child: Text('Save',style: GoogleFonts.poppins(color: Colors.white),))
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              });
                                            });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                    ),
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
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          'Add Extras',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 16),
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

  Widget showmodel() {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        height: height * 0.35,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: width * 0.5,
                  child: Text(
                    editingIndex == null
                        ? 'Add Extras Category'
                        : 'Edit Extra Category ',
                    textScaler: TextScaler.linear(1),
                    textAlign: TextAlign.start,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.cancel, color: Colors.grey))
              ],
            ),
            SizedBox(
              height: 20,
            ),
            Container(
              height: height * 0.06,
              child: TextField(
                controller: ExtrasController,
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2)),
                  labelStyle: GoogleFonts.poppins(
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(),
                  labelText: "Extra Category Name (English)",
                ),
              ),
            ),
            SizedBox(
              height: 20,
            ),
            CommonButton(
                bordercircular: 10,
                height: height * 0.05,
                width: width * 0.5,
                onTap: addOrEditExtra,
                child: Center(
                    child: Text(
                  'Add',
                  style: GoogleFonts.poppins(color: Colors.white),
                )))
          ],
        ),
      ),
    );
  }
}