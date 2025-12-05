import 'package:flutter/material.dart';
import 'package:unipos/presentation/screens/restaurant/AuthSelectionScreen.dart';

import '../../../widget/componets/restaurant/componets/Button.dart';

class Logout extends StatelessWidget {
  const Logout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
        
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: <Widget>[
            CommonButton(
              onTap: () {
                // Perform logout logic here
                Navigator.push(context,MaterialPageRoute(builder: (context)=>AuthSelectionScreen()));
              },
              child: Text('Logout'),
            ),
            CommonButton(
              onTap: () {
                // Cancel logout
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
  }
}
