import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'tax_details.g.dart';

@HiveType(typeId: HiveTypeIds.taxDetails) // make sure this ID is unique in your app
class TaxDetails extends HiveObject {
  @HiveField(0)
  final bool isEnabled;            // enable/disable tax

  @HiveField(1)
  final bool isInclusive;          // inclusive vs exclusive

  @HiveField(2)
  final double defaultRate;        // e.g., 18.0 for 18%

  @HiveField(3)
  final String taxName;            // e.g., 'GST', 'VAT'

  @HiveField(4)
  final String? placeOfSupply;     // e.g., 'KA' (Karnataka) or full state

  @HiveField(5)
  final bool applyOnDelivery;      // apply tax on delivery/packing etc.

  @HiveField(6)
  final String? notes;             // optional info

  @HiveField(7)
  final List<TaxRateItem>? taxRates; // List of all tax rates added during setup

   TaxDetails({
    this.isEnabled = true,
    this.isInclusive = true,
    this.defaultRate = 0.0,
    this.taxName = 'GST',
    this.placeOfSupply,
    this.applyOnDelivery = false,
    this.notes,
    this.taxRates,
  });

  TaxDetails copyWith({
    bool? isEnabled,
    bool? isInclusive,
    double? defaultRate,
    String? taxName,
    String? placeOfSupply,
    bool? applyOnDelivery,
    String? notes,
    List<TaxRateItem>? taxRates,
  }) {
    return TaxDetails(
      isEnabled: isEnabled ?? this.isEnabled,
      isInclusive: isInclusive ?? this.isInclusive,
      defaultRate: defaultRate ?? this.defaultRate,
      taxName: taxName ?? this.taxName,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      applyOnDelivery: applyOnDelivery ?? this.applyOnDelivery,
      notes: notes ?? this.notes,
      taxRates: taxRates ?? this.taxRates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'isInclusive': isInclusive,
      'defaultRate': defaultRate,
      'taxName': taxName,
      'placeOfSupply': placeOfSupply,
      'applyOnDelivery': applyOnDelivery,
      'notes': notes,
      'taxRates': taxRates?.map((e) => e.toMap()).toList(),
    };
  }

  factory TaxDetails.fromMap(Map<String, dynamic> map) {
    return TaxDetails(
      isEnabled: map['isEnabled'] as bool? ?? true,
      isInclusive: map['isInclusive'] as bool? ?? true,
      defaultRate: (map['defaultRate'] as num?)?.toDouble() ?? 0.0,
      taxName: map['taxName'] as String? ?? 'GST',
      placeOfSupply: map['placeOfSupply'] as String?,
      applyOnDelivery: map['applyOnDelivery'] as bool? ?? false,
      notes: map['notes'] as String?,
      taxRates: (map['taxRates'] as List<dynamic>?)
          ?.map((e) => TaxRateItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

@HiveType(typeId:  HiveTypeIds.taxRateItem) // Unique type ID for TaxRateItem
class TaxRateItem extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final double rate;

  @HiveField(2)
  final bool isDefault;

  TaxRateItem({
    required this.name,
    required this.rate,
    this.isDefault = false,
  });

  TaxRateItem copyWith({
    String? name,
    double? rate,
    bool? isDefault,
  }) {
    return TaxRateItem(
      name: name ?? this.name,
      rate: rate ?? this.rate,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'rate': rate,
      'isDefault': isDefault,
    };
  }

  factory TaxRateItem.fromMap(Map<String, dynamic> map) {
    return TaxRateItem(
      name: map['name'] as String,
      rate: (map['rate'] as num).toDouble(),
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }
}
