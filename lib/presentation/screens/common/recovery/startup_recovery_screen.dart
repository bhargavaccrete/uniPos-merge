import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_safe_open.dart';
import 'package:billberrylite/core/init/restore_record.dart';
import 'package:billberrylite/core/init/startup_recovery.dart';
import 'package:billberrylite/data/repositories/business_type_repository.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// What the Recovery screen calls. Production wiring by default; tests swap
/// the platform parts (file picker, folders, app exit).
class RecoveryActions {
  final Future<HiveStartupBlocked?> Function() retry;
  final Future<String?> Function() pickBackupFile;

  /// Saves the encrypted export the way this platform allows (Android:
  /// Downloads, then the Save dialog; desktop: the Save dialog).
  final Future<ExportOutcome> Function(String password) exportFile;
  final Future<String?> Function() storedPassword;

  /// The existing restore. Production: `importFromFilePath` with the
  /// password already checked.
  final Future<bool> Function(BuildContext context, String path, String password)
      runRestore;

  /// Builds what the existing restore expects (the service locator).
  final Future<void> Function() prepareServices;

  /// After a successful restore. Production: the existing restart prompt,
  /// which closes the app so every store reloads the restored data.
  final Future<void> Function() afterRestored;

  const RecoveryActions({
    this.retry = StartupRecovery.retry,
    this.pickBackupFile = _pickBackupFile,
    this.exportFile = _exportForThisPlatform,
    this.storedPassword = BackupEncryptionService.getStoredPassword,
    this.runRestore = _importFromFilePath,
    this.prepareServices = prepareServicesForRecovery,
    this.afterRestored = UnifiedBackupService.promptRestartAfterRestore,
  });

  static Future<String?> _pickBackupFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    return picked?.files.single.path;
  }

  static Future<ExportOutcome> _exportForThisPlatform(String password) =>
      StartupRecovery.exportForThisPlatform(password: password);

  static Future<bool> _importFromFilePath(
          BuildContext context, String path, String password) =>
      UnifiedBackupService.importFromFilePath(context, path,
          password: password, fromRecovery: true);
}

/// Builds the service locator from scratch (a failed restore may have built
/// it already).
Future<void> prepareServicesForRecovery() async {
  if (locator.isRegistered<BusinessTypeRepository>()) {
    await resetServiceLocator();
  }
  await setupServiceLocator();
}

/// Root widget shown instead of the app when [HiveStartupBlocked] stops
/// startup. Uses the app's global navigator and messenger keys, which the
/// existing restore uses for its own dialogs.
class StartupRecoveryApp extends StatelessWidget {
  final HiveStartupBlocked blocked;
  final Future<void> Function() onRecovered;
  final RecoveryActions actions;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  const StartupRecoveryApp({
    super.key,
    required this.blocked,
    required this.onRecovered,
    this.actions = const RecoveryActions(),
    this.navigatorKey,
    this.scaffoldMessengerKey,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Bill Berry Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins'),
      home: StartupRecoveryScreen(
        blocked: blocked,
        onRecovered: onRecovered,
        actions: actions,
      ),
    );
  }
}

class StartupRecoveryScreen extends StatefulWidget {
  final HiveStartupBlocked blocked;

  /// Continues normal startup. Called only once every box has opened.
  final Future<void> Function() onRecovered;
  final RecoveryActions actions;

  const StartupRecoveryScreen({
    super.key,
    required this.blocked,
    required this.onRecovered,
    this.actions = const RecoveryActions(),
  });

  @override
  State<StartupRecoveryScreen> createState() => _StartupRecoveryScreenState();
}

class _StartupRecoveryScreenState extends State<StartupRecoveryScreen> {
  late HiveStartupBlocked _blocked = widget.blocked;
  bool _busy = false;
  String? _busyText;

  List<HiveBoxFailure> get _failures => _blocked.failures;

  /// BKP-5: an unfinished restore (record still open).
  RestoreRecord? get _interrupted => _blocked.interruptedRestore;

