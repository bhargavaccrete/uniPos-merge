import 'package:flutter/material.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'mulTextFelids&userinfoPopUp.dart';

class Showdialog extends StatelessWidget {
  final String? title;
  final String? content;
  final String? ButtonText;
  final Color? buttonColor;
  final VoidCallback? child;
  final List<Widget>? actions;


  const Showdialog({Key? key,this.child, this.title,this.content,this.ButtonText ,this.buttonColor,this.actions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
      title: Text(
        title??'',

        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
      ),
      content: Text(content??''),
      actions: [
       textFelids(hintText: "Enter payment method"),
       Padding(
         padding: const EdgeInsets.all(10.0),
         child: CommonButton(onTap: (){}, child:Text(ButtonText??'',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),) ,bgcolor: buttonColor,),
       ),
      ],
    );
  }
}
