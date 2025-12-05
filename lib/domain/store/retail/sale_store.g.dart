// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SaleStore on _SaleStore, Store {
  Computed<int>? _$saleCountComputed;

  @override
  int get saleCount => (_$saleCountComputed ??=
          Computed<int>(() => super.saleCount, name: '_SaleStore.saleCount'))
      .value;
  Computed<double>? _$totalRevenueComputed;

  @override
  double get totalRevenue =>
      (_$totalRevenueComputed ??= Computed<double>(() => super.totalRevenue,
              name: '_SaleStore.totalRevenue'))
          .value;
  Computed<int>? _$creditSalesCountComputed;

  @override
  int get creditSalesCount => (_$creditSalesCountComputed ??= Computed<int>(
          () => super.creditSalesCount,
          name: '_SaleStore.creditSalesCount'))
      .value;
  Computed<double>? _$totalDueInSalesComputed;

  @override
  double get totalDueInSales => (_$totalDueInSalesComputed ??= Computed<double>(
          () => super.totalDueInSales,
          name: '_SaleStore.totalDueInSales'))
      .value;
  Computed<int>? _$dueInvoicesCountComputed;

  @override
  int get dueInvoicesCount => (_$dueInvoicesCountComputed ??= Computed<int>(
          () => super.dueInvoicesCount,
          name: '_SaleStore.dueInvoicesCount'))
      .value;

  late final _$salesAtom = Atom(name: '_SaleStore.sales', context: context);

  @override
  ObservableList<SaleModel> get sales {
    _$salesAtom.reportRead();
    return super.sales;
  }

  @override
  set sales(ObservableList<SaleModel> value) {
    _$salesAtom.reportWrite(value, super.sales, () {
      super.sales = value;
    });
  }

  late final _$salesStatsAtom =
      Atom(name: '_SaleStore.salesStats', context: context);

  @override
  Map<String, dynamic> get salesStats {
    _$salesStatsAtom.reportRead();
    return super.salesStats;
  }

  @override
  set salesStats(Map<String, dynamic> value) {
    _$salesStatsAtom.reportWrite(value, super.salesStats, () {
      super.salesStats = value;
    });
  }

  late final _$loadSalesAsyncAction =
      AsyncAction('_SaleStore.loadSales', context: context);

  @override
  Future<void> loadSales() {
    return _$loadSalesAsyncAction.run(() => super.loadSales());
  }

  late final _$addSaleAsyncAction =
      AsyncAction('_SaleStore.addSale', context: context);

  @override
  Future<void> addSale(SaleModel sale) {
    return _$addSaleAsyncAction.run(() => super.addSale(sale));
  }

  late final _$updateSaleAsyncAction =
      AsyncAction('_SaleStore.updateSale', context: context);

  @override
  Future<void> updateSale(SaleModel sale) {
    return _$updateSaleAsyncAction.run(() => super.updateSale(sale));
  }

  late final _$deleteSaleAsyncAction =
      AsyncAction('_SaleStore.deleteSale', context: context);

  @override
  Future<void> deleteSale(String saleId) {
    return _$deleteSaleAsyncAction.run(() => super.deleteSale(saleId));
  }

  late final _$getAllSalesAsyncAction =
      AsyncAction('_SaleStore.getAllSales', context: context);

  @override
  Future<List<SaleModel>> getAllSales() {
    return _$getAllSalesAsyncAction.run(() => super.getAllSales());
  }

  late final _$getSaleByIdAsyncAction =
      AsyncAction('_SaleStore.getSaleById', context: context);

  @override
  Future<SaleModel?> getSaleById(String saleId) {
    return _$getSaleByIdAsyncAction.run(() => super.getSaleById(saleId));
  }

  late final _$getTodaySalesAsyncAction =
      AsyncAction('_SaleStore.getTodaySales', context: context);

  @override
  Future<List<SaleModel>> getTodaySales() {
    return _$getTodaySalesAsyncAction.run(() => super.getTodaySales());
  }

  late final _$getSalesByDateRangeAsyncAction =
      AsyncAction('_SaleStore.getSalesByDateRange', context: context);

  @override
  Future<List<SaleModel>> getSalesByDateRange(
      DateTime startDate, DateTime endDate) {
    return _$getSalesByDateRangeAsyncAction
        .run(() => super.getSalesByDateRange(startDate, endDate));
  }

  late final _$loadSalesStatsAsyncAction =
      AsyncAction('_SaleStore.loadSalesStats', context: context);

  @override
  Future<void> loadSalesStats() {
    return _$loadSalesStatsAsyncAction.run(() => super.loadSalesStats());
  }

  late final _$clearAllSalesAsyncAction =
      AsyncAction('_SaleStore.clearAllSales', context: context);

  @override
  Future<void> clearAllSales() {
    return _$clearAllSalesAsyncAction.run(() => super.clearAllSales());
  }

  late final _$getSalesByCustomerIdAsyncAction =
      AsyncAction('_SaleStore.getSalesByCustomerId', context: context);

  @override
  Future<List<SaleModel>> getSalesByCustomerId(String customerId) {
    return _$getSalesByCustomerIdAsyncAction
        .run(() => super.getSalesByCustomerId(customerId));
  }

  late final _$getCreditSalesAsyncAction =
      AsyncAction('_SaleStore.getCreditSales', context: context);

  @override
  Future<List<SaleModel>> getCreditSales() {
    return _$getCreditSalesAsyncAction.run(() => super.getCreditSales());
  }

  late final _$getSalesWithDueAsyncAction =
      AsyncAction('_SaleStore.getSalesWithDue', context: context);

  @override
  Future<List<SaleModel>> getSalesWithDue() {
    return _$getSalesWithDueAsyncAction.run(() => super.getSalesWithDue());
  }

  late final _$getCustomerSalesWithDueAsyncAction =
      AsyncAction('_SaleStore.getCustomerSalesWithDue', context: context);

  @override
  Future<List<SaleModel>> getCustomerSalesWithDue(String customerId) {
    return _$getCustomerSalesWithDueAsyncAction
        .run(() => super.getCustomerSalesWithDue(customerId));
  }

  late final _$getTodayCreditSalesAsyncAction =
      AsyncAction('_SaleStore.getTodayCreditSales', context: context);

  @override
  Future<List<SaleModel>> getTodayCreditSales() {
    return _$getTodayCreditSalesAsyncAction
        .run(() => super.getTodayCreditSales());
  }

  late final _$getCreditSalesByDateRangeAsyncAction =
      AsyncAction('_SaleStore.getCreditSalesByDateRange', context: context);

  @override
  Future<List<SaleModel>> getCreditSalesByDateRange(
      DateTime start, DateTime end) {
    return _$getCreditSalesByDateRangeAsyncAction
        .run(() => super.getCreditSalesByDateRange(start, end));
  }

  late final _$getSalesByStatusAsyncAction =
      AsyncAction('_SaleStore.getSalesByStatus', context: context);

  @override
  Future<List<SaleModel>> getSalesByStatus(String status) {
    return _$getSalesByStatusAsyncAction
        .run(() => super.getSalesByStatus(status));
  }

  @override
  String toString() {
    return '''
sales: ${sales},
salesStats: ${salesStats},
saleCount: ${saleCount},
totalRevenue: ${totalRevenue},
creditSalesCount: ${creditSalesCount},
totalDueInSales: ${totalDueInSales},
dueInvoicesCount: ${dueInvoicesCount}
    ''';
  }
}
