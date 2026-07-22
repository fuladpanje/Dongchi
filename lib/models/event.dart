import 'package:flutter/material.dart';

// لیست ثابت آیکون‌های برنامه (برای جلوگیری از خطای Tree Shaking)
const List<IconData> kAllAppIcons = [
  Icons.event,
  Icons.restaurant,
  Icons.flight,
  Icons.beach_access,
  Icons.forest,
  Icons.hiking,
  Icons.business,
  Icons.celebration,
  Icons.sports_soccer,
  Icons.local_cafe,
  Icons.shopping_bag,
  Icons.movie,
  Icons.music_note,
];

// کد آیکون پیش‌فرض (Icons.event) برای سازگاری با داده‌های قدیمی
const int kDefaultEventIconCodePoint = 0xe23a;

// تابع کمکی برای یافتن آیکون از codePoint
IconData getIconFromCodePoint(int? codePoint) {
  final safeCodePoint = codePoint ?? kDefaultEventIconCodePoint;
  return kAllAppIcons.firstWhere(
    (icon) => icon.codePoint == safeCodePoint,
    orElse: () => Icons.event,
  );
}

// مدل برنامه/رویداد
class Event {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? startDate; // تاریخ شروع برنامه
  final DateTime? endDate; // تاریخ پایان برنامه
  final Color? color; // رنگ برنامه
  final int? iconCodePoint; // برای داده‌های قدیمی ممکن است null باشد

  Event({
    required this.id,
    required this.name,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.color,
    this.iconCodePoint,
  });

  // Getter برای راحتی استفاده در UI
  IconData get icon => getIconFromCodePoint(iconCodePoint);

  // codePoint موثر برای پشتیبانی از داده‌های قدیمی
  int get effectiveIconCodePoint => iconCodePoint ?? kDefaultEventIconCodePoint;

  // تبدیل به Map برای ذخیره‌سازی
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'color': color?.value,
      'iconCodePoint': effectiveIconCodePoint,
    };
  }

  // ساخت از Map
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      color: json['color'] != null ? Color(json['color'] as int) : null,
      iconCodePoint:
          (json['iconCodePoint'] as int?) ?? kDefaultEventIconCodePoint,
    );
  }
}
