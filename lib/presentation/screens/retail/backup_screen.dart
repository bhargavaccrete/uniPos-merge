import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';

import '../../../domain/services/retail/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  List<File> _backups = [];
  bool _isLoading = false;
  bool _autoBackupEnabled = true;
  DateTime? _lastBackupDate;
  String? _backupDirectory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final backups = await _backupService.getLocalBackups();
    final autoBackup = await _backupService.isAutoBackupEnabled();
    final lastBackup = await _backupService.getLastBackupDate();
    final backupDir = await _backupService.getBackupDirectoryPath();

    setState(() {
      _backups = backups;
      _autoBackupEnabled = autoBackup;
      _lastBackupDate = lastBackup;
      _backupDirectory = backupDir;
      _isLoading = false;
    });
  }

  void _showBackupLocation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backups are stored at:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: SelectableText(
                _backupDirectory ?? 'Loading...',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can access these files using:',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 8),
            const Text(
              '• File Manager app on your device\n'
              '• Connect device to computer via USB\n'
              '• Share button to export to cloud storage',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    try {
      setState(() => _isLoading = true);

      final backupFile = await _backupService.createBackup();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created successfully: ${backupFile.path.split('/').last}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareBackup(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'rPOS Backup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBackupInfo(File file) async {
    final info = await _backupService.getBackupInfo(file);

    if (!mounted) return;

    final stats = info['statistics'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(info['fileName'] ?? 'Backup Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Version', info['version'] ?? 'Unknown'),
              _buildInfoRow('Export Date', _formatDate(info['exportDate'])),
              _buildInfoRow('File Size', _formatFileSize(info['fileSize'] ?? 0)),
              _buildInfoRow('Last Modified', _formatDate(info['lastModified'])),
              const Divider(),
              const Text('Statistics:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildInfoRow('Products', '${stats['totalProducts'] ?? 0}'),
              _buildInfoRow('Variants', '${stats['totalVariants'] ?? 0}'),
              _buildInfoRow('Sales', '${stats['totalSales'] ?? 0}'),
              _buildInfoRow('Customers', '${stats['totalCustomers'] ?? 0}'),
              _buildInfoRow('Suppliers', '${stats['totalSuppliers'] ?? 0}'),
              _buildInfoRow('Purchases', '${stats['totalPurchases'] ?? 0}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Are you sure you want to delete ${file.path.split('/').last}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _backupService.deleteBackup(file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete backup: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    await _backupService.setAutoBackupEnabled(value);
    setState(() => _autoBackupEnabled = value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto backup ${value ? 'enabled' : 'disabled'}'),
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    try {
      // Open file picker to select backup file
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'JSON Backup Files',
        extensions: ['json'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (file == null) {
        // User cancelled the picker
        return;
      }

      // Convert XFile to File
      final backupFile = File(file.path);

      // Validate the backup file first
      final validation = await _backupService.validateBackupFile(backupFile);

      if (validation['valid'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid backup file: ${validation['error']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Show file info and confirm restore
      final info = await _backupService.getBackupInfo(backupFile);
      if (!mounted) return;

      final stats = info['statistics'] as Map<String, dynamic>? ?? {};

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Backup'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Found valid backup file:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('File Name', info['fileName'] ?? 'Unknown'),
                _buildInfoRow('Version', info['version'] ?? 'Unknown'),
                _buildInfoRow('Export Date', _formatDate(info['exportDate'])),
                _buildInfoRow('File Size', _formatFileSize(info['fileSize'] ?? 0)),
                const Divider(),
                const Text('Contains:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 8),
                _buildInfoRow('Products', '${stats['totalProducts'] ?? 0}'),
                _buildInfoRow('Customers', '${stats['totalCustomers'] ?? 0}'),
                _buildInfoRow('Suppliers', '${stats['totalSuppliers'] ?? 0}'),
                _buildInfoRow('Sales', '${stats['totalSales'] ?? 0}'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This will add data from the backup to your current data.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Import & Restore'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // Restore the backup
        await _restoreBackup(backupFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup(File file) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to restore from ${file.path.split('/').last}?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This will add data from the backup to your current data.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);

        final result = await _backupService.restoreFromBackup(file);

        if (mounted) {
          setState(() => _isLoading = false);

          if (result['success'] == true) {
            // Show success dialog with details
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Text('Restore Successful'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result['message'] ?? 'Backup restored successfully'),
                    if (result['errors'] != null && (result['errors'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Some items had errors:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ...(result['errors'] as List).take(3).map((error) => Text(
                        '• $error',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
                      )),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );

            _loadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Restore failed: ${result['error']}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to restore backup: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr == 'Unknown') return 'Unknown';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('MMM dd, yyyy hh:mm a').format(date);
    } catch (e) {
      return dateStr.toString();
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B6B6B))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Auto Backup Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.backup, color: Colors.blue.shade700, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto Backup',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Automatically backup data once per day',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _autoBackupEnabled,
                            onChanged: _toggleAutoBackup,
                          ),
                        ],
                      ),
                      if (_lastBackupDate != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Last backup: ${DateFormat('MMM dd, yyyy hh:mm a').format(_lastBackupDate!)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Create Backup Button
                ElevatedButton.icon(
                  onPressed: _createBackup,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Create New Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Import Backup Button
                OutlinedButton.icon(
                  onPressed: _importBackup,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import Backup File'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Backups List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Local Backups',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _showBackupLocation,
                          icon: const Icon(Icons.folder_outlined, size: 16),
                          label: const Text('Location', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_backups.length} backups',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Backups List
                if (_backups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'No backups found',
                          style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first backup to get started',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
                        ),
                      ],
                    ),
                  )
                else
                  ..._backups.map((file) => _buildBackupCard(file)),
              ],
            ),
    );
  }

  Widget _buildBackupCard(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = file.lengthSync();
    final lastModified = file.lastModifiedSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatFileSize(fileSize)} • ${DateFormat('MMM dd, yyyy hh:mm a').format(lastModified)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBackupInfo(file),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Info'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareBackup(file),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _restoreBackup(file),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Restore'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _deleteBackup(file),
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.red,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}