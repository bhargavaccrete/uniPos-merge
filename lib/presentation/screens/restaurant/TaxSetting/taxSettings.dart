import 'package:flutter/material.dart';
import 'package:unipos/presentation/screens/restaurant/TaxSetting/addMultipleTax.dart';
import 'package:unipos/presentation/screens/restaurant/TaxSetting/taxRagistration.dart';

import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';

//main screeen of the texes
class taxSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height * 1;
    double width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.person),
                Text("Admin"),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                height: height * 0.6,
                child: Image.asset('assets/images/taximage.png'),
              ),
              Padding(
                padding: const EdgeInsets.all( 10),
                child: CommonButton(
                    bordercircular: 10,
                    width: width  ,
                    height: height * 0.05,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context)=>Taxragistration()));

                    },
                    child: Center(
                      child: Text(
                        'Add Text Name & Number',
                          textScaler: TextScaler.linear(1.2),
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.0),
                      ),
                    )),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: CommonButton(
                  bordercircular: 10,
                    width: width ,
                    height: height * 0.05,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context)=>Addtax()));
                                          },
                    child:Center(
                      child: Text(
                      'Add Multiple Tax to be applied on items',
                          textScaler: TextScaler.linear(1.2),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold),
                    ),
                    )
                     ),
              ),
            ],
          ),
        ),
      ),
      drawer: DrawerManage(
        issync: true,
        islogout: true,
        isDelete: true,
      ),
    );
  }
}
