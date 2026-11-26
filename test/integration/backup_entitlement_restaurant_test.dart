import '../helpers/backup_entitlement_suite.dart';

/// M6b: Restaurant backups still answer to `data_backup` (unchanged).
void main() => backupEntitlementSuite(mode: 'restaurant');
