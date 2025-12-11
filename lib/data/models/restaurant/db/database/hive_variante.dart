
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';

class HiveVariante{
  static  Box<VariantModel> ?_box;
   static const _boxName = 'variante';

   static Future <Box<VariantModel>> getVariante ()async{
     if(_box == null || !_box!.isOpen ){
       try{
         _box = await Hive.openBox<VariantModel>(_boxName);
       }catch(e){
         print("Error opening '$_boxName' Hive Box: $e");
       }
     }
     return _box!;
   }

   static Future<void> addVariante(VariantModel variantmodel)async{
     final box = await getVariante();
     await box.put(variantmodel.id , variantmodel);
   }

   static Future<void> updateVariante(VariantModel variantemodel)async{
     final box = await getVariante();
     await box.put(variantemodel.id,variantemodel);
   }

static Future<void> deleteVariante(String id)async{
     final box = await getVariante();
     await box.delete(id);
   }




   static Future<List<VariantModel>> getAllVariante ()async {
     final box = await getVariante();
     return box.values.toList();
   }

}