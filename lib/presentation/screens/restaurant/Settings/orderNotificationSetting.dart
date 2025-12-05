import 'package:flutter/material.dart';

class OrderNotificationsettings extends StatefulWidget {
  @override
  _ordernotificationsettingsState createState() =>
      _ordernotificationsettingsState();
}

class _ordernotificationsettingsState extends State<OrderNotificationsettings> {
  bool _isonline1 = false;
  bool _isonline2 = true;
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
        appBar: AppBar(
          elevation: 1,
          title: Text(
            'Order Notification Settings',
            style: TextStyle(fontSize: 20.0),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [Icon(Icons.person), Text('Admin')],
              ),
            )
          ],
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
            child: Column(children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                  ),
                  Text(
                    "Active Device ",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                  Text(
                    "Inactive Decives ",
                    style: TextStyle(fontSize: 16),
                  ),

                ],
              ),
              Card(
                child: Container(
                  decoration: BoxDecoration(
                    // border: Border.all()
                  // borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10),bottomRight: Radius.circular(10))
                  borderRadius: BorderRadius.circular(10)
                  ),
                  child: Container(
                    width:width*0.9,
                    height: height*0.8,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.blue[200]),
                      border: TableBorder(borderRadius: BorderRadius.circular(20)),
                      columns: [

                        DataColumn(
                          label: Text(
                            "Device Info",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Status",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      rows: [
                        DataRow(cells: [
                          DataCell(Text('Device 1')),
                          DataCell(
                            Row(children: [
                              Container(
                                width: 120,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Row(
                                  children: [
                                    // Online
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isonline1 = true;
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                _isonline1 ? Colors.green : Colors.white,
                                            borderRadius: const BorderRadius.horizontal(
                                                left: Radius.circular(30)),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Online',
                                            style: TextStyle(
                                              color: _isonline1
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Offline
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isonline1 = false;
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                !_isonline1 ? Colors.red : Colors.white,
                                            borderRadius: const BorderRadius.horizontal(
                                                right: Radius.circular(30)),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Offline',
                                            style: TextStyle(
                                              color: !_isonline1
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        ]),
                        DataRow(cells: [
                          DataCell(Text('Device 2')),
                          DataCell(
                            Row(children: [
                              Container(
                                width: 120,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Row(
                                  children: [
                                    // Online
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isonline2 = true;
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                _isonline2 ? Colors.green : Colors.white,
                                            borderRadius: const BorderRadius.horizontal(
                                                left: Radius.circular(30)),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Online',
                                            style: TextStyle(
                                              color: _isonline2
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Offline
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isonline2 = false;
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                !_isonline2 ? Colors.red : Colors.white,
                                            borderRadius: const BorderRadius.horizontal(
                                                right: Radius.circular(30)),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Offline',
                                            style: TextStyle(
                                              color: !_isonline2
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        ])
                      ],
                    ),
                  ),
                ),
              )
            ]),
          ),
        ));
  }
}
