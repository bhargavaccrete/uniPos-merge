import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

/// AND-06: a backup image entry may only be written as a plain file name
/// inside `product_images` — never a path that leaves that folder.
void main() {
  String? name(String entry) => UnifiedBackupService.safeImageFileName(entry);

  group('names the app exports are kept', () {
    test('product image: prefix dropped', () {
      expect(name('prod_img_photo.jpg'), 'photo.jpg');
    });

    test('item image: kept as is', () {
      expect(name('item_img_3f2a9c1e-uuid'), 'item_img_3f2a9c1e-uuid');
    });
  });

  group('names that would leave product_images are rejected', () {
    for (final entry in [
      'prod_img_../../shared_prefs/FlutterSharedPreferences.xml',
      'item_img_../orderbox.hive',
      'prod_img_sub/photo.jpg',
      'prod_img_/data/data/app/file',
      'prod_img_..',
      'prod_img_.',
      'prod_img_',
    ]) {
      test(entry, () => expect(name(entry), isNull));
    }
  });
}
