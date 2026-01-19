// import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

import '../../../../../constants/restaurant/color.dart';

class CommonTextForm extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final void Function(String)? onfieldsumbitted;
  final void Function(String)? onChanged;
  final Widget? icon;
  final Widget? gesture;
  final String? hintText;
  final String? labelText;
  final Color? BorderColor;
  final Color? HintColor;
  final Color? LabelColor;
  final double? borderc;
  final int? maxline;
  final TextInputType? keyboardType;
  // final String? labelText;
  final bool obsecureText;
  final double? height;
  final double? width;
  final bool? enabled;
  const CommonTextForm(
      {super.key,
      this.controller,
        this.keyboardType,
      this.hintText,
      required this.obsecureText,
      this.validator, this.icon,  this.gesture, this.maxline,this.focusNode, this.onfieldsumbitted,
        this.onChanged,
        this.enabled,
        this.BorderColor, this.HintColor, this.borderc,
      this.height, this.width, this.labelText, this.LabelColor
      });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return TextFormField(
      enabled: enabled,
      maxLines: maxline?? 1,
      keyboardType: keyboardType??TextInputType.text,
      onFieldSubmitted:onfieldsumbitted ,
      onChanged: onChanged,
      validator: validator,
      obscureText: obsecureText,
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600, color: LabelColor ?? Colors.black),
        suffixIcon: gesture,
        // labelText: labelText,
        hintText: hintText,
        prefixIcon: icon,
        hintStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600, color: HintColor ?? Colors.black),
        // label: labelText,
        focusedBorder:
            OutlineInputBorder(
                borderSide: BorderSide(
                  color: BorderColor ?? AppColors.primary
                ),
                borderRadius: BorderRadius.circular(borderc??15)),
        enabledBorder:
            OutlineInputBorder(
                borderSide: BorderSide(
                    color: BorderColor ?? Colors.black
                ),
                borderRadius: BorderRadius.circular(borderc??15)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderc??15),
        ),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderc??15)),

      ),
    );
  }
}

