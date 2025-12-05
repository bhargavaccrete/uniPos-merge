// androidPOS/lib/componets/multipleListView.dart
import 'package:flutter/material.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/inputTextFields.dart';

const CommonTextSize = 10.0;

class MultipleListView extends StatefulWidget {
  final List<List<String>> lists;

  final Color? leadingColor;

  final String? ShowText;

  MultipleListView({
    Key? key,
    required this.lists,
    this.ShowText,
    this.leadingColor = Colors.orange,
  }) : super(key: key);

  @override
  _MultipleListViewState createState() => _MultipleListViewState();
}

class _MultipleListViewState extends State<MultipleListView> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            widget.ShowText ?? '',
            textScaler: TextScaler.linear(1),
            style: TextStyle(
              fontWeight: FontWeight.bold,
                color: widget.leadingColor ?? Colors.black, fontSize: 20),
          ),
        ),
        Expanded(
          child: Flexible(
            child: ListView.builder(
              itemCount: widget.lists.length,
              itemBuilder: (context, index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Card(
                      elevation: 3,
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              textScaler: TextScaler.linear(1),
                              widget.lists[index][0],
                              style: TextStyle(
                                  fontSize: 15,
                                  color: widget.leadingColor ?? Colors.black),
                            ),
                            SizedBox(
                                width: 10), // add some space between the texts
                            Text(widget.lists[index][1],
                                textScaler: TextScaler.linear(1),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black,
                                )),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              textScaler: TextScaler.linear(1),
                              widget.lists[index][2],
                              style: TextStyle(
                                  fontSize: 15, color: widget.leadingColor),
                            ),
                            SizedBox(
                                width: 10), // add some space between the texts
                            Text(
                              textScaler: TextScaler.linear(1),
                              widget.lists[index][3],
                              style:
                                  TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (BuildContext context) {
                                return Container(

                                  height: height ,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.all(5),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              'Tax Ragistration',
                                              textScaler:
                                                  TextScaler.linear(1.2),
                                              style: TextStyle(
                                                  color: Colors.orangeAccent,
                                                  fontSize: 20),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 10.0,
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            icon: Icon(
                                              Icons.cancel,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Please fill in the required fields and press update and this is data want to able to give the some data ",
                                          textScaler: TextScaler.linear(1.2),
                                          style: TextStyle(fontSize: 15.0),
                                        ),
                                      ),
                                      Container(
                                        width: width,
                                        child: InputTextFields(
                                          Textdata: "text data",
                                          titleText: "Text Ragistration",
                                        ),
                                      ),
                                      Container(
                                        width: width,
                                        child: InputTextFields(
                                          Textdata: "text Number",
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: CommonButton(
                                          onTap: () {
                                            Navigator.of(context).pop();
                                          },
                                          bordercircular: 10.0,
                                          height: height*0.07,
                                          width: width * 0.9,
                                          child: Center(
                                              child: Text(
                                            "Update",
                                textScaler: TextScaler.linear(1.2),
                                            style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          )),
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
