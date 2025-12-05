import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/retail/hive_model/category_model_215.dart';
import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';

/// GST Calculation Service
/// Priority: Variant GST > Product GST > Category GST > Default (0%)
class GstService {
  static const String _taxInclusiveKey = 'gst_tax_inclusive';
  static const String _defaultGstRateKey = 'gst_default_rate';

  /// Get effective GST rate for a variant
  /// Priority: Variant > Product > Category > Default (0%)
  Future<double> getEffectiveGstRate({
    required VarianteModel variant,
    ProductModel? product,
    CategoryModel? category,
  }) async {
    // 1. Check variant level GST
    if (variant.taxRate != null && variant.taxRate! > 0) {
      return variant.taxRate!;
    }

    // 2. Check product level GST
    if (product != null && product.gstRate != null && product.gstRate! > 0) {
      return product.gstRate!;
    }

    // 3. Check category level GST
    if (category != null && category.gstRate != null && category.gstRate! > 0) {
      return category.gstRate!;
    }

    // 4. Return default GST (0%)
    return await getDefaultGstRate();
  }

  /// Get effective HSN code for a variant
  /// Priority: Variant > Product > Category
  String? getEffectiveHsnCode({
    required VarianteModel variant,
    ProductModel? product,
    CategoryModel? category,
  }) {
    // 1. Check variant level HSN
    if (variant.hsnCode != null && variant.hsnCode!.isNotEmpty) {
      return variant.hsnCode;
    }

    // 2. Check product level HSN
    if (product != null && product.hsnCode != null && product.hsnCode!.isNotEmpty) {
      return product.hsnCode;
    }

    // 3. Check category level HSN
    if (category != null && category.hsnCode != null && category.hsnCode!.isNotEmpty) {
      return category.hsnCode;
    }

    return null;
  }

  /// Calculate GST for a single item
  GstCalculation calculateItemGst({
    required double unitPrice,
    required int quantity,
    required double gstRate,
    double discountAmount = 0,
  }) {
    final grossAmount = _round(unitPrice * quantity);
    final taxableAmount = _round(grossAmount - discountAmount);
    final gstAmount = _round(taxableAmount * (gstRate / 100));
    final cgstAmount = _round(gstAmount / 2);
    final sgstAmount = _round(gstAmount / 2);
    final totalAmount = _round(taxableAmount + gstAmount);

    return GstCalculation(
      grossAmount: grossAmount,
      discountAmount: discountAmount,
      taxableAmount: taxableAmount,
      gstRate: gstRate,
      gstAmount: gstAmount,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      totalAmount: totalAmount,
    );
  }

  /// Calculate GST for multiple items (bill totals)
  BillGstSummary calculateBillGst(List<GstCalculation> itemCalculations) {
    double totalGrossAmount = 0;
    double totalDiscountAmount = 0;
    double totalTaxableAmount = 0;
    double totalGstAmount = 0;
    double totalCgstAmount = 0;
    double totalSgstAmount = 0;
    double grandTotal = 0;

    // Group by GST rate for rate-wise breakdown
    final gstBreakdown = <double, GstRateBreakdown>{};

    for (final calc in itemCalculations) {
      totalGrossAmount += calc.grossAmount;
      totalDiscountAmount += calc.discountAmount;
      totalTaxableAmount += calc.taxableAmount;
      totalGstAmount += calc.gstAmount;
      totalCgstAmount += calc.cgstAmount;
      totalSgstAmount += calc.sgstAmount;
      grandTotal += calc.totalAmount;

      // Add to rate-wise breakdown
      if (!gstBreakdown.containsKey(calc.gstRate)) {
        gstBreakdown[calc.gstRate] = GstRateBreakdown(
          gstRate: calc.gstRate,
          taxableAmount: 0,
          cgstAmount: 0,
          sgstAmount: 0,
          totalGstAmount: 0,
        );
      }
      final breakdown = gstBreakdown[calc.gstRate]!;
      gstBreakdown[calc.gstRate] = GstRateBreakdown(
        gstRate: calc.gstRate,
        taxableAmount: breakdown.taxableAmount + calc.taxableAmount,
        cgstAmount: breakdown.cgstAmount + calc.cgstAmount,
        sgstAmount: breakdown.sgstAmount + calc.sgstAmount,
        totalGstAmount: breakdown.totalGstAmount + calc.gstAmount,
      );
    }

    return BillGstSummary(
      totalGrossAmount: _round(totalGrossAmount),
      totalDiscountAmount: _round(totalDiscountAmount),
      totalTaxableAmount: _round(totalTaxableAmount),
      totalGstAmount: _round(totalGstAmount),
      totalCgstAmount: _round(totalCgstAmount),
      totalSgstAmount: _round(totalSgstAmount),
      grandTotal: _round(grandTotal),
      gstBreakdown: gstBreakdown.values.toList(),
    );
  }

