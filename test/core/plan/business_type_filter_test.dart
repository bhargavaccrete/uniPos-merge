import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';

/// Business-type filtering from the signed manifest's new fields
/// (`planBusinessType` + `featureBusinessTypes`). 1 Restaurant, 2 Retail, 3 Both.
///
/// Rule under test (fail-open): a feature is relevant unless the manifest
/// EXPLICITLY tags it for a different business type. Verifies the parse/store
/// layer ([Entitlements]) and the filter ([PlanEnforce.businessTypeAllows]).
/// `allows()` itself is not exercised here — it routes through GetIt/LicenseStore.
void main() {
  ManifestData manifest({int? plan, Map<String, int> features = const {}}) =>
      ManifestData(
        entitlements: {for (final k in features.keys) k: true},
        license: const {'status': 2},
        version: 1,
        planBusinessType: plan,
        featureBusinessTypes: features,
      );

  group('Entitlements — business-type fields round-trip', () {
    tearDown(() => Entitlements.instance.clear());

    test('exposes planBusinessType and per-feature types after load', () {
      Entitlements.instance.loadFromManifest(manifest(
        plan: 2,
        features: {'retail.catalog': 2, 'billing': 1, 'reports': 3},
      ));

      expect(Entitlements.instance.planBusinessType, 2);
      expect(Entitlements.instance.featureBusinessType('retail.catalog'), 2);
      expect(Entitlements.instance.featureBusinessType('billing'), 1);
      expect(Entitlements.instance.featureBusinessType('reports'), 3);
      expect(Entitlements.instance.featureBusinessType('absent.key'), isNull);
    });

    test('old manifest (fields absent) → null plan type, empty feature map', () {
      Entitlements.instance.loadFromManifest(
        const ManifestData(entitlements: {'billing': true}, license: {}, version: 1),
      );
      expect(Entitlements.instance.planBusinessType, isNull);
      expect(Entitlements.instance.featureBusinessType('billing'), isNull);
    });

    test('clear() resets the new fields', () {
      Entitlements.instance.loadFromManifest(manifest(plan: 1, features: {'x': 1}));
      Entitlements.instance.clear();
      expect(Entitlements.instance.planBusinessType, isNull);
      expect(Entitlements.instance.featureBusinessType('x'), isNull);
    });
  });

  group('PlanEnforce.businessTypeAllows — fail-open filter', () {
    late Directory tempDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = await Directory.systemTemp.createTemp('business_type_filter_');
      Hive.init(tempDir.path);
      await AppConfig.init();
    });

    tearDownAll(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    tearDown(() => Entitlements.instance.clear());

    test('restaurant store: restaurant & Both pass, retail is withheld', () {
      AppConfig.forceSetBusinessMode(BusinessMode.restaurant);
      expect(PlanEnforce.storeBusinessTypeCode, 1);
      Entitlements.instance.loadFromManifest(manifest(features: {
        'resto.only': 1,
        'retail.only': 2,
        'shared': 3,
      }));
      expect(PlanEnforce.businessTypeAllows('resto.only'), isTrue);
      expect(PlanEnforce.businessTypeAllows('shared'), isTrue);
      expect(PlanEnforce.businessTypeAllows('retail.only'), isFalse);
      // Untagged / unknown keys always pass (fail-open, back-compat).
      expect(PlanEnforce.businessTypeAllows('untracked'), isTrue);
    });

    test('retail store: retail & Both pass, restaurant is withheld', () {
      AppConfig.forceSetBusinessMode(BusinessMode.retail);
      expect(PlanEnforce.storeBusinessTypeCode, 2);
      Entitlements.instance.loadFromManifest(manifest(features: {
        'resto.only': 1,
        'retail.only': 2,
        'shared': 3,
      }));
      expect(PlanEnforce.businessTypeAllows('retail.only'), isTrue);
      expect(PlanEnforce.businessTypeAllows('shared'), isTrue);
      expect(PlanEnforce.businessTypeAllows('resto.only'), isFalse);
      expect(PlanEnforce.businessTypeAllows('untracked'), isTrue);
    });
  });
}
