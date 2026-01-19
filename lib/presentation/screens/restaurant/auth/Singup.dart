import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/screens/restaurant/auth/login.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:unipos/util/color.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _signUpState();
}

class _signUpState extends State<Signup> {
  bool ischecked = false;
  TextEditingController fullnameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController restaurantController = TextEditingController();
  TextEditingController mobileController = TextEditingController();

  final _fromKey = GlobalKey<FormState>();
  FocusNode nameFocus = FocusNode();
  FocusNode emailFocus = FocusNode();
  FocusNode restaurantFocus = FocusNode();
  FocusNode mobileFocus = FocusNode();

  @override
  Widget build(BuildContext content) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
        backgroundColor: AppColors.primary,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(150),
          child: AppBar(
            backgroundColor: AppColors.primary,
            automaticallyImplyLeading: false,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            title: SizedBox.shrink(),
            bottom: PreferredSize(
                preferredSize: Size.fromHeight(40),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      "signup",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 30),
                    ),
                  ),
                )),
            centerTitle: true,
          ),
        ),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: SingleChildScrollView(
              child: Form(
                  key: _fromKey,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Container(
                      width: width,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Full Name",
                                textScaler: TextScaler.linear(1.2),
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          CommonTextForm(
                            obsecureText: false,
                            focusNode: nameFocus,
                            controller: fullnameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "  Plase Provide A Name";
                              }
                            },
                            hintText: "Enter the Full Name",
                            onfieldsumbitted: (value) {
                              FocusScope.of(context).requestFocus(nameFocus);
                            },
                          ),
                          Center(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Email Address ",
                                textScaler: TextScaler.linear(1.2),

                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          CommonTextForm(
                            obsecureText: false,
                            focusNode: emailFocus,
                            controller: emailController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "plase Enter the Email";
                              } else if (!RegExp(
                                  r'^[\ -\.]+@([\w-]+\.)+[\w]{2,4}$')
                                  .hasMatch(value)) {
                                return "enter the valid email address";
                              }
                            },
                            hintText: "Enter the Email ",
                            onfieldsumbitted: (value) {
                              FocusScope.of(context).requestFocus(emailFocus);
                            },
                          ),
                          Center(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Resturant Name ",
                                textScaler: TextScaler.linear(1.2),
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          CommonTextForm(
                            obsecureText: false,
                            focusNode: restaurantFocus,
                            controller: restaurantController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please Enter the Restorunt Name";
                              }
                            },
                            hintText: "Enter the Retaurant Name",
                          ),
                          Center(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Enter the Phone number ",
                                textScaler: TextScaler.linear(1.2),
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(10),
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
                                        decoration: InputDecoration(
                                            border: InputBorder.none),
                                        keyboardType: TextInputType.number,
                                        controller: mobileController,
                                        focusNode: mobileFocus,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return "Enter the Mobile Number";
                                          }
                                        })),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Center(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Enter the Promo Code  (Optional) ",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          CommonTextForm(
                            hintText: "Enter the Promo Code",

                            obsecureText: false,
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              Checkbox(
                                  value: ischecked,
                                  onChanged: (value) {
                                    setState(() {
                                      ischecked = value!;
                                    });

                                  }),
                              SizedBox(
                                width: width * 0.75,
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Text(
                                    "I Allow to BillBerry to contect and email me to help me  grow  my bussiness online",
                                    style: GoogleFonts.poppins(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          //Contuniue button 
                          CommonButton(
                            onTap: () async {
                              if (_fromKey.currentState!.validate()) {
                                SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                                await prefs.setString(
                                    "fullname", fullnameController.text);
                                await prefs.setString(
                                    "email", emailController.text);
                                await prefs.setString(
                                    "mobile", mobileController.text);
                                await prefs.setString(
                                    "restaurant", restaurantController.text);
                              }
                            },
                            bgcolor: Colors.grey,
                            bordercolor: Colors.grey,
                            child: Text(
                              "Continue",
                              style:
                              TextStyle(color: Colors.white, fontSize: 20),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  textScaler: TextScaler.linear(1.2),
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => loginScreen()));
                                  },
                                  child: SizedBox(
                                    width: width * 0.2,
                                    child: Text(
                                      "SIGN IN",
                                      textScaler: TextScaler.linear(1.2),


                                      style: TextStyle(
                                          color: AppColors.primary, fontSize:16),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))),
        ));
  }
}
