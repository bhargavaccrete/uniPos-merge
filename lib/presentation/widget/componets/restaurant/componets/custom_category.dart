import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

class CustomCategory extends StatefulWidget {
  final String? imagePath;
  final String title;
  final String itemCount;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelet;
  final ValueChanged<bool> onToggle;
  final DateTime? createdTime;
  final DateTime? lastEditedTime;
  final String? editedBy;
  final int? editCount;

  const CustomCategory({
    super.key,
    required this.title,
    required this.itemCount,
    required this.isActive,
    required this.onEdit,
    required this.onDelet,
    required this.onToggle,
    this.imagePath,
    this.createdTime,
    this.lastEditedTime,
    this.editedBy,
    this.editCount,
  });

  @override
  State<CustomCategory> createState() => _CustomCategoryState();
}

class _CustomCategoryState extends State<CustomCategory> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                  child: Icon(Icons.menu,size: 30,color: Colors.grey)
              ),
              Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:   widget.imagePath != null
                      ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                     : Icon(Icons.image, size: 70, color: Colors.grey),
                  // Icon(Icons.image,size: 50,color: Colors.grey,)
              ),
                SizedBox(width: 5,),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title ,
                      style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.bold),),
                      SizedBox(height: 5,),
                      Text('${widget.itemCount} item Added',style: GoogleFonts.poppins(color: Colors.grey),),
                      // 🔍 AUDIT TRAIL: Display edit history
                      if (widget.createdTime != null || widget.lastEditedTime != null) ...[
                        SizedBox(height: 3,),
                        if (widget.createdTime != null)
                          Text(
                            'Created: ${widget.createdTime!.day}/${widget.createdTime!.month}/${widget.createdTime!.year}',
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                          ),
                        if (widget.lastEditedTime != null)
                          Text(
                            'Edited ${widget.editCount ?? 0}x • ${widget.lastEditedTime!.day}/${widget.lastEditedTime!.month}/${widget.lastEditedTime!.year}${widget.editedBy != null ? ' by ${widget.editedBy}' : ''}',
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange[700]),
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          ),


              Row(
                children: [
                  Container(
                    child: Column(
                      // crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 25),
                          child: SizedBox(
                            height:10,
                            width: 20,
                            child: Transform.scale(
                                scale: 0.6,
                                child: Switch(
                                  // thumb when ON
                                  activeColor: Colors.white,
                                  // track when ON
                                  activeTrackColor: AppColors.primary,
                                  // thumb when OFF
                                  inactiveThumbColor: Colors.white70,
                                  // track when OFF
                                  inactiveTrackColor: Colors.grey.shade400,
                                  value: widget.isActive,
                                  onChanged: widget.onToggle,)),
                          ),
                        ),
                                SizedBox(height: 10,),
                                Row(
                                  children: [
                                    Container(
                                      width: width * 0.08,
                                      height: height * 0.05,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(5)
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.edit, color: Colors.grey,size: 15,),
                                        onPressed: widget.onEdit,
                                      ),
                                    ),
                                    SizedBox(width: 5,),
                                    Container(
                                      alignment: Alignment.center,
                                      width: width * 0.08,
                                      height: height * 0.05,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(5)
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.delete, color: Colors.white,size: 15,),
                                        onPressed: widget.onDelet,
                                      ),
                                    ),

                                  ],
                                )
                      ],
                    ),
                  ),
                ],
              )







        ],
      ),
    );
  }
}
