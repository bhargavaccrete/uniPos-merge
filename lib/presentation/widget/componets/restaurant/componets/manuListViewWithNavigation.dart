import 'package:flutter/material.dart';
import '../../../../../main.dart';
import '../../../../../util/restaurant/common.dart';

class MultipleListViewWithNavigation extends StatelessWidget {
  final String displayTitle;
  final VoidCallback onTap;
  final IconData? displayicon;
  final String? centerText;
  final double? screenheightt;

  final Widget? child;

  MultipleListViewWithNavigation(
      {required this.displayTitle,
      this.displayicon,
      required this.onTap,
      this.centerText,
      this.screenheightt,
      this.child});
 var  DeskTop ="Desktop" ;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          margin: EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5), // black shadow with 50% opacity
                spreadRadius: 2, // how much the shadow spreads
                blurRadius: 5, // how blurry the shadow is
                offset: Offset(2, 4), // shadow position (x: right, y: down)
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              onTap();
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayTitle,
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textScaler: TextScaler.linear(1),
                      ),
                      Icon(displayicon, size: appStore.deviceCategory==DeskTop?20:iconSize(context))
                    ],
                  ),
                ),
                child == null ? SizedBox() : SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.0),
                  child: child ??
                      SizedBox(
                        height: 0,
                      ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// class DecimalPointNavigation extends StatefulWidget {
//   @override
//   _decimalPointNavigationState createState() => _decimalPointNavigationState();
// }

// class _decimalPointNavigationState extends State<DecimalPointNavigation> {
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Row(children: [
//           Text('Decimal Point'),
//         ],)
//       ],
//     );
//   }
// }
