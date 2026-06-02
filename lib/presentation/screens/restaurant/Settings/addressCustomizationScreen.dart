import 'package:flutter/material.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';
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
        appBar: buildPrimaryAppBar(
          title: "Address Customization",
          actions: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.white),
                Text("admin", style: TextStyle(color: Colors.white)),
              ],
            )
          ],
        ),
        body: DraggableEditableList()
    );
  }
}
