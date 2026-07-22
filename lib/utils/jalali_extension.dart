import 'package:shamsi_date/shamsi_date.dart';

extension JalaliFormatterExtension on Jalali {
  String formatPersianFullDate() {
    const weekDays = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه'];
    const months = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 
                    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
    
    final dayOfWeek = weekDays[weekDay - 1];
    final monthName = months[month - 1];
    
    return '$dayOfWeek $day $monthName $year'
        .toPersianNumbers();
  }

  String formatJalaliCompact() {
    const months = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 
                    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
    
    final monthName = months[month - 1];
    return '$day $monthName $year'.toPersianNumbers();
  }
}

extension PersianNumberExtension on String {
  String toPersianNumbers() {
    return replaceAll('0', '۰')
        .replaceAll('1', '۱')
        .replaceAll('2', '۲')
        .replaceAll('3', '۳')
        .replaceAll('4', '۴')
        .replaceAll('5', '۵')
        .replaceAll('6', '۶')
        .replaceAll('7', '۷')
        .replaceAll('8', '۸')
        .replaceAll('9', '۹');
  }
}
