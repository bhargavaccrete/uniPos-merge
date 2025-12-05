import 'package:country_code_picker/country_code_picker.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/data/models/restaurant/db/companymodel_301.dart';
import 'package:unipos/presentation/screens/restaurant/auth/login.dart';
import 'dart:io';
import '../dashboard.dart';
import 'package:hive/hive.dart';
import 'package:flutter/widgets.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
class Companyregister extends StatefulWidget {
  const Companyregister({super.key});

  @override
  State<Companyregister> createState() => _CompanyregisterState();
}

class _CompanyregisterState extends State<Companyregister> {
  DateTime? _fromDate;

  // Function to show the Date Picker
  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
      });
    }
  }

  final _fromKey = GlobalKey<FormState>();
  TextEditingController bussinessnameController = TextEditingController();
  TextEditingController ownernameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController alternatemobileController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController businesstypeController = TextEditingController();
  TextEditingController gstinController = TextEditingController();
  TextEditingController fssaiController = TextEditingController();
  TextEditingController panController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController pincodeController = TextEditingController();
  TextEditingController countryController = TextEditingController();

  // TextEditingController logoController = TextEditingController();
  TextEditingController dateregisterController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController Controller = TextEditingController();

  FocusNode businessFocus = FocusNode();
  FocusNode owenerFocus = FocusNode();
  FocusNode mobileFocus = FocusNode();
  FocusNode alternatemobileFocus = FocusNode();
  FocusNode emailFocus = FocusNode();
  FocusNode businesstypeFocus = FocusNode();
  FocusNode gstinFocus = FocusNode();
  FocusNode fssaiFocus = FocusNode();
  FocusNode pannumberFocus = FocusNode();
  FocusNode addressFocus = FocusNode();
  FocusNode cityFocus = FocusNode();
  FocusNode stateFocus = FocusNode();
  FocusNode pincodeFocus = FocusNode();
  FocusNode countryFocus = FocusNode();
  FocusNode dateregisterFocus = FocusNode();
  FocusNode passwordFocus = FocusNode();

  void _saveCompanyData()async{
    if(_fromKey.currentState!.validate()){
      final company = Company(
          comapanyName: bussinessnameController.text,
          ownerName: ownernameController.text,
          mobileNumber: mobileController.text,
          mobilenumberaltr:alternatemobileController.text,
          email: emailController.text,
          btype: businesstypeController.text,
          gst: gstinController.text,
          fssai: fssaiController.text,
          country: countryController.text,
          state: stateController.text,
          city: cityController.text,
          pincode: pincodeController.text,
          dateofreg: dateregisterController.text,
          pass: passwordController.text,
          address: addressController.text);
      final box = Hive.box('companyBox');

      await box.clear();
      await box.add(company);
      dispose();
      Navigator.push(context, MaterialPageRoute(builder: (context)=> loginScreen()));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Company data saved')),
      );
    }
  }

  void dispose() {
    bussinessnameController.dispose();
    ownernameController.dispose();
    mobileController.dispose();
    alternatemobileController.dispose();
     emailController.dispose();
     businesstypeController.dispose();
     gstinController.dispose();
     fssaiController.dispose();
     panController.dispose();
     addressController.dispose();
     cityController.dispose();
     stateController.dispose();
     pincodeController.dispose();
     countryController.dispose();
  }







  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    // final width = MediaQuery.of(context).size.width * 1;
    final size = MediaQuery.of(context).size;
    final width = size.width;

    bool forMobile = width < 600;
    bool fortablet = width >= 600 && width < 1024;
    bool fordesktop = width >= 1024;

    double iconSize = forMobile
        ? 24
        : fortablet
            ? 36
            : 48;
    double title = forMobile
        ? 16
        : fortablet
            ? 20
            : 26;
    double padding = forMobile
        ? 12
        : fortablet
            ? 20
            : 32;
    double spaceing = forMobile ? 5 : 20;
    double forfont = forMobile ? 16: fortablet? 15 : 35;

    ValueNotifier obsecurepass = ValueNotifier(true);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        backgroundColor: primarycolor,
        centerTitle: true,
        title: Text(
          'Business Registration',
          textScaler: TextScaler.linear(1.2),
          style: GoogleFonts.poppins(
              fontSize: forfont,
              fontWeight: FontWeight.w500,
              color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Column(
            children: [

              Form(
                  key: _fromKey,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        RichText(
                          text: TextSpan(
                              text: 'Business Name',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black),
                              children: [
                                TextSpan(
                                    text: ' *',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold))
                              ]),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        CommonTextForm(
                          controller: bussinessnameController,
                          focusNode: businessFocus,
                          borderc: 5,
                          obsecureText: false,
                          hintText: ' Enter Business Name',
                          HintColor: Colors.grey.shade500,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "please Enter Business Name";
                            }
                          },
                          onfieldsumbitted: (value) {
                            FocusScope.of(context).requestFocus(owenerFocus);
                          },
                        ),
                        SizedBox(
                          height: forfont,
                        ),

                        // owner name
                        RichText(
                          text: TextSpan(
                              text: 'Owner Name',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black),
                              children: [
                                TextSpan(
                                    text: ' *',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold))
                              ]),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        CommonTextForm(
                          controller: ownernameController,
                          focusNode: owenerFocus,
                          borderc: 5,
                          obsecureText: false,
                          hintText: 'Enter Owner Name',
                          HintColor: Colors.grey.shade500,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "please Enter Owner Name";
                            }
                          },
                          onfieldsumbitted: (value) {
                            FocusScope.of(context).requestFocus(mobileFocus);
                          },
                        ),
                        SizedBox(
                          height: forfont,
                        ),

                        // mobile Number
                        RichText(
                            text: TextSpan(
                                text: 'Mobile Number',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black),
                                children: [
                              TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ))
                            ])),
                        SizedBox(
                          height: 5,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            children: [
                              CountryCodePicker(
                                onChanged: (conuntry) {
                                  print(
                                      "selected country:${conuntry.dialCode}");
                                },
                                initialSelection: 'IN',
                                showCountryOnly: false,
                                showOnlyCountryWhenClosed: false,
                                alignLeft: false,
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                  child: TextFormField(
                                    decoration:
                                    InputDecoration(border: InputBorder.none),
                                    keyboardType: TextInputType.number,
                                    controller: mobileController,
                                    focusNode: mobileFocus,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Enter the Mobile Number";
                                      }
                                    },
                                    onFieldSubmitted: (value) {
                                      FocusScope.of(context)
                                          .requestFocus(emailFocus);
                                    },
                                  )),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),

                        // alternate
                        Text(
                          ' Alternate Mobile Number',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            children: [
                              CountryCodePicker(
                                onChanged: (conuntry) {
                                  print(
                                      "selected country:${conuntry.dialCode}");
                                },
                                initialSelection: 'IN',
                                showCountryOnly: false,
                                showOnlyCountryWhenClosed: false,
                                alignLeft: false,
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                  child: TextFormField(
                                decoration:
                                    InputDecoration(border: InputBorder.none),
                                keyboardType: TextInputType.number,
                                controller: alternatemobileController,
                                focusNode: alternatemobileFocus,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Enter the Mobile Number";
                                  }
                                },
                                onFieldSubmitted: (value) {
                                  FocusScope.of(context)
                                      .requestFocus(emailFocus);
                                },
                              )),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: forfont,
                        ),

                        // email
                        RichText(
                            text: TextSpan(
                                text: 'Email Address',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                              TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold))
                            ])),
                        SizedBox(
                          height: 5,
                        ),
                        CommonTextForm(
                          controller: emailController,
                          focusNode: emailFocus,
                          borderc: 5,
                          obsecureText: false,
                          hintText: 'Enter Email Address',
                          HintColor: Colors.grey.shade500,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please Enter Email Address";
                            }
                          },
                          onfieldsumbitted: (value) {
                            FocusScope.of(context)
                                .requestFocus(businesstypeFocus);
                          },
                        ),

                        SizedBox(
                          height: forfont,
                        ),

                        // businesstype
                        RichText(
                            text: TextSpan(
                                text: 'Business Type',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                              TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red))
                            ])),
                        SizedBox(
                          height: 5,
                        ),
                        CommonTextForm(
                          controller: businesstypeController,
                          focusNode: businesstypeFocus,
                          borderc: 5,
                          obsecureText: false,
                          hintText: 'Enter Business Type',
                          HintColor: Colors.grey.shade500,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "please Enter Business Type";
                            }
                          },
                          onfieldsumbitted: (value) {
                            FocusScope.of(context).requestFocus(gstinFocus);
                          },
                        ),
                        SizedBox(
                          height: forfont,
                        ),

                        // gst
                        Text(
                          'Gstin',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        CommonTextForm(
                          controller: gstinController,
                          focusNode: gstinFocus,
                          borderc: 5,
                          obsecureText: false,
                          hintText: 'Enter Gst Identification Number',
                          HintColor: Colors.grey.shade500,
                          onfieldsumbitted: (value) {
                            FocusScope.of(context).requestFocus(fssaiFocus);
                          },
                        ),
                        SizedBox(
                          height: forfont,
                        ),

                        // fssai
                        Text(
                          'Fssai Number',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        CommonTextForm(
                          controller: fssaiController,
                          focusNode: fssaiFocus,
                          borderc: 5,
                          obsecureText: false,
                          hintText: 'Enter Fssai Number',
                          HintColor: Colors.grey.shade500,
                          onfieldsumbitted: (value) {
                            FocusScope.of(context).requestFocus(countryFocus);
                          },
                        ),
                        SizedBox(
                          height: forfont,
                        ),

                        // fssai
                        Text(
                          'Country',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        CommonTextForm(
                          controller: countryController,
                          focusNode: countryFocus,
                          borderc: 5,
                          obsecureText: false,
                          hintText: 'Enter Country  ',
                          HintColor: Colors.grey.shade500,
                          onfieldsumbitted: (value) {
                            FocusScope.of(context).requestFocus(countryFocus);
                          },
                        ),
                        SizedBox(
                          height: forfont,
                        ),

                        RichText(
                            text: TextSpan(
                                text: "Address",
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w400),
                                children: [
                              TextSpan(
                                  text: '*',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold))
                            ])),
                        SizedBox(
                          height: 5,
                        ),
                        CommonTextForm(
                          controller: addressController,
                          focusNode: addressFocus,
                          borderc: 5,
                          obsecureText: false,
                          hintText: 'Enter Address',
                          HintColor: Colors.grey.shade500,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "please Enter Address";
                            }
                          },
                          onfieldsumbitted: (value) {
                            FocusScope.of(context).requestFocus(cityFocus);
                          },
                        ),
                        SizedBox(
                          height: forfont,
                        ),

                        // city and state
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // city
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                      text: TextSpan(
                                          text: "State",
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w400),
                                          children: [
                                        TextSpan(
                                            text: '*',
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold))
                                      ])),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  // city
                                  Container(
                                    width: width * 0.4,
                                    child: CommonTextForm(
                                      controller: cityController,
                                      focusNode: cityFocus,
                                      borderc: 5,
                                      obsecureText: false,
                                      hintText: 'Enter State',
                                      HintColor: Colors.grey.shade500,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return "please Enter State";
                                        }
                                      },
                                      onfieldsumbitted: (value) {
                                        FocusScope.of(context)
                                            .requestFocus(cityFocus);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // state
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                      text: TextSpan(
                                          text: "City",
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w400),
                                          children: [
                                        TextSpan(
                                            text: '*',
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold))
                                      ])),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  Container(
                                    width: width * 0.45,
                                    child: CommonTextForm(
                                      controller: stateController,
                                      focusNode: stateFocus,
                                      borderc: 5,
                                      obsecureText: false,
                                      hintText: 'Enter City',
                                      HintColor: Colors.grey.shade500,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return "please Enter City";
                                        }
                                      },
                                      onfieldsumbitted: (value) {
                                        FocusScope.of(context)
                                            .requestFocus(pincodeFocus);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: forfont,
                        ),

                        // Pincode
                        RichText(
                            text: TextSpan(
                                text: "Pincode",
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w400),
                                children: [
                              TextSpan(
                                  text: '*',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold))
                            ])),
                        SizedBox(
                          height: 5,
                        ),
                        Container(
                          width: width ,
                          child: CommonTextForm(
                            controller: pincodeController,
                            focusNode: pincodeFocus,
                            borderc: 5,
                            obsecureText: false,
                            hintText: 'Enter Pincode',
                            keyboardType: TextInputType.number,
                            HintColor: Colors.grey.shade500,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "please Enter Pincode";
                              }
                            },
                            onfieldsumbitted: (value) {
                              FocusScope.of(context).requestFocus();
                            },
                          ),
                        ),

                        SizedBox(
                          height: forfont,
                        ),

                        // Logo Upload Placeholder
                        Text(
                          'Select Logo',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        Container(
                          padding: EdgeInsets.all(16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.image, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text("Upload Logo (Optional)",
                                  style: GoogleFonts.poppins()),
                            ],
                          ),
                        ),

                        SizedBox(
                          height: forfont,
                        ),

                        // date
                        RichText(
                            text: TextSpan(
                                text: "Date Of Registration",
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w400),
                                children: [
                              TextSpan(
                                  text: '*',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold))
                            ])),
                        SizedBox(
                          height: 5,
                        ),
                        InkWell(
                          onTap: () {
                            _pickDate(context);
                          },
                          child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              // width: width * 0.6,
                              height: height * 0.09,
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  // color: Colors.red,
                                  borderRadius: BorderRadius.circular(5)),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _fromDate == null
                                        ? ' DD/MM/YYYY'
                                        : '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}',
                                  ),
                                  Icon(Icons.date_range)
                                ],
                              )),
                        ),

                        SizedBox(
                          height: forfont,
                        ),

                        // password
                        RichText(
                            text: TextSpan(
                                text: "Password / Pin",
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w400),
                                children: [
                              TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold))
                            ])),
                        SizedBox(
                          height: 5,
                        ),
                        Container(
                          width: width ,
                          child: CommonTextForm(
                            controller: passwordController,
                            focusNode: passwordFocus,
                            borderc: 5,
                            obsecureText: false,
                            hintText: 'Enter Password/PIN',
                            HintColor: Colors.grey.shade500,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "please Enter Password or PIN";
                              }
                            },
                            onfieldsumbitted: (value) {
                              FocusScope.of(context).requestFocus();
                            },
                          ),
                        ),
                        SizedBox(
                          height: 25,
                        ),
                        CommonButton(
                          height: height * 0.08,
                          width: width,
                          onTap:(){
                            print('button pressed');
                            _saveCompanyData();
                          },
                          child: Center(
                            child: Text(
                              'submit',
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 18),
                            ),
                          ),
                          bgcolor: primarycolor,
                        ),
                      ],
                    ),
                  ))
            ],
          ),
        ),
      ),
    );
  }
}
