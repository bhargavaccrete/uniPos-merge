// In a new file, e.g., lib/screens/Reports/salesByCategory/CategoryReportData.dart

class CategoryReportData {
  final String categoryName;
  int totalItemsSold;
  double totalRevenue;

  CategoryReportData({
    required this.categoryName,
    required this.totalItemsSold,
    required this.totalRevenue,
  });
}