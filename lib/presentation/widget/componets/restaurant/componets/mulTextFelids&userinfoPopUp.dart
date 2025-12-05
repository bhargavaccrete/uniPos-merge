 
import 'package:flutter/material.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

import '../../../../../constants/restaurant/color.dart';
 

// this is for multiple text felids for the user
class textFelids extends StatelessWidget {
  final Color? textStyleColors;
  final Color? enabledBorderColor;
  final Color? focusedBorderColor;
  final TextEditingController? controller ;
 

  final String ?hintText;

   textFelids(
      {super.key,
      this.textStyleColors, 
       this.hintText,
       this.controller,
      this.enabledBorderColor,
      this.focusedBorderColor});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
        controller:controller,

      style: TextStyle(color: textStyleColors ?? Colors.black),
      decoration: InputDecoration(
          labelStyle: TextStyle(color: Colors.amber),
          hintStyle: TextStyle(color: primarycolor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: enabledBorderColor ?? primarycolor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: focusedBorderColor ?? primarycolor)),
          hintText: hintText),
    );

  }
}


class ShowInputData extends StatelessWidget {
  final Color? textStyleColors;
  final Color? enabledBorderColor;
  final Color? focusedBorderColor;
  final Text ? normalText;
  final String ?hintText;

  const ShowInputData(
      {super.key,
      this.textStyleColors,
      this.normalText,
       this.hintText,
      this.enabledBorderColor,
      this.focusedBorderColor});

  @override
  Widget build(BuildContext context) {
    return TextField(
        
      style: TextStyle(color: textStyleColors ?? Colors.black),
      decoration: InputDecoration(
          labelStyle: TextStyle(color: Colors.amber),
          hintStyle: TextStyle(color: primarycolor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: enabledBorderColor ?? primarycolor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: focusedBorderColor ?? primarycolor)),
          hintText: hintText),
    );

  }
}

//custom user info button for add staff 

class CustomUserInfoButton extends StatelessWidget {
  final String? userName;
  final String? mobileNumber;
  final String? email;
  final textFelids? multipleDdata;
  
   

  const CustomUserInfoButton({
    Key? key,
     this.userName,
     this.mobileNumber,
     this.email,
     this.multipleDdata,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: Icon(Icons.person, size: 30.0, color: primarycolor),
              
              title: Text("User Details", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Name: NAMES OF THE USER", style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text("Mobile: MOBILES NAMES ", style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text("Email: EMAILS OF THE DATA ", style: TextStyle(fontSize: 16)),
                ],
              ),
              actions: [
                CommonButton(
                  onTap:  () => Navigator.of(context).pop(),
                  child: Text("ADD", style: TextStyle(color: primarycolor, fontWeight: FontWeight.bold)),
                ),
                CommonButton(
                  bgcolor: primarycolor,
                  onTap:  () => Navigator.of(context).pop(),
                  child: Text("Close", style: TextStyle(color: primarycolor, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },

        );
      },
      icon: Icon(Icons.edit, color: primarycolor),
      label: Text("Edit"),
      style: ElevatedButton.styleFrom(
        backgroundColor: primarycolor,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

      ),
    );
  }
}

