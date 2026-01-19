import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import 'package:unipos/util/color.dart';
import 'package:unipos/util/color.dart';


class Listmenud extends StatefulWidget {
  final String Title;
  final String? img ;
  final IconData icons;
  final void Function()? onTap;
  const Listmenud({super.key, required this.Title,  this.img, this.onTap, required this.icons});

  @override
  State<Listmenud> createState() => _ListmenudState();
}

class _ListmenudState extends State<Listmenud> {
  @override
  Widget build(BuildContext context) {

    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return InkWell(
      onTap: widget.onTap,
      child: Card(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 1),
        elevation: 5,
        child:Container(
          width: width * 0.3,
          height: height * 0.2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(15),
                width: width * 0.1,
                height: height * 0.1,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  // borderRadius: BorderRadius.circular(10)
                ),
                child:Icon(widget.icons,color: Colors.white,),
                // Image.asset(widget.img)
              ),
              Text(widget.Title,style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w500),)
            ],
          ),
        ),
      ),
    );
  }
}