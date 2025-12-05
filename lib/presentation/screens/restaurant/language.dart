import 'package:flutter/material.dart';


import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../data/models/restaurant/db/companymodel_301.dart';

class CompanyListScreen extends StatelessWidget {
  final Box companyBox = Hive.box<Company>('companybox');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registered Companies')),
      body: ValueListenableBuilder(
        valueListenable: companyBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return Center(child: Text("No company data found."));
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final company = box.getAt(index) as Company;

              return Card(
                margin: EdgeInsets.all(8),
                child:
                  Column(
                    children: [
                      Text(company.comapanyName),
                      Text(company.ownerName),
                      Text(company.address),
                      Text(company.state),
                      Text(company.city),
                      Text(company.btype),
                      Text(company.comapanyName),
                      Text(company.comapanyName),
                      Text(company.comapanyName),
                    ],
                  )
              );
            },
          );
        },
      ),
    );
  }
}
