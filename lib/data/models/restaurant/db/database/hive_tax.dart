
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/taxmodel_314.dart';

class TaxBox{
  static Box<Tax>? _box;
  static const _boxName = 'restaurant_taxes';

 static Future<Box<Tax>> getTaxBox()async{
   if(_box== null || !_box!.isOpen){
     try{
       _box =  await Hive.openBox<Tax>(_boxName);
     }catch(e){
       print("Error Opening $_boxName $e");
     }
   }
   return _box!;
 }


 static Future<void> addTax(Tax tax)async{
   final box = await getTaxBox();
   await box.put(tax.id ,tax);
 }

 static Future<List<Tax>> getAllTax()async{
   final box  = await getTaxBox();
   return box.values.toList();
 }

 static Future<void> updateTax(Tax tax)async{
   final box = await getTaxBox();
   await box.put(tax.id, tax);
 }

 static Future<void> deleteTax(String id)async{
   final box = await getTaxBox();
   await box.delete(id);
 }


}