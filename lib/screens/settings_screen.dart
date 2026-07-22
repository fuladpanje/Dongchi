import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/contacts_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/jalali_extension.dart';
import '../services/app_backup_service.dart';

enum BackupDeliveryAction { share, save }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _includeReceiptFiles = true;
  bool _hasSafetyBackup = false;
  DateTime? _safetyBackupCreatedAt;
  bool _isSafetyBackupLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSafetyBackupState();
  }

  Future<void> _loadSafetyBackupState() async {
    final hasSafetyBackup = await AppBackupService.hasSafetyBackup();
    final createdAt = hasSafetyBackup
        ? await AppBackupService.getSafetyBackupCreatedAt()
        : null;

    if (!mounted) {
      return;
    }

    setState(() {
      _hasSafetyBackup = hasSafetyBackup;
      _safetyBackupCreatedAt = createdAt;
      _isSafetyBackupLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  secondary: const Icon(Icons.brightness_4),
                  title: const Text('حالت شب'),
                  value: settings.isDark,
                  onChanged: settings.toggleTheme,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  secondary: const Icon(Icons.visibility_off_outlined),
                  title: const Text('مخفی‌سازی اطلاعات'),
                  subtitle: const Text(
                    'شرکت کنندگان، هزینه ها، مجموع',
                  ),
                  value: settings.hideAmounts,
                  onChanged: settings.setHideAmounts,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.attach_money),
                        title: Text('واحد پول'),
                        subtitle: Text(
                          'واحد نمایش مبلغ‌ها را در برنامه انتخاب کنید',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'toman',
                                label: Text('تومان'),
                                icon: Icon(Icons.payments_outlined),
                              ),
                              ButtonSegment<String>(
                                value: 'rial',
                                label: Text('ریال'),
                                icon: Icon(Icons.payments_rounded),
                              ),
                            ],
                            selected: <String>{settings.currencyUnit},
                            onSelectionChanged: (selected) {
                              settings.setCurrency(selected.first);
                            },
                            showSelectedIcon: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ListTile(
                        leading: Icon(Icons.backup_outlined),
                        title: Text('پشتیبان‌گیری و بازیابی'),
                        subtitle: Text(
                          'رویدادها، هزینه‌ها، مخاطبین و تنظیمات را پشتیبان بگیرید یا بازیابی کنید. بازیابی به‌صورت ادغام انجام می‌شود.',
                          textAlign: TextAlign.justify,
                        ),
                      ),
                      CheckboxListTile(
                        value: _includeReceiptFiles,
                        onChanged: (value) {
                          setState(() {
                            _includeReceiptFiles = value ?? true;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'پشتیبان گیری از رسیدها',
                          textAlign: TextAlign.justify,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _createBackup(context),
                                icon: const Icon(Icons.save_alt),
                                label: const Text('پشتیبان‌گیری'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _restoreBackup(context),
                                icon: const Icon(Icons.restore),
                                label: const Text('بازیابی'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isSafetyBackupLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: LinearProgressIndicator(minHeight: 2),
                        )
                      else if (_hasSafetyBackup) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          child: OutlinedButton.icon(
                            onPressed: () => _restoreSafetyBackup(context),
                            icon: const Icon(Icons.history),
                            label: const Text('بازیابی آخرین نسخه ایمنی'),
                          ),
                        ),
                        if (_safetyBackupCreatedAt != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                            child: Text(
                              'زمان ثبت نسخه ایمنی: ${DateFormat('yyyy/MM/dd HH:mm').format(_safetyBackupCreatedAt!.toLocal()).toPersianNumbers()}',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.justify,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.red),
                  title: const Text(
                    'حذف تمام داده‌ها',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'تمام داده‌های برنامه، شامل رویدادها، مخاطبین و تنظیمات حذف می‌شود',
                  ),
                  onTap: () => _showClearDialog(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createBackup(BuildContext context) async {
    try {
      _showProgressDialog(context, 'در حال ساخت نسخه پشتیبان...');

      final payload = await AppBackupService.buildBackupPayload(
        includeReceiptFiles: _includeReceiptFiles,
      );
      final backupJson = AppBackupService.encodeBackupPayload(payload);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final backupName = 'simple_farsi_backup_$timestamp.json';

      if (!context.mounted) {
        return;
      }

      _hideProgressDialog(context);

      final deliveryAction = await _showBackupDeliveryDialog(context);
      if (deliveryAction == null || !context.mounted) {
        return;
      }

      switch (deliveryAction) {
        case BackupDeliveryAction.share:
          await _shareBackup(context, backupJson, backupName);
          break;
        case BackupDeliveryAction.save:
          await _saveBackup(context, backupJson, backupName);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        _hideProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ساخت نسخه پشتیبان ناموفق بود: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _shareBackup(
    BuildContext context,
    String backupJson,
    String backupName,
  ) async {
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(backupJson)),
          mimeType: 'application/json',
          name: backupName,
        ),
      ],
      text: 'نسخه پشتیبان برنامه simple_farsi_app',
      subject: 'نسخه پشتیبان simple_farsi_app',
      fileNameOverrides: [backupName],
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('نسخه پشتیبان برای اشتراک‌گذاری آماده شد'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveBackup(
    BuildContext context,
    String backupJson,
    String backupName,
  ) async {
    final savedFile = await AppBackupService.saveBackupJson(
      backupJson: backupJson,
      fileName: backupName,
    );

    if (savedFile == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('نسخه پشتیبان ذخیره شد: ${savedFile.path}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
        withData: true,
        dialogTitle: 'انتخاب فایل نسخه پشتیبان',
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final backupJson = await _readPickedFile(file);

      if (backupJson.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فایل انتخاب‌شده خالی است'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final restoreMode = await _showRestoreModeDialog(context);
      if (restoreMode == null || !context.mounted) {
        return;
      }

      final confirmed = await _showRestoreConfirmDialog(
        context,
        restoreMode: restoreMode,
        sourceLabel: 'فایل انتخاب‌شده',
      );
      if (!confirmed || !context.mounted) {
        return;
      }

      _showProgressDialog(context, 'در حال بازیابی داده‌ها...');
      final restoreResult = await AppBackupService.restoreFromJson(
        backupJson,
        expenseProvider: Provider.of<ExpenseProvider>(context, listen: false),
        contactsProvider: Provider.of<ContactsProvider>(context, listen: false),
        settingsProvider: Provider.of<SettingsProvider>(context, listen: false),
        restoreMode: restoreMode,
      );

      if (context.mounted) {
        _hideProgressDialog(context);
        await _loadSafetyBackupState();
        await _showRestoreSummaryDialog(
          context,
          restoreResult,
          sourceLabel: 'فایل انتخاب‌شده',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _hideProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('بازیابی ناموفق بود: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restoreSafetyBackup(BuildContext context) async {
    try {
      final confirmed = await _showRestoreConfirmDialog(
        context,
        restoreMode: RestoreMode.replace,
        sourceLabel: 'آخرین نسخه ایمنی',
      );
      if (!confirmed || !context.mounted) {
        return;
      }

      _showProgressDialog(context, 'در حال بازیابی نسخه ایمنی...');
      final restoreResult = await AppBackupService.restoreSafetyBackup(
        expenseProvider: Provider.of<ExpenseProvider>(context, listen: false),
        contactsProvider: Provider.of<ContactsProvider>(context, listen: false),
        settingsProvider: Provider.of<SettingsProvider>(context, listen: false),
      );

      if (context.mounted) {
        _hideProgressDialog(context);
        await _loadSafetyBackupState();
        await _showRestoreSummaryDialog(
          context,
          restoreResult,
          sourceLabel: 'آخرین نسخه ایمنی',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _hideProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('بازیابی نسخه ایمنی ناموفق بود: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String> _readPickedFile(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }

    throw const FormatException('Unable to read the selected file.');
  }

  Future<RestoreMode?> _showRestoreModeDialog(BuildContext context) async {
    return showDialog<RestoreMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Colors.teal, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'انتخاب حالت بازیابی',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'برای بازیابی فایل انتخاب‌شده یکی از این دو حالت را انتخاب کنید.',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, RestoreMode.replace),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('جایگزینی کامل'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(dialogContext, RestoreMode.merge),
              icon: const Icon(Icons.merge_type_outlined),
              label: const Text('ادغام'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
                label: const Text('انصراف'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<BackupDeliveryAction?> _showBackupDeliveryDialog(
    BuildContext context,
  ) async {
    return showDialog<BackupDeliveryAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.backup_outlined, color: Colors.teal, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                ' پشتیبان گیری',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'می‌خواهید نسخه پشتیبان را برای اشتراک‌گذاری باز کنیم یا آن را در حافظه گوشی ذخیره کنیم؟',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, BackupDeliveryAction.share),
              icon: const Icon(Icons.share_outlined),
              label: const Text('اشتراک‌گذاری'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () =>
                  Navigator.pop(dialogContext, BackupDeliveryAction.save),
              icon: const Icon(Icons.save_outlined),
              label: const Text('ذخیره'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
                label: const Text('انصراف'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showRestoreConfirmDialog(
    BuildContext context, {
    required RestoreMode restoreMode,
    required String sourceLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'بازیابی نسخه پشتیبان',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'این کار ابتدا از داده‌های فعلی یک نسخه ایمنی می‌سازد و سپس داده‌های $sourceLabel را با داده‌های موجود اعمال می‌کند. ادامه می‌دهید؟',
          textAlign: TextAlign.justify,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogContext, false),
            icon: const Icon(Icons.close),
            label: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              restoreMode == RestoreMode.merge ? 'ادغام' : 'جایگزینی',
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _showRestoreSummaryDialog(
    BuildContext context,
    RestoreResult result, {
    required String sourceLabel,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'بازیابی با موفقیت انجام شد',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('منبع: $sourceLabel'),
            const SizedBox(height: 8),
            Text(
              'حالت: ${result.mode == RestoreMode.merge ? 'ادغام' : 'جایگزینی کامل'}',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 8),
            Text(
              'رویدادهای خوانده‌شده: ${result.eventsCount.toString().toPersianNumbers()}',
              textAlign: TextAlign.justify,
            ),
            Text(
              'مخاطبین خوانده‌شده: ${result.contactsCount.toString().toPersianNumbers()}',
              textAlign: TextAlign.justify,
            ),
            Text(
              'فایل‌های رسید بازسازی‌شده: ${result.receiptFilesCount.toString().toPersianNumbers()}',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 8),
            Text(
              result.safetyBackupCreated
                  ? 'از داده‌های قبلی یک نسخه ایمنی هم ساخته شد.'
                  : 'نسخه ایمنی از داده‌های قبلی ساخته نشد.',
              textAlign: TextAlign.justify,
            ),
            if (result.safetyBackupCreatedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'زمان نسخه ایمنی: ${DateFormat('yyyy/MM/dd HH:mm').format(result.safetyBackupCreatedAt!.toLocal()).toPersianNumbers()}',
                textAlign: TextAlign.justify,
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(
      context,
      listen: false,
    );
    final contactsProvider = Provider.of<ContactsProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'پاک کردن همه',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آیا از حذف کامل داده‌های برنامه مطمئن هستید؟',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'این عمل همه رویدادها، هزینه‌ها، مخاطبین و تنظیمات ذخیره‌شده را حذف می‌کند و قابل بازگشت نیست.',
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  label: const Text('انصراف'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      _showProgressDialog(context, 'در حال حذف داده‌ها...');
                      await AppBackupService.clearAppData(
                        expenseProvider: expenseProvider,
                        contactsProvider: contactsProvider,
                        settingsProvider: settingsProvider,
                      );
                      if (context.mounted) {
                        _hideProgressDialog(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تمام داده‌های برنامه حذف شد'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _hideProgressDialog(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('حذف داده‌ها ناموفق بود: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('حذف'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProgressDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  void _hideProgressDialog(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
