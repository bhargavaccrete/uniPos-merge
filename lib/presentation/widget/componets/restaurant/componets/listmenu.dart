import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../../util/restaurant/responsive_helper.dart';


class Listmenu extends StatefulWidget {
  final VoidCallback? onTap;
  final String title;
  final IconData icons;
  final Color? color;
  final Color? colortext;
  final Color? colorb;
  final Color? listcolor;
  final double? heightCon;
  final double? borderradius;
  final double? iconssize;
  final double? borderwidth;
  final Widget? iconsT;
  const Listmenu({super.key, required this.title, required this.icons, this.color, this.onTap, this.listcolor, this.heightCon, this.borderwidth, this.colorb, this.borderradius, this.colortext, this.iconssize, this.iconsT,});

  @override
  State<Listmenu> createState() => _ListmenuState();
}

class _ListmenuState extends State<Listmenu> {
  @override
  Widget build(BuildContext context) {
    return  Container(
      alignment: Alignment.center,
      height: widget.heightCon?? MediaQuery.of(context).size.height * 0.08,
      // width: MediaQuery.of(context).size.width * 0.,
      decoration: BoxDecoration(
        color: widget.listcolor??Colors.white,
        border: Border.all(
          width: widget.borderwidth??1,
          color: widget.colorb??AppColors.primary,
        ),
        borderRadius: BorderRadius.circular(widget.borderradius??10),

      ),
      child: ListTile(

        trailing: widget.iconsT,

        style: ListTileStyle.drawer,

        onTap:widget.onTap,
        leading:Icon(widget.icons,color:widget.color?? AppColors.primary,size: widget.iconssize??ResponsiveHelper.responsiveTextSize(context, 20),
          ),
        titleAlignment: ListTileTitleAlignment.center,
        title: Text(widget.title,style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.responsiveTextSize(context, 10),
            color: widget.colortext?? Colors.black),),
      ),
    );

    }}
