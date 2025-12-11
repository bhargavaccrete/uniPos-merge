
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/companymodel_301.dart';

class CompanyBox {
  static const String _boxName = 'companyBox';

  static Future<Box<Company>> openBox() async {
    return await Hive.openBox<Company>(_boxName);
  }

  static Box<Company> getBox() {
    return Hive.box<Company>(_boxName);
  }

  static Future<void> saveCompany(Company company) async {
    final box = getBox();
    await box.put('company', company); // Replace if already exists
  }

  static Company? getCompany() {
    final box = getBox();
    return box.get('company');
  }

  static Future<void> deleteCompany() async {
    final box = getBox();
    await box.delete('company');
  }

  static Future<void> clearBox() async {
    final box = getBox();
    await box.clear();
  }
}
