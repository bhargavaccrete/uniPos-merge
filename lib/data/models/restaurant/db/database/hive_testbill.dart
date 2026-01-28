import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/testbillmodel_318.dart';


class HiveTestBill {
  static const String boxName = 'testBillBox';

  // Get box instance
  static Box<TestBillModel> getBox() {
    return Hive.box<TestBillModel>(boxName);
  }

  // Add a test bill
  static Future<void> addBill(TestBillModel bill) async {
    final box = getBox();
    await box.add(bill);
  }

  // Add multiple bills (batch insert)
  static Future<void> addBills(List<TestBillModel> bills) async {
    final box = getBox();
    await box.addAll(bills);
  }

  // Get all bills
  static List<TestBillModel> getAllBills() {
    final box = getBox();
    return box.values.toList();
  }

  // Get bills count
  static int getBillsCount() {
    final box = getBox();
    return box.length;
  }

  // Get bills by table number
  static List<TestBillModel> getBillsByTable(int tableNo) {
    final box = getBox();
    return box.values.where((bill) => bill.tableNo == tableNo).toList();
  }

  // Get bills by payment type
  static List<TestBillModel> getBillsByPaymentType(String paymentType) {
    final box = getBox();
    return box.values.where((bill) => bill.paymentType == paymentType).toList();
  }

  // Get bills by date range
  static List<TestBillModel> getBillsByDateRange(DateTime start, DateTime end) {
    final box = getBox();
    return box.values
        .where((bill) =>
            bill.dateTime.isAfter(start) && bill.dateTime.isBefore(end))
        .toList();
  }

  // Get bills by customer name
  static List<TestBillModel> getBillsByCustomer(String customerName) {
    final box = getBox();
    return box.values
        .where((bill) =>
            bill.customerName.toLowerCase().contains(customerName.toLowerCase()))
        .toList();
  }

  // Get total revenue
  static double getTotalRevenue() {
    final box = getBox();
    return box.values.fold(0.0, (sum, bill) => sum + bill.totalAmount);
  }

  // Get revenue by payment type
  static Map<String, double> getRevenueByPaymentType() {
    final box = getBox();
    Map<String, double> revenue = {};

    for (var bill in box.values) {
      revenue[bill.paymentType] =
          (revenue[bill.paymentType] ?? 0.0) + bill.totalAmount;
    }

    return revenue;
  }

  // Delete a bill by key
  static Future<void> deleteBill(dynamic key) async {
    final box = getBox();
    await box.delete(key);
  }

  // Clear all bills
  static Future<void> clearAllBills() async {
    final box = getBox();
    await box.clear();
  }

  // Compact the box (reduce file size)
  static Future<void> compactBox() async {
    final box = getBox();
    await box.compact();
  }

  // Get box file path
  static String? getBoxPath() {
    final box = getBox();
    return box.path;
  }
}
