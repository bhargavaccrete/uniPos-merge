
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';

class HivePastOrder{
  static const String _boxName = 'pastorderBox';



  static Box<PastOrderModel>? _box;

  static Box<PastOrderModel> _getPastOrderBox(){
    // Box is already opened during app startup in HiveInit
    if(_box == null || !_box!.isOpen){
      _box = Hive.box<PastOrderModel>(_boxName);
    }
    return _box!;
  }



  static Future<void> addOrder (PastOrderModel pastOrder)async{
    final box = _getPastOrderBox();
    await box.put(pastOrder.id, pastOrder);
  }

  static Future<List<PastOrderModel>> getAllPastOrderModel ()async{
    final box = _getPastOrderBox();
    return  box.values.toList();
  }


  static Future<void> deleteOrder(String id)async{
    final box = _getPastOrderBox();
    await box.delete(id);
  }

  static Future<void> updateOrder(PastOrderModel updatedOrder) async {
    final box = _getPastOrderBox();
    await box.put(updatedOrder.id, updatedOrder);
  }



}
