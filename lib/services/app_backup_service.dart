import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../providers/contacts_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';

enum RestoreMode { merge, replace }

class RestoreResult {
  final RestoreMode mode;
  final bool sourceIsSafetyBackup;
  final int eventsCount;
  final int contactsCount;
  final int receiptFilesCount;
  final bool safetyBackupCreated;
  final DateTime? safetyBackupCreatedAt;

  const RestoreResult({
    required this.mode,
    required this.sourceIsSafetyBackup,
    required this.eventsCount,
    required this.contactsCount,
    required this.receiptFilesCount,
    required this.safetyBackupCreated,
    required this.safetyBackupCreatedAt,
  });
}

class AppBackupService {
  static const int backupSchemaVersion = 1;
  static const String appName = 'simple_farsi_app';

  static const String _eventsKey = 'events';
  static const String _settledDebtsKey = 'settledDebts';
  static const String _settlementDescriptionsKey = 'settlementDescriptions';
  static const String _settlementDatesKey = 'settlementDates';
  static const String _contactsKey = 'contacts';
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _currencyUnitKey = 'currencyUnit';
  static const String _restoreSafetyBackupKey =
      '__restore_safety_backup_json__';
  static const String _restoreSafetyBackupAtKey =
      '__restore_safety_backup_at__';

  static const List<String> _allDataKeys = <String>[
    _eventsKey,
    _settledDebtsKey,
    _settlementDescriptionsKey,
    _settlementDatesKey,
    _contactsKey,
    _isDarkModeKey,
    _currencyUnitKey,
  ];

  static Future<Map<String, dynamic>> buildBackupPayload({
    required bool includeReceiptFiles,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final events = _readJsonObject(prefs.getString(_eventsKey));
    final receiptAttachments = includeReceiptFiles
        ? await _collectReceiptAttachments(events)
        : <String, dynamic>{};

    return <String, dynamic>{
      'schemaVersion': backupSchemaVersion,
      'appName': appName,
      'createdAt': DateTime.now().toIso8601String(),
      'includeReceiptFiles': includeReceiptFiles,
      'data': <String, dynamic>{
        'events': events,
        'settledDebts': _readJsonObject(prefs.getString(_settledDebtsKey)),
        'settlementDescriptions': _readJsonObject(
          prefs.getString(_settlementDescriptionsKey),
        ),
        'settlementDates': _readJsonObject(prefs.getString(_settlementDatesKey)),
        'contacts': _readJsonArray(prefs.getString(_contactsKey)),
        'settings': <String, dynamic>{
          'isDarkMode': prefs.getBool(_isDarkModeKey) ?? false,
          'currencyUnit': prefs.getString(_currencyUnitKey) ?? 'toman',
        },
        if (includeReceiptFiles)
          'attachments': <String, dynamic>{
            'receipts': receiptAttachments,
          },
      },
    };
  }

  static String encodeBackupPayload(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Future<File> writeBackupFile(String backupJson) async {
    final directory = await _getStorageDirectory();
    if (directory == null) {
      throw UnsupportedError('File-based backups are not supported on this platform.');
    }
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}simple_farsi_backup_$timestamp.json',
    );
    return file.writeAsString(backupJson, flush: true);
  }

  static Future<File?> saveBackupJson({
    required String backupJson,
    required String fileName,
  }) async {
    try {
      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'محل ذخیره نسخه پشتیبان را انتخاب کنید',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );

      if (selectedPath == null || selectedPath.isEmpty) {
        return null;
      }

      final file = File(selectedPath);
      await file.writeAsString(backupJson, flush: true);
      return file;
    } catch (_) {
      // Fall back to the app storage location below.
    }

