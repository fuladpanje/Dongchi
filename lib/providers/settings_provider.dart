import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _currencyUnit = 'toman'; // 'toman' or 'rial'
  bool _hideAmounts = false;

  ThemeMode get themeMode => _themeMode;
  String get currencyUnit => _currencyUnit;
  bool get hideAmounts => _hideAmounts;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isRial => _currencyUnit == 'rial';

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    _currencyUnit = prefs.getString('currencyUnit') ?? 'toman';
    _hideAmounts = prefs.getBool('hideAmounts') ?? false;
    notifyListeners();
  }

  Future<void> reload() async {
    await _loadSettings();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  Future<void> setCurrency(String unit) async {
    if (unit != 'toman' && unit != 'rial') return;
    _currencyUnit = unit;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencyUnit', unit);
  }

  Future<void> setHideAmounts(bool hide) async {
    _hideAmounts = hide;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideAmounts', hide);
  }

  // Helper to format amount based on selected currency
  String formatAmount(double amount, {bool withUnit = true}) {
    double displayAmount = amount;
    String unitLabel = 'تومان';

    if (isRial) {
      displayAmount = amount * 10;
      unitLabel = 'ریال';
    }

    // Manual thousands separator
    String formatted = displayAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // Convert to Persian numbers (mock implementation if extension not available here)
    // Assuming calling code handles .toPersianNumbers() or we add it here if imported.
    // For now returning standard string, caller usually does .toPersianNumbers()
    
    return withUnit ? '$formatted $unitLabel' : formatted;
  }
}
