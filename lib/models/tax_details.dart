import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

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

  // Field 7 (taxRates: List<TaxRateItem>?) retired — named tax rates now
  // live in the shared TaxStore (data/models/common/taxmodel_314.dart).

   TaxDetails({
    this.isEnabled = true,
    this.isInclusive = true,
    this.defaultRate = 0.0,
    this.taxName = 'GST',
    this.placeOfSupply,
    this.applyOnDelivery = false,
    this.notes,
  });

  TaxDetails copyWith({
    bool? isEnabled,
    bool? isInclusive,
    double? defaultRate,
    String? taxName,
    String? placeOfSupply,
    bool? applyOnDelivery,
    String? notes,
  }) {
    return TaxDetails(
      isEnabled: isEnabled ?? this.isEnabled,
      isInclusive: isInclusive ?? this.isInclusive,
      defaultRate: defaultRate ?? this.defaultRate,
      taxName: taxName ?? this.taxName,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      applyOnDelivery: applyOnDelivery ?? this.applyOnDelivery,
      notes: notes ?? this.notes,
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
    );
  }
}
