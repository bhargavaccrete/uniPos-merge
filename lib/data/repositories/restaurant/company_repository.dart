import 'package:hive/hive.dart';
import '../../models/restaurant/db/companymodel_301.dart';

/// Repository layer for Company data access (Restaurant)
/// Handles all Hive database operations for company information
class CompanyRepository {
  late Box<Company> _companyBox;

  CompanyRepository() {
    _companyBox = Hive.box<Company>('companyBox');
  }

  /// Save company information
  Future<void> saveCompany(Company company) async {
    await _companyBox.put('company', company);
  }

  /// Get company information
  Future<Company?> getCompany() async {
    return _companyBox.get('company');
  }

  /// Update company information
  Future<void> updateCompany(Company company) async {
    await _companyBox.put('company', company);
  }

  /// Delete company information
  Future<void> deleteCompany() async {
    await _companyBox.delete('company');
  }

  /// Clear entire company box
  Future<void> clearBox() async {
    await _companyBox.clear();
  }

  /// Check if company information exists
  Future<bool> hasCompanyInfo() async {
    return _companyBox.containsKey('company');
  }
}