  Future<void> _run(String text, Future<void> Function() body) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyText = text;
    });
    try {
      await body();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyText = null;
        });
      }
    }
  }

  // ── Retry ────────────────────────────────────────────────────────────────

  Future<void> _retry() => _run('Trying again…', () async {
        final still = await widget.actions.retry();
        if (still == null) {
          await widget.onRecovered();
          return;
        }
        if (!mounted) return;
        setState(() => _blocked = still);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Still could not open: '
              '${still.failures.map((f) => f.boxName).join(', ')}'),
        ));
      });

  // ── Restore ──────────────────────────────────────────────────────────────

  Future<void> _restore() async {
    final path = await widget.actions.pickBackupFile();
    if (path == null || !mounted) return;
    final password = await _askPassword(
      title: 'Backup Password',
      subtitle: 'Enter the password of this backup',
      confirmLabel: 'Check Backup',
    );
    if (password == null || !mounted) return;

    final deviceMode = StartupRecovery.deviceMode(_failures);
    String? mode;
    Object? refused;
    await _run('Checking the backup…', () async {
      try {
        mode = await StartupRecovery.checkBackup(
            path: path, password: password, deviceMode: deviceMode);
      } catch (e) {
        refused = e;
      }
    });
    if (!mounted) return;
    if (mode == null) {
      // Shown after the busy overlay is gone.
      await showAppErrorDialog(
        context: context,
        title: 'Backup Not Used',
        message: '${_plain(refused ?? 'Unknown error')}\n\nNothing on this '
            'device was changed.',
      );
      return;
    }

    final label = mode == 'retail' ? 'Retail' : 'Restaurant';
    final unknownMode = deviceMode == null
        ? '\n\nThis device\'s business type could not be read. This is a '
            '$label backup — continue only if this device is $label.'
        : '';
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Replace Business Data?',
      message: 'Restoring replaces ALL business data on this device with the '
          '$label backup "${p.basename(path)}". Anything recorded after that '
          'backup was made will not be in it.\n\n'
          'The damaged files stay saved in the recovery folder and are not '
          'changed. If the restore does not finish, they are put back.'
          '$unknownMode',
      confirmLabel: 'Restore',
      accent: AppColors.warning,
      icon: Icons.restore_rounded,
      barrierDismissible: false,
    );
    if (!ok || !mounted) return;

    RecoveryRestoreOutcome? outcome;
    await _run('Restoring the backup…', () async {
      outcome = await StartupRecovery.restore(
        failures: _failures,
        runRestore: () => widget.actions.runRestore(context, path, password),
        prepareServices: widget.actions.prepareServices,
        interrupted: _interrupted,
      );
    });
    final result = outcome;
    if (result == null || !mounted) return;
    if (result.result == RecoveryRestoreResult.restored) {
      await widget.actions.afterRestored();
      return;
    }
    if (result.blocked == null) {
      await widget.onRecovered();
      return;
    }
    setState(() => _blocked = result.blocked!);
    await showAppErrorDialog(
      context: context,
      title: 'Restore Not Completed',
      message: 'The backup was not restored. ${_interrupted == null ? 'The original damaged files were put back unchanged and are still saved' : 'The safety copy from before the earlier restore is still kept'}, '
          'and the till stays stopped.'
          '${result.error == null ? '' : '\n\n${_plain(result.error!)}'}',
    );
  }

  // ── Undo an interrupted restore (BKP-5) ──────────────────────────────────

  Future<void> _undo() async {
    final record = _interrupted;
    if (record == null || !record.canUndo) return;
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Undo the Unfinished Restore?',
      message: 'This puts back the business data exactly as it was before the '
          'restore started (${DateFormat('dd MMM yyyy, hh:mm a').format(record.startedAt)}), '
          'including unfinished stock work. Anything the unfinished restore '
          'wrote is replaced.',
      confirmLabel: 'Undo',
      accent: AppColors.warning,
      icon: Icons.undo_rounded,
      barrierDismissible: false,
    );
    if (!ok || !mounted) return;
    final pin = await _askPassword(
      title: 'Safety Copy PIN',
      subtitle: record.pin == SnapshotPin.deviceBackupPin
          ? 'Enter this device\'s backup PIN as it was before the restore '
              'started.'
          : 'Enter the PIN of the backup you were restoring.',
      confirmLabel: 'Undo',
    );
    if (pin == null || !mounted) return;

    RecoveryRestoreOutcome? outcome;
    await _run('Putting the earlier data back…', () async {
      outcome = await StartupRecovery.undo(
        record: record,
        runRestore: (snapshot) =>
            widget.actions.runRestore(context, snapshot, pin),
        prepareServices: widget.actions.prepareServices,
      );
    });
    final result = outcome;
    if (result == null || !mounted) return;
    if (result.result == RecoveryRestoreResult.restored) {
      await widget.actions.afterRestored();
      return;
    }
    if (result.blocked != null) setState(() => _blocked = result.blocked!);
    await showAppErrorDialog(
      context: context,
      title: 'Undo Not Completed',
      message: 'The earlier data was not fully put back. The safety copy is '
          'still kept and the till stays stopped; you can try Undo again or '
          'restore a backup.'
          '${result.error == null ? '' : '\n\n${_plain(result.error!)}'}',
    );
  }

  // ── Export ───────────────────────────────────────────────────────────────

  Future<void> _export() async {
    var password = await widget.actions.storedPassword();
    final usingBackupPassword = password != null && password.isNotEmpty;
    if (!usingBackupPassword) {
      if (!mounted) return;
      password = await _askNewPassword();
    }
    if (password == null || !mounted) return;
    final secret = password;

    // The result dialog opens after the busy overlay is gone.
    ExportOutcome? outcome;
    Object? failure;
    await _run('Exporting…', () async {
      try {
        outcome = await widget.actions.exportFile(secret);
      } catch (e) {
        failure = e;
      }
    });
    if (!mounted) return;
    final result = outcome;
    if (result == null) {
      await showAppErrorDialog(
        context: context,
        title: 'Export Failed',
        message: '${_plain(failure ?? 'Unknown error')}\n\nThe preserved files '
            'on this device were not changed.',
      );
      return;
    }
    if (result.kind == ExportOutcomeKind.cancelled) {
      await showAppInfoDialog(
        context: context,
        title: 'Export Not Saved',
        message: '${result.note ?? 'Export cancelled.'}\n\nNothing was saved, '
            'and the preserved files on this device were not changed.',
        accent: AppColors.warning,
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    final where = result.kind == ExportOutcomeKind.savedViaDialog
        ? 'to the location you chose:\n${result.location}'
        : 'to:\n${result.location}';
    await showAppInfoDialog(
      context: context,
      title: 'Export Saved',
      message: 'The preserved files were saved, encrypted, $where'
          '${result.note == null ? '' : '\n\n${result.note}'}\n\n'
          'It is locked with ${usingBackupPassword ? 'your backup password' : 'the password you just entered'}. '
          'Send the file to support; share the password separately.',
      accent: AppColors.success,
      icon: Icons.check_circle_rounded,
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  Future<String?> _askPassword({
    required String title,
    required String subtitle,
    required String confirmLabel,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppDialogShell(
        title: title,
        subtitle: subtitle,
        accent: AppColors.primary,
        icon: Icons.lock_outline_rounded,
        body: AppTextField(
          key: const Key('recoveryPassword'),
          controller: controller,
          obscureText: true,
          autofocus: true,
          label: 'Backup Password',
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          appDialogCancelButton(ctx),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: confirmLabel,
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          ),
        ],
      ),
    );
  }

  Future<String?> _askNewPassword() {
    final first = TextEditingController();
    final second = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AppDialogShell(
          title: 'Export Password',
          subtitle: 'No backup password is set. Choose a 6-digit password '
              'to lock the export.',
          accent: AppColors.primary,
          icon: Icons.lock_outline_rounded,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                key: const Key('exportPassword'),
                controller: first,
                obscureText: true,
                autofocus: true,
                label: 'Password (6 digits)',
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: AppResponsive.smallSpacing(ctx)),
              AppTextField(
                key: const Key('exportPasswordConfirm'),
                controller: second,
                obscureText: true,
                label: 'Confirm Password',
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (error != null)
                Text(error!,
                    style: GoogleFonts.poppins(
                        color: AppColors.danger,
                        fontSize: AppResponsive.smallFontSize(ctx))),
            ],
          ),
          actions: [
            appDialogCancelButton(ctx),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Export',
              onPressed: () {
                final err = BackupEncryptionService.validatePassword(
                    first.text.trim(), second.text.trim());
                if (err != null) {
                  setState(() => error = err);
                  return;
                }
                Navigator.pop(ctx, first.text.trim());
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _plain(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  // ── Layout ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final files = StartupRecovery.filesSupported;
    final interrupted = _interrupted;
    final canRestore =
        StartupRecovery.canRestore(_failures, interrupted: interrupted);
    final hasPreserved = StartupRecovery.exportSources().isNotEmpty;
    final inUse = _failures.any((f) => f.kind == HiveBoxFailureKind.inaccessible);
    final gap = SizedBox(height: AppResponsive.mediumSpacing(context));

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: buildPrimaryAppBar(
          title: 'Data Recovery',
          automaticallyImplyLeading: false,
          titleFontSize: AppResponsive.subheadingFontSize(context),
        ),
        body: Stack(
          children: [
            AppResponsive.constrainedContent(
              context: context,
              maxWidth: AppResponsive.maxFormWidth(context),
              alignment: Alignment.topCenter,
              child: ListView(
                padding: AppResponsive.screenPadding(context),
                children: [
                  if (interrupted != null)
                    _card(
                      context,
                      key: const Key('interruptedRestore'),
                      icon: Icons.history_toggle_off_rounded,
                      color: AppColors.danger,
                      title: 'A restore did not finish',
                      body: interrupted.readable
                          ? 'A restore started '
                              '${DateFormat('dd MMM yyyy, hh:mm a').format(interrupted.startedAt)} '
                              'was interrupted. Business data may be partly '
                              'replaced, so the till stays stopped and no '
                              'unfinished stock work is replayed. '
                              '${interrupted.canUndo ? 'Undo puts back the data from before that restore, or restore a backup.' : 'Restore a backup to continue.'}'
                          : 'A restore was interrupted and its details could '
                              'not be read. The till stays stopped. Restore a '
                              'backup to continue.',
                    )
                  else
                    _card(
                      context,
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      title: 'Some saved data could not be opened',
                      body: 'Bill Berry Lite stopped before opening the till, '
                          'so no sales are recorded against incomplete data. '
                          'Nothing was deleted or repaired.',
                    ),
                  gap,
                  for (final f in _failures) ...[
                    _failureCard(context, f),
                    gap,
                  ],
                  _actions(context,
                      files: files,
                      canRestore: canRestore,
                      hasPreserved: hasPreserved,
                      inUse: inUse,
                      interrupted: interrupted),
                  gap,
                  if (files)
                    _card(
                      context,
                      icon: Icons.help_outline_rounded,
                      color: AppColors.info,
                      title: 'No backup?',
                      body: 'The original damaged data has been kept on this '
                          'device where it could be copied (see above). '
                          'Automatic recovery is not possible without a '
                          'backup. Export the preserved files and send them to '
                          'support: some records may be recoverable by hand, '
                          'but this is not guaranteed. Do not uninstall the app '
                          'or clear its data — that would delete these files.',
                    )
                  else
                    _card(
                      context,
                      icon: Icons.public_rounded,
                      color: AppColors.info,
                      title: 'Browser version',
                      body: 'In the browser, damaged data cannot be copied, '
                          'exported or replaced from a backup here. It is left '
                          'untouched in the browser\'s storage. Tap Retry, or '
                          'contact support. Do not clear the browser\'s site '
                          'data.',
                    ),
                ],
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: AppResponsive.cardPadding(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            SizedBox(width: AppResponsive.mediumSpacing(context)),
                            Text(_busyText ?? '',
                                style: GoogleFonts.poppins(
                                    fontSize:
                                        AppResponsive.bodyFontSize(context))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static (String, Color) _category(HiveBoxFailureKind kind) {
    switch (kind) {
      case HiveBoxFailureKind.corrupted:
        return ('Damaged data', AppColors.danger);
      case HiveBoxFailureKind.unreadable:
        return ('Compatibility – may be from a newer app version',
            AppColors.warning);
      case HiveBoxFailureKind.inaccessible:
        return ('Temporarily in use', AppColors.info);
      case HiveBoxFailureKind.preservationFailed:
        return ('Damaged – safe copy failed', AppColors.danger);
    }
  }

  Widget _failureCard(BuildContext context, HiveBoxFailure f) {
    final (label, color) = _category(f.kind);
    final small = GoogleFonts.poppins(
        fontSize: AppResponsive.smallFontSize(context),
        color: AppColors.textSecondary);
    final body = GoogleFonts.poppins(
        fontSize: AppResponsive.bodyFontSize(context),
        color: AppColors.textPrimary);
    final String kept;
    switch (f.kind) {
      case HiveBoxFailureKind.inaccessible:
        kept = 'Not needed — nothing was changed.';
      case HiveBoxFailureKind.preservationFailed:
        kept = 'No — a safe copy could not be made '
            '(${f.preservationError ?? 'unknown reason'}). The original file '
            'was left untouched and was not repaired.';
      case HiveBoxFailureKind.corrupted:
      case HiveBoxFailureKind.unreadable:
        kept = f.preserved != null
            ? 'Yes — a verified copy was saved.'
            : 'Left untouched in this device\'s storage.';
    }
    return Container(
      key: ValueKey('failure-${f.boxName}'),
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.boxName,
              style: GoogleFonts.poppins(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          AppStatusPill(label: label, color: color),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(f.describe().replaceFirst('• ${f.boxName}: ', ''), style: body),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text('Original kept: $kept', style: body),
          if (f.preserved != null) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text('Saved copy:', style: small),
            SelectableText(f.preserved!.path, style: small),
          ],
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
              'Detected: ${DateFormat('dd MMM yyyy, hh:mm:ss a').format(f.detectedAt)}',
              style: small),
          Text('Details: ${f.error}', style: small),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context, {
    required bool files,
    required bool canRestore,
    required bool hasPreserved,
    required bool inUse,
    required RestoreRecord? interrupted,
  }) {
    final note = GoogleFonts.poppins(
        fontSize: AppResponsive.smallFontSize(context),
        color: AppColors.textSecondary);
    final gap = SizedBox(height: AppResponsive.smallSpacing(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // BKP-5: after an unfinished restore every box may open while the
        // data is mixed — Retry would start the till on it, so it is hidden.
        if (interrupted == null)
          _button(
            context,
            key: const Key('recoveryRetry'),
            icon: Icons.refresh_rounded,
            label: 'Retry',
            filled: !canRestore,
            onPressed: _busy ? null : _retry,
          ),
        if (files && interrupted != null && interrupted.canUndo)
          _button(
            context,
            key: const Key('recoveryUndo'),
            icon: Icons.undo_rounded,
            label: 'Undo the Unfinished Restore',
            filled: true,
            onPressed: _busy ? null : _undo,
          ),
        if (files) ...[
          if (interrupted == null || interrupted.canUndo) gap,
          _button(
            context,
            key: const Key('recoveryRestore'),
            icon: Icons.restore_rounded,
            label: 'Restore from Backup',
            filled: true,
            onPressed: _busy || !canRestore ? null : _restore,
          ),
          if (inUse)
            Padding(
              padding: EdgeInsets.only(top: AppResponsive.smallSpacing(context)),
              child: Text(
                  'A file is in use. Close any other Bill Berry Lite window '
                  'and tap Retry before restoring.',
                  style: note),
            ),
          if (hasPreserved) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _button(
              context,
              key: const Key('recoveryExport'),
              icon: Icons.ios_share_rounded,
              label: interrupted == null
                  ? 'Export Damaged Files for Support'
                  : 'Export for Support',
              filled: false,
              onPressed: _busy ? null : _export,
            ),
          ],
        ],
      ],
    );
  }

  Widget _button(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback? onPressed,
  }) {
    // One line, scaled down on narrow phones: a wrapped button label is hard
    // to read and re-lays out badly when the button changes state.
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label,
          maxLines: 1,
          style: GoogleFonts.poppins(
              fontSize: AppResponsive.buttonFontSize(context),
              fontWeight: FontWeight.w600)),
    );
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    final size = Size.fromHeight(AppResponsive.buttonHeight(context));
    return filled
        ? ElevatedButton.icon(
            key: key,
            onPressed: onPressed,
            icon: Icon(icon),
            label: text,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              minimumSize: size,
              shape: shape,
            ),
          )
        : OutlinedButton.icon(
            key: key,
            onPressed: onPressed,
            icon: Icon(icon),
            label: text,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: size,
              shape: shape,
            ),
          );
  }

  Widget _card(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      key: key,
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppResponsive.largeIconSize(context)),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                Text(body,
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
