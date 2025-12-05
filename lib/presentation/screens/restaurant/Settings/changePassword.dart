import 'package:flutter/material.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/dropdown.dart';

class Changepassword extends StatefulWidget {
  @override
  State<Changepassword> createState() => _ChangepasswordState();
}

class _ChangepasswordState extends State<Changepassword> {
  String selectedItem = 'Select Item';
  bool obscurePass = true;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title:Text(
          "Change Password",
          style:
          TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
        ) ,
        actions: [
          Padding(
            padding: EdgeInsets.all(5.0),
            child: Row(
              children: [
                Icon(Icons.person),
                Text("admin"),
              ],
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 15,right: 15),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
           
            children: [
          
              Padding(
                padding: EdgeInsets.only(top: 10,bottom: 10),
                child: Row(
                   children: [
                     Text("User type",style: TextStyle(fontSize: 15,fontWeight: FontWeight.bold),),
                   ],
                 ),
              ),
              Container(
                width: MediaQuery.of(context).size.width * 1,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueGrey),
                    borderRadius: BorderRadius.circular(10.0)),
                child: Dropdown(
                    items: ['Select Item', 'Cashier', 'Admin', 'Manager', 'Waiter'],
                    selectedItem: selectedItem,
                    onChanged: (value) {
                      setState(() {
                        selectedItem = value;
                      });
                    }),
              ),
              SizedBox(height: 15.0),
          
              Padding(
                padding: EdgeInsets.only(top: 10,bottom: 10),
                child: Row(
                  children: [
                    Text("Password",style: TextStyle(fontSize: 15,fontWeight: FontWeight.bold),),
                  ],
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width * 1,
                
                child: TextFormField(
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: primarycolor, width: 2.0)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePass ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePass = !obscurePass;
                        });
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 15.0),
          
              Padding(
                padding: EdgeInsets.only(top: 10,bottom: 10),
                child: Row(
                  children: [
                    Text("Confirm Password",style: TextStyle(fontSize: 15,fontWeight: FontWeight.bold),),
                  ],
                ),
              ),
              TextFormField(
                obscureText: obscurePass,
                decoration: InputDecoration(
                  hintText: 'Cinfirm Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide(color: primarycolor, width: 2.0)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePass ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePass = !obscurePass;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(
                height: height*0.10,
              ),
              Container(
                child: CommonButton(
                  width:width*0.9 ,
                  height: height*0.08,
                  onTap: () {},
                  bordercircular: 20,
                  bgcolor: Colors.grey,
                  bordercolor: Colors.grey,
                  child: Text(
                    "Submit",
                    style:
                        TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
