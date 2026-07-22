<div dir="rtl">

# دنگ چی | Dongchi

**اپلیکیشن مدیریت هزینه‌های گروهی**

---

</div>

<div align="center">

![Dongchi Logo](assets/icon.png)

**Dongchi** — A cross-platform Flutter app for splitting expenses and settling debts in groups

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?style=for-the-badge&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.1.0-orange?style=for-the-badge)](https://github.com/fuladpanje/Dongchi/releases)

</div>

---

<div dir="rtl">

## درباره دنگ چی

**دنگ چی** یک اپلیکیشن کراس‌پلتفرم با فریمورک Flutter برای مدیریت هزینه‌های گروهی و تسویه بدهی‌هاست. با این اپلیکیشن می‌توانید رویدادهای مختلف (سفر، مهمانی، دورهمی و ...) بسازید، هزینه‌ها را ثبت کنید و در نهایت ببینید چه کسی به چه کسی بدهکار است.

</div>

<div dir="rtl">

## دانلود و نصب

</div>

<div align="center">

| پلتفرم | لینک دانلود |
|---------|-------------|
| **اندروید (APK)** | [دانلود مستقیم](https://dl.dongchiapp.ir/) |
| **بازار** | [CafeBazaar](https://cafebazaar.ir/app/com.takbaran.dangchi) |
| **مایکت** | [Myket](https://myket.ir/app/com.takbaran.dangchi) |
| **وب (PWA)** | [dongchiapp.ir](https://dongchiapp.ir) |
| **ویندوز** | [GitHub Releases](https://github.com/fuladpanje/Dongchi/releases) |

</div>

---

<div dir="rtl">

## امکانات اصلی

</div>

### 🔹 مدیریت رویدادها
- ایجاد رویدادهای مختلف (سفر، مهمانی، رستوران، ورزش و ...)
- نمادهای از پیش تعریف شده و امکان انتخاب رنگ دلخواه
- جستجو و فیلتر رویدادها بر اساس نام، شرکت‌کننده و تاریخ شمسی

### 🔹 ثبت هزینه‌ها با تقسیم انعطاف‌پذیر
- **تقسیم مساوی** — بین تمام شرکت‌کنندگان
- **درصدی** — تعیین درصد هر نفر
- **سهمی** — تقسیم بر اساس نسبت
- **مبلغی** — تعیین مبلغ مشخص برای هر نفر
- امکان افزودن عکس رسید به هزینه

### 🔹 مدیریت شرکت‌کنندگان
- افزودن شرکت‌کننده با نام و شماره کارت بانکی (اختیاری)
- حذف گروهی شرکت‌کنندگان
- آمار تراکنش‌ها و مبلغ پرداختی هر نفر

### 🔹 الگوریتم تسویه هوشمند
- محاسبه خودکار بدهی‌ها با کمترین تعداد تراکنش
- نمایش وضعیت تسویه (پرداخت شده / در انتظار)
- نمایش شماره کارت بانکی برای انتقال آسان
- کپی شماره کارت با یک لمس

### 🔹 نمودارها و تحلیل‌ها
- نمودار دایره‌ای (سهم پرداخت هر نفر)
- نمودار میله‌ای (مانده حساب)
- نمایش وضعیت تسویه
- امکان اشتراک‌گذاری نمودارها به صورت تصویر

### 🔹 گزارش و PDF
- تولید گزارش PDF از تسویه‌ها
- چاپ و اشتراک‌گذاری اسناد PDF
- اشتراک‌گذاری متنی گزارش‌ها

### 🔹 سیستم مخاطبین
- دفترچه مخاطبین سراسری (جدا از شرکت‌کنندگان رویداد)
- ذخیره نام و شماره کارت بانکی
- جستجو بر اساس نام یا شماره کارت

### 🔹 پشتیبان‌گیری و بازیابی
- پشتیبان‌گیری کامل JSON با نسخه‌بندی
- دو حالت بازیابی: **ادغام** یا **جایگزینی**
- پشتیبان‌گیری خودکار ایمن قبل از بازیابی
- امکان اشتراک‌گذاری فایل پشتیبان

### 🔹 تنظیمات
- حالت تاریک / روشن
- واحد پرز: تومان یا ریال (تبدیل خودکار)
- حالت پنهان کردن مبالغ (حریم خصوصی)
- پاک کردن تمام داده‌ها

### 🔹 پشتیبانی کامل فارسی
- پشتیبانی RTL (راست به چپ)
- تقویم شمسی در تمام بخش‌ها
- تبدیل خودکار اعداد به فارسی (۰-۹)
- فونت وزیرمتن

---

<div dir="rtl">

## ساختار پروژه

</div>

```
lib/
├── main.dart                    # نقطه ورود برنامه
├── models/
│   ├── event.dart               # مدل رویداد
│   ├── expense.dart             # مدل هزینه
│   └── participant.dart         # مدل شرکت‌کننده
├── providers/
│   ├── expense_provider.dart    # منطق اصلی کسب‌وکار
│   ├── settings_provider.dart   # تنظیمات تم و پول
│   └── contacts_provider.dart   # مخاطبین سراسری
├── screens/
│   ├── events_list_screen.dart  # صفحه اصلی: لیست رویدادها
│   ├── event_detail_screen.dart # جزئیات رویداد
│   ├── add_event_screen.dart    # ایجاد رویداد جدید
│   ├── add_expense_screen.dart  # افزودن هزینه
│   ├── result_screen.dart       # نتایج تسویه
│   ├── charts_screen.dart       # نمودارها
│   ├── contacts_screen.dart     # مخاطبین
│   ├── settings_screen.dart     # تنظیمات
│   └── about_screen.dart        # درباره ما
├── services/
│   └── app_backup_service.dart  # سیستم پشتیبان‌گیری
├── utils/
│   ├── jalali_extension.dart    # ابزار تاریخ شمسی
│   └── card_input_formatter.dart # فرمت‌دهی شماره کارت
└── widgets/
    └── persian_date_picker.dart # تقویم شمسی
```

---

<div dir="rtl">

## تکنولوژی‌ها

</div>

| دسته | کتابخانه | نسخه | کاربرد |
|------|---------|------|--------|
| فریمورک | Flutter | ^3.10.3 | رابط کاربری کراس‌پلتفرم |
| مدیریت State | provider | ^6.1.0 | مدیریت وضعیت |
| ذخیره‌سازی | shared_preferences | ^2.2.0 | ذخیره‌سازی محلی |
| فونت فارسی | google_fonts | ^6.1.0 | فونت وزیرمتن |
| تقویم شمسی | persian_datetime_picker | ^3.1.1 | انتخابگر تاریخ |
| PDF | pdf + printing | ^3.10.0 | تولید و چاپ PDF |
| نمودار | fl_chart | ^1.2.0 | نمودارهای دایره‌ای و میله‌ای |
| اشتراک‌گذاری | share_plus | ^10.0.0 | اشتراک‌گذاری گزارش |

---

<div dir="rtl">

## نحوه اجرا

</div>

```bash
# کلون کردن پروژه
git clone https://github.com/fuladpanje/Dongchi.git

# رفتن به پوشه پروژه
cd Dongchi

# نصب وابستگی‌ها
flutter pub get

# اجرا روی اندروید
flutter run

# اجرا روی ویندوز
flutter run -d windows

# اجرا روی وب
flutter run -d chrome

# بیلد APK
flutter build apk --release

# بیلد ویندوز
flutter build windows --release
```

---

<div dir="rtl">

## توسعه‌دهنده

</div>

**رضا فولادپانجه** — [fuladpanjeh.ir](https://fuladpanjeh.ir)

---

<div dir="rtl">

## مجوز

</div>

این پروژه تحت مجوز MIT منتشر شده است. See [LICENSE](LICENSE) for details.