  /// Calculate GST from tax-inclusive price
  GstCalculation calculateFromInclusivePrice({
    required double inclusivePrice,
    required int quantity,
    required double gstRate,
    double discountAmount = 0,
  }) {
    final totalInclusive = inclusivePrice * quantity;
    final taxableAmount = _round((totalInclusive - discountAmount) / (1 + gstRate / 100));
    final gstAmount = _round((totalInclusive - discountAmount) - taxableAmount);
    final cgstAmount = _round(gstAmount / 2);
    final sgstAmount = _round(gstAmount / 2);

    return GstCalculation(
      grossAmount: totalInclusive,
      discountAmount: discountAmount,
      taxableAmount: taxableAmount,
      gstRate: gstRate,
      gstAmount: gstAmount,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      totalAmount: _round(taxableAmount + gstAmount),
    );
  }

  /// Check if tax-inclusive mode is enabled
  Future<bool> isTaxInclusiveMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_taxInclusiveKey) ?? false;
  }

  /// Set tax-inclusive mode
  Future<void> setTaxInclusiveMode(bool inclusive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_taxInclusiveKey, inclusive);
  }

  /// Get default GST rate
  Future<double> getDefaultGstRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_defaultGstRateKey) ?? 0.0;
  }

  /// Set default GST rate
  Future<void> setDefaultGstRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_defaultGstRateKey, rate);
  }

  /// Round to 2 decimal places
  double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  /// Get common GST rates in India
  static List<double> get commonGstRates => [0, 5, 12, 18, 28];

  /// Format GST rate for display
  static String formatGstRate(double rate) {
    if (rate == rate.toInt()) {
      return '${rate.toInt()}%';
    }
    return '${rate.toStringAsFixed(1)}%';
  }
}

/// Result of GST calculation for a single item
class GstCalculation {
  final double grossAmount;
  final double discountAmount;
  final double taxableAmount;
  final double gstRate;
  final double gstAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double totalAmount;

  GstCalculation({
    required this.grossAmount,
    required this.discountAmount,
    required this.taxableAmount,
    required this.gstRate,
    required this.gstAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'grossAmount': grossAmount,
      'discountAmount': discountAmount,
      'taxableAmount': taxableAmount,
      'gstRate': gstRate,
      'gstAmount': gstAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'totalAmount': totalAmount,
    };
  }
}

/// Bill-level GST summary
class BillGstSummary {
  final double totalGrossAmount;
  final double totalDiscountAmount;
  final double totalTaxableAmount;
  final double totalGstAmount;
  final double totalCgstAmount;
  final double totalSgstAmount;
  final double grandTotal;
  final List<GstRateBreakdown> gstBreakdown;

  BillGstSummary({
    required this.totalGrossAmount,
    required this.totalDiscountAmount,
    required this.totalTaxableAmount,
    required this.totalGstAmount,
    required this.totalCgstAmount,
    required this.totalSgstAmount,
    required this.grandTotal,
    required this.gstBreakdown,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalGrossAmount': totalGrossAmount,
      'totalDiscountAmount': totalDiscountAmount,
      'totalTaxableAmount': totalTaxableAmount,
      'totalGstAmount': totalGstAmount,
      'totalCgstAmount': totalCgstAmount,
      'totalSgstAmount': totalSgstAmount,
      'grandTotal': grandTotal,
      'gstBreakdown': gstBreakdown.map((e) => e.toMap()).toList(),
    };
  }
}

/// GST breakdown by rate (for invoice display)
class GstRateBreakdown {
  final double gstRate;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double totalGstAmount;

  GstRateBreakdown({
    required this.gstRate,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.totalGstAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'gstRate': gstRate,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'totalGstAmount': totalGstAmount,
    };
  }
}