    return writeBackupFile(backupJson);
  }

  static Future<RestoreResult> restoreFromJson(
    String backupJson, {
    required ExpenseProvider expenseProvider,
    required ContactsProvider contactsProvider,
    required SettingsProvider settingsProvider,
    RestoreMode restoreMode = RestoreMode.merge,
    bool sourceIsSafetyBackup = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentSafetyBackup = await _saveSafetyBackup(prefs);
    final safetyBackupCreatedAt = _parseSafetyBackupCreatedAt(prefs);

    try {
      final result = await _applyBackupJson(
        backupJson,
        prefs: prefs,
        mergeWithCurrent: restoreMode == RestoreMode.merge,
        expenseProvider: expenseProvider,
        contactsProvider: contactsProvider,
        settingsProvider: settingsProvider,
        sourceIsSafetyBackup: sourceIsSafetyBackup,
        safetyBackupCreatedAt: safetyBackupCreatedAt,
        safetyBackupCreated: currentSafetyBackup != null,
      );
      return result;
    } catch (error) {
      if (currentSafetyBackup != null) {
        try {
          await _applyBackupJson(
            currentSafetyBackup,
            prefs: prefs,
            mergeWithCurrent: false,
            expenseProvider: expenseProvider,
            contactsProvider: contactsProvider,
            settingsProvider: settingsProvider,
            sourceIsSafetyBackup: true,
            safetyBackupCreatedAt: _parseSafetyBackupCreatedAt(prefs),
            safetyBackupCreated: true,
          );
        } catch (_) {
          // If rollback fails, preserve the original error below.
        }
      }
      rethrow;
    }
  }

  static Future<RestoreResult> restoreSafetyBackup({
    required ExpenseProvider expenseProvider,
    required ContactsProvider contactsProvider,
    required SettingsProvider settingsProvider,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final safetyBackupJson = prefs.getString(_restoreSafetyBackupKey);
    if (safetyBackupJson == null || safetyBackupJson.isEmpty) {
      throw StateError('No safety backup is available.');
    }

    return restoreFromJson(
      safetyBackupJson,
      expenseProvider: expenseProvider,
      contactsProvider: contactsProvider,
      settingsProvider: settingsProvider,
      restoreMode: RestoreMode.replace,
      sourceIsSafetyBackup: true,
    );
  }

  static Future<bool> hasSafetyBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_restoreSafetyBackupKey) &&
        (prefs.getString(_restoreSafetyBackupKey)?.isNotEmpty ?? false);
  }

  static Future<DateTime?> getSafetyBackupCreatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseSafetyBackupCreatedAt(prefs);
  }

  static Future<void> clearAppData({
    required ExpenseProvider expenseProvider,
    required ContactsProvider contactsProvider,
    required SettingsProvider settingsProvider,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _allDataKeys) {
      await prefs.remove(key);
    }

    final documentsDirectory = await _getStorageDirectory();
    if (documentsDirectory != null) {
      final receiptsDirectory = Directory(
        '${documentsDirectory.path}${Platform.pathSeparator}receipts',
      );
      if (await receiptsDirectory.exists()) {
        await receiptsDirectory.delete(recursive: true);
      }
    }

    await Future.wait([
      expenseProvider.loadData(),
      contactsProvider.reload(),
      settingsProvider.reload(),
    ]);
  }

  static Map<String, dynamic> _extractDataMap(Map<String, dynamic> root) {
    final version = root['schemaVersion'];
    if (version != null && version is! num) {
      throw const FormatException('Backup version is invalid.');
    }

    if (version != null && version is num && version.toInt() > backupSchemaVersion) {
      throw const FormatException('Backup version is not supported.');
    }

    final data = root['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (root.containsKey(_eventsKey) ||
        root.containsKey(_contactsKey) ||
        root.containsKey(_isDarkModeKey)) {
      return root;
    }

    throw const FormatException('Backup data is missing.');
  }

  static Map<String, dynamic> _coerceObjectMap(dynamic value) {
    if (value == null) {
      return <String, dynamic>{};
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('Expected a JSON object in backup file.');
  }

  static List<dynamic> _coerceArray(dynamic value) {
    if (value == null) {
      return <dynamic>[];
    }
    if (value is List<dynamic>) {
      return value;
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    throw const FormatException('Expected a JSON array in backup file.');
  }

  static Future<String?> _saveSafetyBackup(SharedPreferences prefs) async {
    try {
      final safetyPayload = await buildBackupPayload(includeReceiptFiles: true);
      final safetyJson = encodeBackupPayload(safetyPayload);
      await prefs.setString(_restoreSafetyBackupKey, safetyJson);
      await prefs.setString(
        _restoreSafetyBackupAtKey,
        DateTime.now().toIso8601String(),
      );
      return safetyJson;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseSafetyBackupCreatedAt(SharedPreferences prefs) {
    final rawValue = prefs.getString(_restoreSafetyBackupAtKey);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawValue);
  }

  static Future<RestoreResult> _applyBackupJson(
    String backupJson, {
    required SharedPreferences prefs,
    required bool mergeWithCurrent,
    required ExpenseProvider expenseProvider,
    required ContactsProvider contactsProvider,
    required SettingsProvider settingsProvider,
    required bool sourceIsSafetyBackup,
    required DateTime? safetyBackupCreatedAt,
    required bool safetyBackupCreated,
  }) async {
    final decoded = jsonDecode(backupJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup file is invalid.');
    }

    final data = _extractDataMap(decoded);
    final importedData = _normalizeDataMap(data);
    final receiptAttachments = _extractReceiptAttachments(decoded);
    final sourceData = mergeWithCurrent
        ? _mergeDataMaps(_currentDataFromPrefs(prefs), importedData)
        : importedData;

    await _restoreReceiptAttachments(
      sourceData['events'] as Map<String, dynamic>,
      receiptAttachments,
    );

    await _writeDataToPrefs(prefs, sourceData);

    await Future.wait([
      expenseProvider.loadData(),
      contactsProvider.reload(),
      settingsProvider.reload(),
    ]);

    return RestoreResult(
      mode: mergeWithCurrent ? RestoreMode.merge : RestoreMode.replace,
      sourceIsSafetyBackup: sourceIsSafetyBackup,
      eventsCount: _coerceObjectMap(importedData['events']).length,
      contactsCount: _coerceArray(importedData['contacts']).length,
      receiptFilesCount: receiptAttachments.length,
      safetyBackupCreated: safetyBackupCreated,
      safetyBackupCreatedAt: safetyBackupCreatedAt,
    );
  }

  static Map<String, dynamic> _currentDataFromPrefs(SharedPreferences prefs) {
    return <String, dynamic>{
      'events': _readJsonObject(prefs.getString(_eventsKey)),
      'settledDebts': _readJsonObject(prefs.getString(_settledDebtsKey)),
      'settlementDescriptions': _readJsonObject(
        prefs.getString(_settlementDescriptionsKey),
      ),
      'settlementDates': _readJsonObject(prefs.getString(_settlementDatesKey)),
      'contacts': _readJsonArray(prefs.getString(_contactsKey)),
      'settings': <String, dynamic>{
        'isDarkMode': prefs.getBool(_isDarkModeKey) ?? false,
        'currencyUnit': prefs.getString(_currencyUnitKey) ?? 'toman',
      },
    };
  }

  static Map<String, dynamic> _normalizeDataMap(Map<String, dynamic> data) {
    return <String, dynamic>{
      'events': _coerceObjectMap(data['events']),
      'settledDebts': _coerceObjectMap(data['settledDebts']),
      'settlementDescriptions': _coerceObjectMap(
        data['settlementDescriptions'],
      ),
      'settlementDates': _coerceObjectMap(data['settlementDates']),
      'contacts': _coerceArray(data['contacts']),
      'settings': data['settings'] is Map
          ? Map<String, dynamic>.from(data['settings'] as Map)
          : <String, dynamic>{},
    };
  }

  static Map<String, dynamic> _mergeDataMaps(
    Map<String, dynamic> currentData,
    Map<String, dynamic> importedData,
  ) {
    return <String, dynamic>{
      'events': _mergeEventsMap(
        _coerceObjectMap(currentData['events']),
        _coerceObjectMap(importedData['events']),
      ),
      'settledDebts': _mergeStringObjectMaps(
        _coerceObjectMap(currentData['settledDebts']),
        _coerceObjectMap(importedData['settledDebts']),
      ),
      'settlementDescriptions': _mergeStringObjectMaps(
        _coerceObjectMap(currentData['settlementDescriptions']),
        _coerceObjectMap(importedData['settlementDescriptions']),
      ),
      'settlementDates': _mergeStringObjectMaps(
        _coerceObjectMap(currentData['settlementDates']),
        _coerceObjectMap(importedData['settlementDates']),
      ),
      'contacts': _mergeJsonListsById(
        _coerceArray(currentData['contacts']),
        _coerceArray(importedData['contacts']),
      ),
      'settings': <String, dynamic>{
        ..._coerceSettingsMap(currentData['settings']),
        ..._coerceSettingsMap(importedData['settings']),
      },
    };
  }

  static Map<String, dynamic> _coerceSettingsMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _mergeStringObjectMaps(
    Map<String, dynamic> current,
    Map<String, dynamic> imported,
  ) {
    final merged = <String, dynamic>{...current};
    merged.addAll(imported);
    return merged;
  }

  static Map<String, dynamic> _mergeEventsMap(
    Map<String, dynamic> current,
    Map<String, dynamic> imported,
  ) {
    final merged = <String, dynamic>{...current};
    for (final entry in imported.entries) {
      final currentValue = merged[entry.key];
      if (currentValue is Map && entry.value is Map) {
        merged[entry.key] = _mergeEventDataMaps(
          Map<String, dynamic>.from(currentValue),
          Map<String, dynamic>.from(entry.value as Map),
        );
      } else {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  static Map<String, dynamic> _mergeEventDataMaps(
    Map<String, dynamic> current,
    Map<String, dynamic> imported,
  ) {
    return <String, dynamic>{
      'event': _coerceJsonMap(imported['event']) ?? _coerceJsonMap(current['event']) ?? <String, dynamic>{},
      'participants': _mergeJsonListsById(
        _coerceArray(current['participants']),
        _coerceArray(imported['participants']),
      ),
      'expenses': _mergeJsonListsById(
        _coerceArray(current['expenses']),
        _coerceArray(imported['expenses']),
      ),
    };
  }

  static Map<String, dynamic>? _coerceJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static List<dynamic> _mergeJsonListsById(
    List<dynamic> current,
    List<dynamic> imported,
  ) {
    final merged = <Map<String, dynamic>>[];
    final indexById = <String, int>{};

    void addItem(dynamic item) {
      final map = _coerceJsonMap(item);
      if (map == null) {
        return;
      }
      final id = map['id']?.toString();
      if (id == null || id.isEmpty) {
        merged.add(map);
        return;
      }

      final existingIndex = indexById[id];
      if (existingIndex != null) {
        merged[existingIndex] = map;
      } else {
        indexById[id] = merged.length;
        merged.add(map);
      }
    }

    for (final item in current) {
      addItem(item);
    }
    for (final item in imported) {
      addItem(item);
    }

    return merged;
  }

  static Map<String, dynamic> _extractReceiptAttachments(
    Map<String, dynamic> root,
  ) {
    final data = root['data'];
    if (data is! Map) {
      return <String, dynamic>{};
    }

    final attachments = data['attachments'];
    if (attachments is! Map) {
      return <String, dynamic>{};
    }

    final receipts = attachments['receipts'];
    if (receipts is Map<String, dynamic>) {
      return receipts;
    }
    if (receipts is Map) {
      return Map<String, dynamic>.from(receipts);
    }
    return <String, dynamic>{};
  }

  static Future<void> _writeDataToPrefs(
    SharedPreferences prefs,
    Map<String, dynamic> data,
  ) async {
    await prefs.setString(_eventsKey, jsonEncode(data['events']));
    await prefs.setString(_settledDebtsKey, jsonEncode(data['settledDebts']));
    await prefs.setString(
      _settlementDescriptionsKey,
      jsonEncode(data['settlementDescriptions']),
    );
    await prefs.setString(
      _settlementDatesKey,
      jsonEncode(data['settlementDates']),
    );
    await prefs.setString(_contactsKey, jsonEncode(data['contacts']));

    final settings = _coerceSettingsMap(data['settings']);
    await prefs.setBool(_isDarkModeKey, settings['isDarkMode'] as bool? ?? false);
    await prefs.setString(
      _currencyUnitKey,
      _normalizeCurrencyUnit(settings['currencyUnit'] as String?),
    );
  }

  static Future<Map<String, dynamic>> _collectReceiptAttachments(
    Map<String, dynamic> events,
  ) async {
    final attachments = <String, dynamic>{};

    for (final eventEntry in events.entries) {
      final eventData = eventEntry.value;
      if (eventData is! Map) {
        continue;
      }

      final expenses = eventData['expenses'];
      if (expenses is! List) {
        continue;
      }

      for (final expense in expenses) {
        if (expense is! Map) {
          continue;
        }

        final receiptPath = expense['receiptPath'] as String?;
        if (receiptPath == null || receiptPath.isEmpty) {
          continue;
        }

        if (attachments.containsKey(receiptPath)) {
          continue;
        }

        try {
          final file = File(receiptPath);
          if (!await file.exists()) {
            continue;
          }

          final bytes = await file.readAsBytes();
          attachments[receiptPath] = <String, dynamic>{
            'fileName': _safeReceiptFileName(receiptPath),
            'mimeType': _guessMimeType(receiptPath),
            'base64': base64Encode(bytes),
          };
        } on UnsupportedError {
          continue;
        } on FileSystemException {
          continue;
        }
      }
    }

    return attachments;
  }

  static Future<void> _restoreReceiptAttachments(
    Map<String, dynamic> events,
    Map<String, dynamic> receiptAttachments,
  ) async {
    if (receiptAttachments.isEmpty) {
      return;
    }

    final documentsDirectory = await _getStorageDirectory();
    if (documentsDirectory == null) {
      return;
    }
    final receiptsDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}receipts',
    );
    if (!await receiptsDirectory.exists()) {
      await receiptsDirectory.create(recursive: true);
    }

    for (final eventEntry in events.entries) {
      final eventData = eventEntry.value;
      if (eventData is! Map) {
        continue;
      }

      final expenses = eventData['expenses'];
      if (expenses is! List) {
        continue;
      }

      for (final expense in expenses) {
        if (expense is! Map) {
          continue;
        }

        final receiptPath = expense['receiptPath'] as String?;
        if (receiptPath == null || receiptPath.isEmpty) {
          continue;
        }

        final attachment = receiptAttachments[receiptPath];
        if (attachment is! Map) {
          continue;
        }

        final encodedBytes = attachment['base64'] as String?;
        if (encodedBytes == null || encodedBytes.isEmpty) {
          continue;
        }

        final fileName = _sanitizeFileName(
          attachment['fileName'] as String? ?? _safeReceiptFileName(receiptPath),
        );
        final outputPath = _nextAvailableFilePath(receiptsDirectory, fileName);
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(base64Decode(encodedBytes), flush: true);
        expense['receiptPath'] = outputFile.path;
      }
    }
  }

  static String _safeReceiptFileName(String receiptPath) {
    final pathSeparator = Platform.pathSeparator;
    final originalName = receiptPath.split(pathSeparator).last;
    return _sanitizeFileName(originalName);
  }

  static String _sanitizeFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return sanitized.isEmpty ? 'receipt.png' : sanitized;
  }

  static String _nextAvailableFilePath(Directory directory, String fileName) {
    final baseName = fileName;
    final dotIndex = baseName.lastIndexOf('.');
    final stem = dotIndex > 0 ? baseName.substring(0, dotIndex) : baseName;
    final extension = dotIndex > 0 ? baseName.substring(dotIndex) : '';

    var candidate = File(
      '${directory.path}${Platform.pathSeparator}$baseName',
    );
    var suffix = 1;
    while (candidate.existsSync()) {
      candidate = File(
        '${directory.path}${Platform.pathSeparator}${stem}_$suffix$extension',
      );
      suffix++;
    }
    return candidate.path;
  }

  static String _guessMimeType(String receiptPath) {
    final extension = receiptPath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  static Map<String, dynamic> _readJsonObject(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Stored data is invalid.');
  }

  static List<dynamic> _readJsonArray(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return <dynamic>[];
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    if (decoded is List) {
      return List<dynamic>.from(decoded);
    }
    throw const FormatException('Stored data is invalid.');
  }

  static String _normalizeCurrencyUnit(String? value) {
    if (value == 'rial' || value == 'toman') {
      return value!;
    }
    return 'toman';
  }

  static Future<Directory?> _getStorageDirectory() async {
    if (kIsWeb) {
      return null;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      await directory.create(recursive: true);
      return directory;
    } on MissingPluginException catch (_) {
      return _fallbackStorageDirectory();
    } on PlatformException catch (_) {
      return _fallbackStorageDirectory();
    } on UnsupportedError catch (_) {
      return _fallbackStorageDirectory();
    }
  }

  static Directory _fallbackStorageDirectory() {
    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$appName',
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}
