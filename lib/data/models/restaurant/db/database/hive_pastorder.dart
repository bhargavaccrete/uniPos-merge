
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';

class HivePastOrder{
  static const String _boxName = 'pastorderBox';



  static Box<pastOrderModel>? _box;

  static Future<Box<pastOrderModel>> _getPastOrderBox()async{
    // if the box us already open , return it immediately
    if(_box != null && _box!.isOpen){
      return _box!;
    }

  //   otherwise , open it and store the instance for future use.
    _box = await Hive.openBox<pastOrderModel>(_boxName);
    return _box!;

  }



  static Future<void> addOrder (pastOrderModel pastOrder)async{
    final box = await _getPastOrderBox();
    await box.put(pastOrder.id, pastOrder);
  }

  static Future<List<pastOrderModel>> getAllPastOrderModel ()async{
    final box = await _getPastOrderBox();
    return  box.values.toList();
  }


  static Future<void> deleteOrder(String id)async{
    final box = await _getPastOrderBox();
    await box.delete(id);
  }

  static Future<void> updateOrder(pastOrderModel updatedOrder) async {
    final box = await _getPastOrderBox();
    await box.put(updatedOrder.id, updatedOrder);
  }



}