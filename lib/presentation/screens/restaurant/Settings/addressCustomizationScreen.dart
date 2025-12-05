import 'package:flutter/material.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/drag&droplist.dart';

class AddressCustomizationScreen extends StatefulWidget {
  @override
  _addressCustomizationScreenState createState() =>
      _addressCustomizationScreenState();
}

class _addressCustomizationScreenState
    extends State<AddressCustomizationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Text("Address Customization",style: TextStyle(fontSize: 20.0,fontWeight: FontWeight.bold)),
        actions: [
          Row(
            children: [
                Icon(Icons.person),
                Text("admin"),
            ],
          )
        ],
      ),
    body: DraggableEditableList()
    );
  }
}
