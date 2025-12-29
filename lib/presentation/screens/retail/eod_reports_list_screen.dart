import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/domain/services/restaurant/eod_service.dart';
import 'package:unipos/presentation/screens/retail/eod_report_detail_screen.dart';

/// EOD Reports List Screen - Shows all saved EOD reports
class EODReportsListScreen extends StatefulWidget {
  const EODReportsListScreen({super.key});

  @override
  State<EODReportsListScreen> createState() => _EODReportsListScreenState();
}

class _EODReportsListScreenState extends State<EODReportsListScreen> {
  List<EndOfDayReport> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final allReports = await EODService.getAllEODReports();
      // Filter for retail reports only (mode == 'retail' or null for old reports)
      final retailReports = allReports.where((report) {
        return report.mode == 'retail';
      }).toList();

      setState(() {
        _reports = retailReports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading reports: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EOD Reports', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No EOD Reports Yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete your first End of Day to see reports here',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return _buildReportCard(report);
                    },
                  ),
                ),
    );
  }

  Widget _buildReportCard(EndOfDayReport report) {
    final dateFormat = DateFormat('dd MMM yyyy, EEEE');
    final isBalanced = report.cashReconciliation.reconciliationStatus == 'Balanced';
    final isOverage = report.cashReconciliation.reconciliationStatus == 'Overage';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EODReportDetailScreen(report: report),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(report.date),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBalanced
                          ? Colors.green[50]
                          : isOverage
                              ? Colors.blue[50]
                              : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.cashReconciliation.reconciliationStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isBalanced
                            ? Colors.green[700]
                            : isOverage
                                ? Colors.blue[700]
                                : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Sales Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn(
                    'Total Sales',
                    'Rs. ${report.totalSales.toStringAsFixed(2)}',
                    Colors.green,
                  ),
                  _buildStatColumn(
                    'Transactions',
                    '${report.totalOrderCount}',
                    Colors.blue,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Cash Reconciliation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn(
                    'Expected Cash',
                    'Rs. ${report.cashReconciliation.systemExpectedCash.toStringAsFixed(2)}',
                    Colors.orange,
                  ),
                  _buildStatColumn(
                    'Actual Cash',
                    'Rs. ${report.cashReconciliation.actualCash.toStringAsFixed(2)}',
                    Colors.teal,
                  ),
                ],
              ),

              if (report.cashReconciliation.difference != 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBalanced
                        ? Colors.green[50]
                        : isOverage
                            ? Colors.blue[50]
                            : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOverage ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: isOverage ? Colors.blue[700] : Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Difference: Rs. ${report.cashReconciliation.difference.abs().toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOverage ? Colors.blue[700] : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // View Details Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EODReportDetailScreen(report: report),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(
                      'View Details',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}