import 'package:flutter/services.dart';

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // فقط اعداد را نگه‌دار
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    // حداکثر 16 رقم
    if (digitsOnly.length > 16) {
      digitsOnly = digitsOnly.substring(0, 16);
    }

    // فرمت کردن به 4-4-4-4
    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }

    // محاسبه موقعیت cursor
    int cursorPosition = formatted.length;
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}
