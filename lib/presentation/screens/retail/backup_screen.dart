import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/domain/services/common/auto_backup_service.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/backup_password_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
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
  bool _hasBackupPassword = false;
  bool _autoBackupEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Card wrapper shared by the two new setting rows.
  Widget _settingCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      border: Border.all(color: AppColors.divider),
    ),
    child: child,
  );

  Widget _buildPasswordCard(BuildContext context) {
    final accent = _hasBackupPassword ? AppColors.success : AppColors.warning;

    return _settingCard(
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
          ),
          child: Icon(
            _hasBackupPassword ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: accent,
            size: AppResponsive.iconSize(context),
          ),
        ),
        title: Text(
          'Backup Password',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          _hasBackupPassword
              ? 'Set — backups are encrypted with it'
              : 'Not set — you will be asked before the first backup',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () async {
                final saved = await showBackupPasswordDialog(
                  context,
                  isChange: _hasBackupPassword,
                );
                if (saved && mounted) {
                  setState(() => _hasBackupPassword = true);
                }
              },
              child: Text(_hasBackupPassword ? 'Change' : 'Set'),
            ),
            if (_hasBackupPassword)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                tooltip: 'Remove password',
                onPressed: () async {
                  final removed = await confirmRemoveBackupPassword(context);
                  if (removed && mounted) {
                    setState(() => _hasBackupPassword = false);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context) {
    return _settingCard(
      child: SwitchListTile(
        value: _autoBackupEnabled,
        activeThumbColor: AppColors.success,
        onChanged: (value) async {
          await AutoBackupService.setAutoBackupEnabled(value);
          if (mounted) setState(() => _autoBackupEnabled = value);
        },
        secondary: Container(
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color:
                (_autoBackupEnabled
                        ? AppColors.success
                        : AppColors.textSecondary)
                    .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
          ),
          child: Icon(
            Icons.alarm_rounded,
            color: _autoBackupEnabled
                ? AppColors.success
                : AppColors.textSecondary,
            size: AppResponsive.iconSize(context),
          ),
        ),
        title: Text(
          'Daily Backup Reminder',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'Show a backup prompt at the start of each day',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Password + reminder state, read from the same shared services restaurant
    // reads them from.
    _hasBackupPassword = await BackupEncryptionService.hasPassword();
    _autoBackupEnabled = await AutoBackupService.isAutoBackupEnabled();

    // Get backup files from Downloads folder
    final backupDir = await UnifiedBackupService.downloadsBackupPath();
    _backupDirectory = backupDir;

    try {
      final dir = Directory(backupDir);
      if (await dir.exists()) {
        final files = dir
            .listSync()
            .whereType<File>()
            .where(
              (file) =>
                  file.path.endsWith('.zip') &&
                  // Match current and all legacy backup prefixes so older
                  // backups still appear: UniPOS_*, BillBerry_*, BillBerryLite_*.
                  (file.path.contains('UniPOS_') ||
                      file.path.contains('BillBerry')),
            )
            .toList();

        // Sort by modified date (newest first)
        files.sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );

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
        title: Text('Backup Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backups are stored at:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: AppResponsive.bodyFontSize(context),
              ),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                border: Border.all(color: AppColors.divider),
              ),
              child: SelectableText(
                _backupDirectory ?? 'Loading...',
                // Monospace on purpose — this is a filesystem path, not UI
                // copy, so it does NOT take the app typeface.
                style: TextStyle(
                  fontSize: AppResponsive.captionFontSize(context),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            Text(
              'You can access these files using:',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              '• File Manager app on your device\n'
              '• Connect device to computer via USB\n'
              '• Share button to export to cloud storage',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    try {
      // Backups are always encrypted — make sure a password is set first.
      if (!await UnifiedBackupService.ensureBackupPassword(context)) return;
      if (!mounted) return;

      setState(() => _isLoading = true);

      // Use UnifiedBackupService to create ZIP backup
      final backupFilePath = await UnifiedBackupService.exportToDownloads();

      if (mounted) {
        setState(() => _isLoading = false);

        if (backupFilePath != null) {
          NotificationService.instance.showSuccess(
            'Backup created successfully: ${backupFilePath.split('/').last}',
          );
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
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Bill Berry Lite Backup');
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
              _buildInfoRow(
                'Last Modified',
                _formatDate(lastModified.toIso8601String()),
              ),
              _buildInfoRow('Format', 'ZIP Archive'),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              Text(
                'This is a complete backup including all products, sales, customers, suppliers, purchases, and settings.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBackup(File file) async {
    // Defence in depth. The entrance is gated three ways already (dashboard
    // has no backup card, the Settings tile and the route both check
    // 'dataBackup'), but this operation can overwrite the entire database,
    // so it verifies for itself rather than trusting how it was reached.
    if (!RestaurantSession.canAccess('dataBackup')) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Backup'),
        content: Text(
          'Are you sure you want to delete ${file.path.split(Platform.pathSeparator).last}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
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
          NotificationService.instance.showSuccess(
            'Backup deleted successfully',
          );
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
    // Defence in depth. The entrance is gated three ways already (dashboard
    // has no backup card, the Settings tile and the route both check
    // 'dataBackup'), but this operation can overwrite the entire database,
    // so it verifies for itself rather than trusting how it was reached.
    if (!RestaurantSession.canAccess('dataBackup')) return;
    try {
      // Open file picker to select backup file (ZIP or JSON)
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Backup Files',
        extensions: ['zip', 'json'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

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
          title: Text('Import Backup'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Found backup file:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: AppResponsive.bodyFontSize(context),
                  ),
                ),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                _buildInfoRow('File Name', fileName),
                _buildInfoRow('File Size', _formatFileSize(fileSize)),
                _buildInfoRow(
                  'Format',
                  fileName.endsWith('.zip') ? 'ZIP Archive' : 'JSON',
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),
                Container(
                  padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.orange.shade700,
                        size: AppResponsive.iconSize(context),
                      ),
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Expanded(
                        child: Text(
                          'This will restore all data from the backup file.',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                          ),
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
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Import & Restore'),
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
    // Defence in depth. The entrance is gated three ways already (dashboard
    // has no backup card, the Settings tile and the route both check
    // 'dataBackup'), but this operation can overwrite the entire database,
    // so it verifies for itself rather than trusting how it was reached.
    if (!RestaurantSession.canAccess('dataBackup')) return;
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to restore from ${file.path.split('/').last}?',
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.orange.shade700,
                    size: AppResponsive.iconSize(context),
                  ),
                  SizedBox(width: AppResponsive.smallSpacing(context)),
                  Expanded(
                    child: Text(
                      'This will add data from the backup to your current data.',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                      ),
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
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);

        // Use UnifiedBackupService to restore
        final success = await UnifiedBackupService.importFromFilePath(
          context,
          file.path,
        );

        if (mounted) {
          setState(() => _isLoading = false);

          if (success) {
            // Show success dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 28),
                    SizedBox(width: AppResponsive.mediumSpacing(context)),
                    Text('Restore Successful'),
                  ],
                ),
                content: Text(
                  'Backup restored successfully! All data has been imported.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context); // Go back to main screen
                    },
                    child: Text('OK'),
                  ),
                ],
              ),
            );

            _loadData();
          } else {
            NotificationService.instance.showError(
              'Restore failed. Please check the backup file.',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          NotificationService.instance.showError(
            'Failed to restore backup: $e',
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
          Text(
            label,
            style: GoogleFonts.poppins(color: AppColors.textSecondary),
          ),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Backup & Restore',
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxCardWidth(context),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : ListView(
                padding: AppResponsive.padding(context),
                children: [
                  // Backup password — retail had no way to set, change or clear it,
                  // even though every backup is encrypted with it and the shared
                  // service already supports all three.
                  _buildPasswordCard(context),

                  SizedBox(height: AppResponsive.mediumSpacing(context)),

                  // Daily reminder — the same AutoBackupService toggle restaurant has.
                  _buildReminderCard(context),

                  SizedBox(height: AppResponsive.largeSpacing(context)),

                  // Create Backup Button
                  ElevatedButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text('Create New Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  SizedBox(height: AppResponsive.mediumSpacing(context)),

                  // Import Backup Button
                  OutlinedButton.icon(
                    onPressed: _importBackup,
                    icon: const Icon(Icons.file_upload),
                    label: Text('Import Backup File'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  SizedBox(height: AppResponsive.extraLargeSpacing(context)),

                  // Backups List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Local Backups',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _showBackupLocation,
                            icon: Icon(Icons.folder_outlined, size: 16),
                            label: Text(
                              'Location',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.captionFontSize(
                                  context,
                                ),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Text(
                            '${_backups.length} backups',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: AppResponsive.mediumSpacing(context)),

                  // Backups List
                  if (_backups.isEmpty)
                    Container(
                      padding: EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          SizedBox(height: AppResponsive.largeSpacing(context)),
                          Text(
                            'No backups found',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: AppResponsive.smallSpacing(context)),
                          Text(
                            'Create your first backup to get started',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._backups.map((file) => _buildBackupCard(file)),
                ],
              ),
      ),
    );
  }

  Widget _buildBackupCard(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = file.lengthSync();
    final lastModified = file.lastModifiedSync();

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: Colors.blue.shade700, size: 24),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_formatFileSize(fileSize)} • ${DateFormat('MMM dd, yyyy hh:mm a').format(lastModified)}',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBackupInfo(file),
                  icon: Icon(Icons.info_outline, size: 16),
                  label: Text('Info'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: AppResponsive.smallSpacing(context),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareBackup(file),
                  icon: Icon(Icons.share, size: 16),
                  label: Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: AppResponsive.smallSpacing(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _restoreBackup(file),
                  icon: const Icon(Icons.restore, size: 16),
                  label: Text('Restore'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: AppResponsive.smallSpacing(context),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              IconButton(
                onPressed: () => _deleteBackup(file),
                icon: Icon(
                  Icons.delete_outline,
                  size: AppResponsive.iconSize(context),
                ),
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
