import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';

import '../../../domain/services/common/unified_backup_service.dart';
import '../../../domain/services/restaurant/notification_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<File> _backups = [];
  bool _isLoading = false;
  String? _backupDirectory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Get backup files from Downloads folder
    final backupDir = '/storage/emulated/0/Download';
    _backupDirectory = backupDir;

    try {
      final dir = Directory(backupDir);
      if (await dir.exists()) {
        final files = dir.listSync()
            .whereType<File>()
            .where((file) =>
                file.path.endsWith('.zip') &&
                file.path.contains('UniPOS_backup'))
            .toList();

        // Sort by modified date (newest first)
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        setState(() {
          _backups = files;
          _isLoading = false;
        });
      } else {
        setState(() {
          _backups = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _backups = [];
        _isLoading = false;
      });
    }
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

      // Use UnifiedBackupService to create ZIP backup
      final backupFilePath = await UnifiedBackupService.exportToDownloads();

      if (mounted) {
        setState(() => _isLoading = false);

        if (backupFilePath != null) {
          NotificationService.instance.showSuccess('Backup created successfully: ${backupFilePath.split('/').last}');
          _loadData();
        } else {
          NotificationService.instance.showError('Failed to create backup');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        NotificationService.instance.showError('Failed to create backup: $e');
      }
    }
  }

  Future<void> _shareBackup(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'rPOS Backup');
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Failed to share backup: $e');
      }
    }
  }

  Future<void> _showBackupInfo(File file) async {
    if (!mounted) return;

    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = await file.length();
    final lastModified = file.lastModifiedSync();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('File Name', fileName),
              _buildInfoRow('File Size', _formatFileSize(fileSize)),
              _buildInfoRow('Last Modified', _formatDate(lastModified.toIso8601String())),
              _buildInfoRow('Format', 'ZIP Archive'),
              const SizedBox(height: 12),
              const Text(
                'This is a complete backup including all products, sales, customers, suppliers, purchases, and settings.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
              ),
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
        content: Text('Are you sure you want to delete ${file.path.split(Platform.pathSeparator).last}?'),
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
        if (await file.exists()) {
          await file.delete();
        }
        if (mounted) {
          NotificationService.instance.showSuccess('Backup deleted successfully');
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          NotificationService.instance.showError('Failed to delete backup: $e');
        }
      }
    }
  }


  Future<void> _importBackup() async {
    try {
      // Open file picker to select backup file (ZIP or JSON)
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Backup Files',
        extensions: ['zip', 'json'],
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
      final fileName = backupFile.path.split(Platform.pathSeparator).last;
      final fileSize = await backupFile.length();

      // Show file info and confirm restore
      if (!mounted) return;

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
                  'Found backup file:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('File Name', fileName),
                _buildInfoRow('File Size', _formatFileSize(fileSize)),
                _buildInfoRow('Format', fileName.endsWith('.zip') ? 'ZIP Archive' : 'JSON'),
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
                          'This will restore all data from the backup file.',
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
        NotificationService.instance.showError('Failed to import backup: $e');
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

        // Use UnifiedBackupService to restore
        final success = await UnifiedBackupService.importFromFilePath(context, file.path);

        if (mounted) {
          setState(() => _isLoading = false);

          if (success) {
            // Show success dialog
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
                content: const Text('Backup restored successfully! All data has been imported.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context); // Go back to main screen
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );

            _loadData();
          } else {
            NotificationService.instance.showError('Restore failed. Please check the backup file.');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          NotificationService.instance.showError('Failed to restore backup: $e');
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