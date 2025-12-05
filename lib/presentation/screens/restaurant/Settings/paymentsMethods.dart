import 'package:flutter/material.dart';

import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/showdialog.dart';
import '../../../widget/componets/restaurant/componets/toggleSwitch.dart';

class Paymentsmethods extends StatefulWidget {
  @override
  _paymentsmethodsState createState() => _paymentsmethodsState();
}

class _paymentsmethodsState extends State<Paymentsmethods> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final widget = MediaQuery.of(context).size.width * 1;
    return Scaffold(
        appBar: AppBar(
          elevation: 1,
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  "Payments Methods ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Icon(Icons.person),
                Text('Admin'),
              ],
            )
          ],
        ),
        body: Column(children: [
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CommonButton(
                    onTap: () {},
                    bordercircular: 10,
                    height: 50,
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sync,
                          color: Colors.white,
                        ),
                        Text(
                          "Sync",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ],
                    )),
                SizedBox(
                  width: 10,
                ),
                CommonButton(
                    onTap: () {},
                    bordercircular: 10,
                    height: 50,
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle,
                          color: Colors.white,
                        ),
                        TextButton(
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return Showdialog(
                                    content: 'Add the payment details here',
                                    title: 'Add  Payment Method',
                                    ButtonText: 'Add',
                                  );
                                });
                          },
                          child: Text(
                            "Add",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ))
              ],
            ),
          ),
          FittedBox(
              child: Container(
            width: widget * 1,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.blue),
                columns: [
                  DataColumn(
                    label: Text(
                      "Sr No",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Method\nName",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Active\nDeactive",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Edit",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: [
                  DataRow(cells: [
                    DataCell(Text("1")),
                    DataCell(Text("Cash")),
                    DataCell(ToggleSwitch(
                      initialValue: false,
                      showBorder: false,
                    )),
                    DataCell(IconButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return Showdialog(
                                  content: 'update the payment details here',
                                  title: 'update Payment Method',
                                  ButtonText: 'Update',
                                );
                              });
                        },
                        icon: Icon(Icons.edit)))
                  ]),
                  DataRow(cells: [
                    DataCell(Text("2")),
                    DataCell(Text("Card")),
                    DataCell(ToggleSwitch(
                      initialValue: false,
                      showBorder: false,
                    )),
                    DataCell(IconButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return Showdialog(
                                  content: 'update the payment details here',
                                  title: 'update Payment Method',
                                  ButtonText: 'Update',
                                );
                              });
                        },
                        icon: Icon(Icons.edit)))
                  ])
                ]),
          )),
        ]));
  }
}
