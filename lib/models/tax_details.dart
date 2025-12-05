import 'package:hive/hive.dart';

part 'tax_details.g.dart';

@HiveType(typeId: 2) // make sure this ID is unique in your app
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
}
