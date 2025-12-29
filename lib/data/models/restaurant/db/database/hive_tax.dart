
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/taxmodel_314.dart';

class TaxBox{
  static const _boxName = 'restaurant_taxes';

  static Box<Tax> getTaxBox() {
    return Hive.box<Tax>(_boxName);
  }

  static Future<void> addTax(Tax tax)async{
    final box = getTaxBox();
    await box.put(tax.id ,tax);
  }

  static Future<List<Tax>> getAllTax()async{
    final box = getTaxBox();
    return box.values.toList();
  }

  static Future<void> updateTax(Tax tax)async{
    final box = getTaxBox();
    await box.put(tax.id, tax);
  }

  static Future<void> deleteTax(String id)async{
    final box = getTaxBox();
    await box.delete(id);
  }
}