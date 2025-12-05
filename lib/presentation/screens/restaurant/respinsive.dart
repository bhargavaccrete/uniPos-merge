


import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class responsive extends StatelessWidget{
  final IconData? icon;
  final String? title;

  responsive({super.key,this.title,this.icon});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width =  size.width;

    bool forMobile = width< 600 ;
    bool fortablet=width>=600  && width<1024;
    bool fordesktop = width>=1024;

    double iconSize=forMobile?24:fortablet?36:48;
    double title=forMobile?16:fortablet?20:26;
    double padding=forMobile?12:fortablet?20:32;
    double spaceing = forMobile?12:18;


    // TODO: implement build
    return Container(
      width: fordesktop?600 :double.infinity,
      padding: EdgeInsets.all(padding),


    );
  }
}
