import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import '../models/participant.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/jalali_extension.dart';
import '../widgets/persian_date_picker.dart';
import 'package:simple_farsi_app/screens/charts_screen.dart';

class ResultScreen extends StatefulWidget {
  final String eventId;

  const ResultScreen({super.key, required this.eventId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Set<String> _selectedDebtorIds = {};
  // 0: همه (پیش‌فرض), 1: تسویه نشده, 2: تسویه شده
  int _settlementFilterMode = 0;

  String _formatCardNumberRaw(String cardNumber) {
    try {
      final digits = cardNumber
          .replaceAll('۰', '0')
          .replaceAll('۱', '1')
          .replaceAll('۲', '2')
          .replaceAll('۳', '3')
          .replaceAll('۴', '4')
          .replaceAll('۵', '5')
          .replaceAll('۶', '6')
          .replaceAll('۷', '7')
          .replaceAll('۸', '8')
          .replaceAll('۹', '9')
          .replaceAll(RegExp(r'\D'), '');
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length; i++) {
        if (i > 0 && i % 4 == 0) {
          buffer.write('-');
        }
        buffer.write(digits[i]);
      }
      return buffer.toString().toPersianNumbers();
    } catch (e) {
      return cardNumber;
    }
  }

  String _formatSettlementDate(DateTime dateTime) {
    final datePart =
        '${Jalali.fromDateTime(dateTime).formatJalaliCompact().toPersianNumbers()}';
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'
            .toPersianNumbers();
    if (timeStr == '۰۰:۰۰') {
      return datePart;
    }
    return '$datePart ساعت $timeStr';
  }

  void _showSettlementDetailPopup(
    BuildContext context,
    Color color,
    String title,
    List debts,
    SettingsProvider settings,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.5,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text(
                    '${debts.length} مورد'.toPersianNumbers(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.account_balance_wallet_outlined, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text(
                    settings.formatAmount(debts.fold<double>(0, (sum, d) => sum + d.amount)).toPersianNumbers(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: debts.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                  ),
                  itemBuilder: (_, i) {
                    final d = debts[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            d.isSettled
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 18,
                            color: d.isSettled ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        d.debtorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey[200]
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ' ← ',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[500],
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        d.creditorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey[200]
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (d.settlementDate != null)
                                  Text(
                                    _formatSettlementDate(d.settlementDate!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[400],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            settings
                                .formatAmount(d.amount)
                                .toPersianNumbers(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSettlementDialog(
    BuildContext context,
    ExpenseProvider provider,
    SettingsProvider settings,
    dynamic debt, {
    bool isEditing = false,
  }) {
    final eventData = provider.getEventData(widget.eventId);
    final Color eventColor = eventData?.event.color ?? Colors.teal;

    final controller = TextEditingController(
      text: isEditing ? debt.settlementDescription : '',
    );
    Jalali? selectedSettlementDate;
    TimeOfDay? selectedSettlementTime;
    final creditorCardNumber = debt.creditorCardNumber as String?;
    final hasCreditorCardNumber =
        creditorCardNumber != null && creditorCardNumber.isNotEmpty;

    if (isEditing && debt.settlementDate != null) {
      selectedSettlementDate = Jalali.fromDateTime(debt.settlementDate!);
      selectedSettlementTime = TimeOfDay.fromDateTime(debt.settlementDate!);
    }
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(isEditing ? 'ویرایش تسویه' : 'تایید تسویه حساب'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                if (!isEditing)
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 14),
                      children: [
                        const TextSpan(text: 'آیا از تسویه مبلغ '),
                        TextSpan(
                          text:
                              '${settings.formatAmount(debt.amount).toPersianNumbers()} ',
                        ),
                        const TextSpan(text: 'بین '),
                        TextSpan(
                          text: '${debt.debtorName} ',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const TextSpan(text: 'و '),
                        TextSpan(
                          text: debt.creditorName,
                          style: const TextStyle(color: Colors.green),
                        ),
                        const TextSpan(text: ' اطمینان دارید؟'),
                      ],
                    ),
                  ),
                if (!isEditing) const SizedBox(height: 16),
                if (hasCreditorCardNumber) ...[
                  Builder(
                    builder: (context) {
                      final cardNumber = creditorCardNumber!;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.credit_card,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${debt.creditorName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatCardNumberRaw(cardNumber),
                                    textDirection: ui.TextDirection.ltr,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'کپی شماره کارت',
                              icon: const Icon(Icons.copy, size: 18),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: cardNumber),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('شماره کارت کپی شد'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controller,
                  maxLength: 50,
                  autofocus: isEditing,
                  maxLines: 3,
                  minLines: 2,
                  decoration: InputDecoration(
                    labelText: 'توضیحات (اختیاری)',
                    hintText:
                        'مثال: پرداخت نقدی، کارت به کارت، بابت ناهار روز جمعه...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                ),
                const SizedBox(height: 16),
                // بخش انتخاب تاریخ و ساعت
                Column(
                  children: [
                    // ردیف تاریخ
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              onTap: () async {
                                FocusScope.of(context).unfocus();
                                final picked = await showCustomPersianDatePicker(
                                  context: context,
                                  initialDate: selectedSettlementDate,
                                  firstDate: Jalali(1400),
                                  lastDate: Jalali(1410),
                                );
                                FocusScope.of(context).unfocus();
                                if (picked != null) {
                                  setDialogState(() {
                                    selectedSettlementDate = picked;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        selectedSettlementDate != null
                                            ? selectedSettlementDate!
                                                  .formatJalaliCompact()
                                                  .toPersianNumbers()
                                            : 'تاریخ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: selectedSettlementDate != null
                                              ? (Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black)
                                              : Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (selectedSettlementDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setDialogState(() {
                                selectedSettlementDate = null;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ردیف ساعت
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              onTap: () async {
                                FocusScope.of(context).unfocus();
                                final initialTime =
                                    selectedSettlementTime ?? TimeOfDay.now();
                                setDialogState(() {
                                  selectedSettlementTime = initialTime;
                                });
                                await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    content: SizedBox(
                                      height: 250,
                                      child: CupertinoDatePicker(
                                        mode: CupertinoDatePickerMode.time,
                                        initialDateTime: DateTime(
                                          2024,
                                          1,
                                          1,
                                          initialTime.hour,
                                          initialTime.minute,
                                        ),
                                        use24hFormat: true,
                                        onDateTimeChanged: (dateTime) {
                                          setDialogState(() {
                                            selectedSettlementTime = TimeOfDay(
                                              hour: dateTime.hour,
                                              minute: dateTime.minute,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('انصراف'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('تایید'),
                                      ),
                                    ],
                                  ),
                                );
                                FocusScope.of(context).unfocus();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      selectedSettlementTime != null
                                          ? '${selectedSettlementTime!.hour.toString().padLeft(2, '0')}:${selectedSettlementTime!.minute.toString().padLeft(2, '0')}'
                                                .toPersianNumbers()
                                          : 'ساعت',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: selectedSettlementTime != null
                                            ? (Theme.of(context).brightness ==
                                                      Brightness.dark
                                                ? Colors.white
                                                : Colors.black)
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    const Icon(Icons.access_time, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (selectedSettlementTime != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setDialogState(() {
                                selectedSettlementTime = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (isEditing)
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            // تایید نهایی برای لغو تسویه
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('لغو تسویه'),
                                content: const Text(
                                  'آیا از حذف اطلاعات تسویه و لغو وضعیت آن اطمینان دارید؟',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('خیر'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('بله، حذف کن'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await provider.updateDebtSettlement(
                                widget.eventId,
                                debt.debtorId,
                                debt.creditorId,
                                debt.debtorName,
                                debt.creditorName,
                                false,
                              );
                              if (context.mounted) {
                                Navigator.pop(context); // بستن دیالوگ اصلی
                              }
                            }
                          },
                          child: const Text('حذف تسویه'),
                        ),
                      ),
                    if (isEditing) const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          DateTime? finalDateTime;
                          if (selectedSettlementDate != null) {
                            final time =
                                selectedSettlementTime ?? TimeOfDay.now();
                            finalDateTime = selectedSettlementDate!
                                .toDateTime()
                                .copyWith(
                                  hour: time.hour,
                                  minute: time.minute,
                                );
                          }

                          await provider.updateDebtSettlement(
                            widget.eventId,
                            debt.debtorId,
                            debt.creditorId,
                            debt.debtorName,
                            debt.creditorName,
                            true,
                            description: controller.text.trim(),
                            settlementDate: finalDateTime,
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(isEditing ? 'ذخیره' : 'تایید و تسویه'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('بستن'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfSectionTitle(
    String title,
    pw.Font titleFont,
    PdfColor color,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Center(
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: color,
                font: titleFont,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildSettlementPdfDetailsSection({
    required dynamic debt,
    required pw.Font titleFont,
    required pw.Font bodyFont,
    required pw.Font boldFont,
    required PdfColor headerPdfColor,
  }) {
    final settlementStatus = debt.isSettled ? 'تسویه شده' : 'در انتظار تسویه';
    final settlementStatusColor = debt.isSettled
        ? PdfColors.green700
        : PdfColors.red700;
    final settlementDateText = debt.settlementDate != null
        ? _formatSettlementDate(debt.settlementDate!)
        : '-';
    final cardText =
        debt.creditorCardNumber != null && debt.creditorCardNumber!.isNotEmpty
        ? _formatCardNumberRaw(debt.creditorCardNumber!)
        : '-';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _buildPdfSectionTitle('اطلاعات تسویه', titleFont, headerPdfColor),
        _buildTopRoundedPdfTable(
          child: pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
            },
            border: pw.TableBorder(
              top: const pw.BorderSide(color: PdfColors.grey300, width: 1),
              bottom: const pw.BorderSide(color: PdfColors.grey300, width: 1),
              left: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              right: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              verticalInside: const pw.BorderSide(
                color: PdfColors.grey200,
                width: 0.5,
              ),
              horizontalInside: const pw.BorderSide(
                color: PdfColors.grey200,
                width: 0.5,
              ),
            ),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerPdfColor),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    child: pw.Text(
                      'مقدار',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: boldFont,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    child: pw.Text(
                      'مشخصه',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: boldFont,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
              _buildSettlementPdfTableRow(
                'نام بدهکار',
                debt.debtorName,
                bodyFont,
              ),
              _buildSettlementPdfTableRow(
                'نام طلبکار',
                debt.creditorName,
                bodyFont,
              ),
              _buildSettlementPdfTableRow(
                'وضعیت تسویه',
                settlementStatus,
                bodyFont,
                valueColor: settlementStatusColor,
              ),
              _buildSettlementPdfTableRow(
                'تاریخ تسویه',
                settlementDateText,
                bodyFont,
              ),
              _buildSettlementPdfTableRow(
                'شماره کارت طلبکار',
                cardText,
                bodyFont,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildSettlementPdfTableRow(
    String label,
    String value,
    pw.Font bodyFont, {
    PdfColor? valueColor,
  }) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.white),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              font: bodyFont,
              color: valueColor ?? PdfColors.black,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              font: bodyFont,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSettlementPdfInfoRow(
    String label,
    String value,
    pw.Font bodyFont,
    pw.Font boldFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 88,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                font: boldFont,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                font: bodyFont,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTopRoundedPdfTable({
    required pw.Widget child,
    double radius = 8,
  }) {
    return _TopRoundedClip(radius: radius, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final eventData = provider.getEventData(widget.eventId);

    if (eventData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('نتیجه تسویه')),
        body: const Center(child: Text('رویداد یافت نشد')),
      );
    }

    final debts = provider.calculateDebtsForEvent(widget.eventId);
    final balances = provider.calculateBalancesForEvent(widget.eventId);
    final eventColor = eventData.event.color ?? Colors.teal;

    // محاسبه آمار
    final participants = eventData.participants;
    final expenses = eventData.expenses;
    final totalExpenses = expenses.fold<double>(
      0.0,
      (double sum, Expense e) => sum + e.amount,
    );
    final fairShare = participants.isNotEmpty
        ? (totalExpenses / participants.length).toDouble()
        : 0.0;

    // منطق هوشمند نمایش میانگین:
    // فقط در صورتی میانگین نمایش داده می‌شود که:
    // ۱. تمام شرکت‌کنندگان در تمام هزینه‌ها شریک باشند.
    // ۲. سهم واقعی هر نفر در تمام هزینه‌ها با سهم مساوی یکی باشد.
    bool showFairShare = true;
    for (var expense in expenses) {
      // شرط ۱: آیا همه شرکت‌کنندگان در این هزینه شریک هستند؟
      if (expense.involvedParticipantIds.length != participants.length) {
        showFairShare = false;
        break;
      }

      // شرط ۲: آیا سهم واقعی هر نفر مساوی است؟
      bool isActuallyEqual = true;
      final numParticipants = expense.involvedParticipantIds.length;

      if (expense.splitType == 'equal') {
        // در حالت مساوی، قطعاً مساوی است!
        isActuallyEqual = true;
      } else if (expense.splitType == 'percent' &&
          expense.customWeights != null) {
        // در حالت درصدی: آیا همه درصدها برابرند؟
        final expectedPercent = 100.0 / numParticipants;
        double firstWeight = -1;
        for (var id in expense.involvedParticipantIds) {
          final weight = expense.customWeights![id];
          if (weight == null) {
            isActuallyEqual = false;
            break;
          }
          if (firstWeight < 0) {
            firstWeight = weight;
          }
          // بررسی با محدوده خطای کوچک برای مشکلات ممیزی
          if ((weight - expectedPercent).abs() > 0.01) {
            isActuallyEqual = false;
            break;
          }
        }
      } else if (expense.splitType == 'shares' &&
          expense.customWeights != null) {
        // در حالت سهام: آیا همه سهام‌ها برابرند؟
        double firstWeight = -1;
        for (var id in expense.involvedParticipantIds) {
          final weight = expense.customWeights![id];
          if (weight == null) {
            isActuallyEqual = false;
            break;
          }
          if (firstWeight < 0) {
            firstWeight = weight;
          }
          if ((weight - firstWeight).abs() > 0.001) {
            isActuallyEqual = false;
            break;
          }
        }
      } else if (expense.splitType == 'amount' &&
          expense.customWeights != null) {
        // در حالت مبلغ: آیا همه مبالغ‌ها برابرند؟
        final expectedAmount = expense.amount / numParticipants;
        for (var id in expense.involvedParticipantIds) {
          final weight = expense.customWeights![id];
          if (weight == null) {
            isActuallyEqual = false;
            break;
          }
          if ((weight - expectedAmount).abs() > 0.01) {
            isActuallyEqual = false;
            break;
          }
        }
      } else {
        // اگر نوع تقسیم نامشخص است یا customWeights null است، مساوی فرض نکن!
        isActuallyEqual = false;
      }

      if (!isActuallyEqual) {
        showFairShare = false;
        break;
      }
    }

    final Map<String, double> totalSpent = {};
    for (var participant in participants) {
      totalSpent[participant.id] = 0;
    }
    for (var expense in expenses) {
      totalSpent[expense.payerId] =
          (totalSpent[expense.payerId] ?? 0) + expense.amount;
    }

    return WillPopScope(
      onWillPop: () async {
        // کمی تاخیر برای رفع باگ
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسویه حساب'),
          centerTitle: true,
          backgroundColor: eventColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'نمودارها',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChartsScreen(
                      eventId: widget.eventId,
                      eventColor: eventColor,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'اشتراک‌گذاری گزارش',
              onPressed: () => _showMainShareOptions(
                context,
                eventData.event.name,
                debts,
                participants,
                totalSpent,
                fairShare,
                settings,
                balances,
                showFairShare,
                expenses,
                eventData.event.startDate,
                eventData.event.endDate,
                eventColor,
              ),
            ),
          ],
        ),
        body: debts.isEmpty
            ? _buildNoDebts(context)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // کادر خلاصه رویداد (کپی از صفحه نمودار)
                    _buildEventSummaryCards(
                      context,
                      settings,
                      totalExpenses,
                      participants.length,
                      expenses.length,
                      fairShare,
                      showFairShare,
                      Theme.of(context).brightness == Brightness.dark,
                      eventColor,
                    ),
                    const SizedBox(height: 16),

                    // کارت خلاصه
                    _buildSummaryCard(
                      context,
                      participants,
                      totalSpent,
                      fairShare,
                      settings,
                      eventColor,
                      balances,
                      showFairShare,
                    ),
                    const SizedBox(height: 24),

                    // عنوان تسویه‌ها و فیلتر
                    Row(
                      children: [
                        Icon(Icons.compare_arrows, color: eventColor, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          'تسویه حساب',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const SizedBox(width: 4),
                        // فیلتر تسویه (سه حالت)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _settlementFilterMode =
                                  (_settlementFilterMode + 1) % 3;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _settlementFilterMode == 1
                                  ? Colors.red.withOpacity(0.12)
                                  : _settlementFilterMode == 2
                                  ? Colors.green.withOpacity(0.12)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _settlementFilterMode == 1
                                    ? Colors.red.withOpacity(0.4)
                                    : _settlementFilterMode == 2
                                    ? Colors.green.withOpacity(0.4)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            child: Tooltip(
                              message: _settlementFilterMode == 0
                                  ? 'فیلتر: همه تسویه‌ها'
                                  : _settlementFilterMode == 1
                                  ? 'فیلتر: فقط تسویه نشده‌ها'
                                  : 'فیلتر: فقط تسویه شده‌ها',
                              child: Icon(
                                _settlementFilterMode == 0
                                    ? Icons.swap_horiz_rounded
                                    : _settlementFilterMode == 1
                                    ? Icons.pending_actions_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 20,
                                color: _settlementFilterMode == 1
                                    ? Colors.red
                                    : _settlementFilterMode == 2
                                    ? Colors.green
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // فیلتر مدرن
                        GestureDetector(
                          onTap: () => _showFilterSheet(
                            context,
                            participants,
                            eventColor,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _selectedDebtorIds.isEmpty
                                  ? Colors.grey.withOpacity(0.1)
                                  : eventColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedDebtorIds.isEmpty
                                    ? Colors.grey.withOpacity(0.3)
                                    : eventColor.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedDebtorIds.isEmpty
                                      ? Icons.filter_list_rounded
                                      : Icons.filter_alt_rounded,
                                  size: 20,
                                  color: _selectedDebtorIds.isEmpty
                                      ? Colors.grey[700]
                                      : eventColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedDebtorIds.isEmpty
                                      ? 'فیلتر بدهکار'
                                      : '${_selectedDebtorIds.length} نفر',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _selectedDebtorIds.isEmpty
                                        ? Colors.grey[700]
                                        : eventColor,
                                    fontWeight: _selectedDebtorIds.isEmpty
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // لیست گروه‌های بدهی فیلتر شده
                    ..._groupDebtsByDebtor(_getFilteredDebts(debts)).map(
                      (group) => _buildDebtGroupCard(
                        context,
                        group.value,
                        group.key,
                        settings,
                        eventColor,
                        eventData.event.name,
                        fairShare,
                        showFairShare,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showMainShareOptions(
    BuildContext context,
    String eventName,
    List debts,
    List participants,
    Map<String, double> totalSpent,
    double fairShare,
    SettingsProvider settings,
    Map<String, double> balances,
    bool showFairShare,
    List<Expense> expenses,
    DateTime? eventStartDate,
    DateTime? eventEndDate,
    Color? eventColor,
  ) {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اشتراک‌گذاری گزارش رویداد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.text_fields_rounded,
                  color: Colors.blue,
                ),
                title: const Text('اشتراک‌گذاری متنی'),
                subtitle: const Text('خلاصه گزارش به صورت متن'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'کپی متن',
                  onPressed: () {
                    final now = Jalali.now();
                    final dateStr = now.formatJalaliCompact().toPersianNumbers();

                    final buffer = StringBuffer();
                    buffer.writeln('🌟 گزارش کامل رویداد $eventName 🌟');
                    buffer.writeln('━━━━━━━━━━━━━━━');
                    buffer.writeln('📅 تاریخ گزارش: $dateStr');
                    buffer.writeln(
                      '👥 تعداد شرکت‌کنندگان: ${participants.length.toString().toPersianNumbers()} نفر',
                    );
                    buffer.writeln(
                      '💰 مجموع هزینه‌های ثبت شده: ${settings.formatAmount(totalSpent.values.fold(0.0, (a, b) => a + b)).toPersianNumbers()}',
                    );

                    if (showFairShare) {
                      buffer.writeln(
                        '⚖️ سهم مساوی هر نفر: ${settings.formatAmount(fairShare).toPersianNumbers()}',
                      );
                    }

                    buffer.writeln('\n📊 وضعیت مالی افراد:');
                    buffer.writeln('-------------------------------');
                    for (var p in participants) {
                      final spent = totalSpent[p.id] ?? 0.0;
                      final balance = balances[p.id] ?? 0.0;
                      String status = 'بی‌حساب';
                      if (balance > 0.01)
                        status = 'طلبکار 🟢';
                      else if (balance < -0.01)
                        status = 'بدهکار 🔴';

                      buffer.writeln('👤 ${p.name}:');
                      buffer.writeln(
                        '   💸 پرداختی: ${settings.formatAmount(spent).toPersianNumbers()}',
                      );
                      buffer.writeln(
                        '   📉 تراز نهایی: ${settings.formatAmount(balance.abs()).toPersianNumbers()} ($status)',
                      );
                      buffer.writeln('');
                    }

                    buffer.writeln('🔄 لیست تسویه‌های لازم:');
                    buffer.writeln('-------------------------------');
                    if (debts.isEmpty) {
                      buffer.writeln('✅ تمام حساب‌ها صاف است.');
                    } else {
                      for (var debt in debts) {
                        String cardInfo = '';
                        if (debt.creditorCardNumber != null &&
                            debt.creditorCardNumber!.isNotEmpty) {
                          cardInfo =
                              '\n   💳 شماره کارت طلبکار: ${_formatCardNumberRaw(debt.creditorCardNumber!)}';
                        }

                        String statusEmoji = debt.isSettled
                            ? '✅ (تسویه شده)'
                            : '⏳ (در انتظار)';
                        buffer.writeln(
                          '• ${debt.debtorName} ⬅️ ${debt.creditorName}',
                        );
                        buffer.writeln(
                          '   💰 مبلغ: ${settings.formatAmount(debt.amount).toPersianNumbers()} $statusEmoji$cardInfo',
                        );
                        buffer.writeln('');
                      }
                    }
                    buffer.writeln('━━━━━━━━━━━━━━━');
                    buffer.writeln('✨ مدیریت شده با اپلیکیشن دنگ چی ✨');

                    Clipboard.setData(ClipboardData(text: buffer.toString()));
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text('متن کپی شد'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final now = Jalali.now();
                  final dateStr = now.formatJalaliCompact().toPersianNumbers();
                  final buffer = StringBuffer();
                  buffer.writeln('🌟 گزارش کامل رویداد $eventName 🌟');
                  buffer.writeln('━━━━━━━━━━━━━━━');
                  buffer.writeln('📅 تاریخ گزارش: $dateStr');
                  buffer.writeln(
                    '👥 تعداد شرکت‌کنندگان: ${participants.length.toString().toPersianNumbers()} نفر',
                  );
                  buffer.writeln(
                    '💰 مجموع هزینه‌های ثبت شده: ${settings.formatAmount(totalSpent.values.fold(0.0, (a, b) => a + b)).toPersianNumbers()}',
                  );

                  if (showFairShare) {
                    buffer.writeln(
                      '⚖️ سهم مساوی هر نفر: ${settings.formatAmount(fairShare).toPersianNumbers()}',
                    );
                  }

                  buffer.writeln('\n📊 وضعیت مالی افراد:');
                  buffer.writeln('-------------------------------');
                  for (var p in participants) {
                    final spent = totalSpent[p.id] ?? 0.0;
                    final balance = balances[p.id] ?? 0.0;
                    String status = 'بی‌حساب';
                    if (balance > 0.01)
                      status = 'طلبکار 🟢';
                    else if (balance < -0.01)
                      status = 'بدهکار 🔴';

                    buffer.writeln('👤 ${p.name}:');
                    buffer.writeln(
                      '   💸 پرداختی: ${settings.formatAmount(spent).toPersianNumbers()}',
                    );
                    buffer.writeln(
                      '   📉 تراز نهایی: ${settings.formatAmount(balance.abs()).toPersianNumbers()} ($status)',
                    );
                    buffer.writeln('');
                  }

                  buffer.writeln('🔄 لیست تسویه‌های لازم:');
                  buffer.writeln('-------------------------------');
                  if (debts.isEmpty) {
                    buffer.writeln('✅ تمام حساب‌ها صاف است.');
                  } else {
                    for (var debt in debts) {
                      String cardInfo = '';
                      if (debt.creditorCardNumber != null &&
                          debt.creditorCardNumber!.isNotEmpty) {
                        cardInfo =
                            '\n   💳 شماره کارت طلبکار: ${_formatCardNumberRaw(debt.creditorCardNumber!)}';
                      }

                      String statusEmoji = debt.isSettled
                          ? '✅ (تسویه شده)'
                          : '⏳ (در انتظار)';
                      buffer.writeln(
                        '• ${debt.debtorName} ⬅️ ${debt.creditorName}',
                      );
                      buffer.writeln(
                        '   💰 مبلغ: ${settings.formatAmount(debt.amount).toPersianNumbers()} $statusEmoji$cardInfo',
                      );
                      buffer.writeln('');
                    }
                  }
                  buffer.writeln('━━━━━━━━━━━━━━━');
                  buffer.writeln('✨ مدیریت شده با اپلیکیشن دنگ چی ✨');

                  if (parentContext.mounted) {
                    await _shareText(
                      parentContext,
                      buffer.toString(),
                      subject: 'گزارش رویداد $eventName',
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.red,
                ),
                title: const Text('خروجی PDF'),
                subtitle: const Text('ساخت فایل PDF رسمی از گزارش'),
                onTap: () {
                  Navigator.pop(context);
                  _generatePDF(
                    context,
                    eventName,
                    debts,
                    participants,
                    totalSpent,
                    fairShare,
                    settings,
                    balances,
                    showFairShare,
                    expenses,
                    eventStartDate,
                    eventEndDate,
                    eventColor,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_rounded, color: Colors.green),
                title: const Text('اشتراک‌گذاری تصویری'),
                subtitle: const Text('خروجی تصویری از کل صفحه تسویه'),
                onTap: () async {
                  Navigator.pop(context);
                  await _shareFullReportImage(
                    parentContext,
                    eventName,
                    debts,
                    participants,
                    totalSpent,
                    fairShare,
                    settings,
                    balances,
                    showFairShare,
                    eventStartDate,
                    eventEndDate,
                    eventColor,
                    totalSpent.values.fold(0.0, (a, b) => a + b),
                    expenses.length,
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareText(
    BuildContext context,
    String text, {
    String? subject,
  }) async {
    if (!kIsWeb) {
      await Share.share(text, subject: subject);
      return;
    }

    // روی وب: اول سعی می‌کنیم Share API مرورگر را صدا بزنیم.
    // روی موبایل (iOS/Android) کار می‌کند، روی دسکتاپ Chrome/Edge ممکن است شکست بخورد.
    try {
      await Share.share(text, subject: subject);
    } catch (_) {
      // fallback برای دسکتاپ مرورگر
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        _showWebCopyFallbackDialog(context, text);
      }
    }
  }

  void _showWebCopyFallbackDialog(BuildContext context, String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('متن کپی شد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اشتراک‌گذاری مستقیم در این مرورگر پشتیبانی نمی‌شود. متن گزارش در کلیپ‌بورد کپی شد.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 11),
                maxLines: 8,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  List _getFilteredDebts(List debts) {
    List filtered = debts;
    if (_selectedDebtorIds.isNotEmpty) {
      filtered = filtered
          .where((debt) => _selectedDebtorIds.contains(debt.debtorId))
          .toList();
    }
    if (_settlementFilterMode == 1) {
      filtered = filtered.where((debt) => !debt.isSettled).toList();
    } else if (_settlementFilterMode == 2) {
      filtered = filtered.where((debt) => debt.isSettled).toList();
    }
    return filtered;
  }

  List<MapEntry<String, List>> _groupDebtsByDebtor(List debts) {
    final groups = <String, List>{};
    for (final debt in debts) {
      groups.putIfAbsent(debt.debtorId, () => []).add(debt);
    }
    final entries = groups.entries.toList();
    entries.sort((a, b) {
      final totalA = a.value.fold(0.0, (sum, d) => sum + (d.amount ?? 0.0));
      final totalB = b.value.fold(0.0, (sum, d) => sum + (d.amount ?? 0.0));
      return totalB.compareTo(totalA);
    });
    return entries;
  }

  void _showFilterSheet(
    BuildContext context,
    List participants,
    Color eventColor,
  ) {
    String filterSearchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredParticipants = participants
                .where(
                  (p) => p.name.toLowerCase().contains(
                    filterSearchQuery.toLowerCase(),
                  ),
                )
                .toList();

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'فیلتر بر اساس بدهکار',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() => _selectedDebtorIds.clear());
                          setState(() {});
                        },
                        child: const Text('پاک کردن همه'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (context, setFieldState) {
                      final controller = TextEditingController(
                        text: filterSearchQuery,
                      );
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                      );
                      return TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'جستجوی نام...',
                          prefixIcon: filterSearchQuery.isEmpty
                              ? const Icon(Icons.search, size: 20)
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setModalState(() {
                                      filterSearchQuery = '';
                                    });
                                    setFieldState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 20,
                                  tooltip: 'پاک کردن متن جستجو',
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.1),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            filterSearchQuery = value;
                          });
                          setFieldState(() {});
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: filteredParticipants.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(child: Text('شخصی یافت نشد')),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredParticipants.length,
                              itemBuilder: (context, index) {
                                final p = filteredParticipants[index];
                                final isSelected = _selectedDebtorIds.contains(
                                  p.id,
                                );
                                return CheckboxListTile(
                                  title: Text(p.name),
                                  value: isSelected,
                                  activeColor: eventColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        _selectedDebtorIds.add(p.id);
                                      } else {
                                        _selectedDebtorIds.remove(p.id);
                                      }
                                    });
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: eventColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('تایید'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoDebts(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 100,
            color: Colors.green.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'همه تسویه شده‌اند!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'هیچ بدهی باقی نمانده است',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSummaryCards(
    BuildContext context,
    SettingsProvider settings,
    double totalExpenses,
    int participantsCount,
    int expensesCount,
    double fairShare,
    bool showFairShare,
    bool isDark,
    Color eventColor,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark
                ? eventColor.withOpacity(0.2)
                : eventColor.withOpacity(0.1),
            isDark
                ? eventColor.withOpacity(0.1)
                : eventColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventCompactStat(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'مجموع هزینه‌ها',
                    value: settings
                        .formatAmount(totalExpenses)
                        .toPersianNumbers(),
                    color: eventColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildEventCompactStat(
                    icon: Icons.people_rounded,
                    label: 'شرکت‌کنندگان',
                    value: '$participantsCount نفر'.toPersianNumbers(),
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const VerticalDivider(
              width: 20,
              thickness: 1,
              indent: 4,
              endIndent: 4,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventCompactStat(
                    icon: Icons.functions_rounded,
                    label: 'میانگین سهم هر نفر',
                    value: showFairShare
                        ? settings.formatAmount(fairShare).toPersianNumbers()
                        : 'نامساوی',
                    color: Colors.purple,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildEventCompactStat(
                    icon: Icons.receipt_long_rounded,
                    label: 'تعداد هزینه‌ها',
                    value: '$expensesCount مورد'.toPersianNumbers(),
                    color: Colors.deepOrange,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildEventCompactStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    List participants,
    Map<String, double> totalSpent,
    double fairShare,
    SettingsProvider settings,
    Color eventColor,
    Map<String, double> balances,
    bool showFairShare,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDark
                  ? eventColor.withOpacity(0.2)
                  : eventColor.withOpacity(0.1),
              isDark
                  ? eventColor.withOpacity(0.1)
                  : eventColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: eventColor),
                const SizedBox(width: 8),
                Text(
                  'طلبکار / بدهکار',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const Divider(height: 20, thickness: 1, color: Colors.grey),
            const SizedBox(height: 8),
            ...participants.map((participant) {
              final spent = totalSpent[participant.id] ?? 0;
              final balance = balances[participant.id] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    // Avatar removed as requested
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            participant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.payment,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                settings.formatAmount(spent).toPersianNumbers(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: balance.abs() > 0.01
                          ? () {
                              final provider = Provider.of<ExpenseProvider>(
                                context,
                                listen: false,
                              );
                              final debts = provider.calculateDebtsForEvent(
                                widget.eventId,
                              );
                              
                              // فیلتر بدهی‌های مربوط به این کاربر
                              final participantDebts = debts.where((debt) {
                                if (balance < -0.01) {
                                  // بدهکار است - نشان دادن بدهی‌هایی که این شخص بدهکار است
                                  return debt.debtorId == participant.id;
                                } else {
                                  // طلبکار است - نشان دادن بدهی‌هایی که این شخص طلبکار است
                                  return debt.creditorId == participant.id;
                                }
                              }).toList();
                              
                              if (participantDebts.isNotEmpty) {
                                _showSettlementDetailPopup(
                                  context,
                                  balance < -0.01 ? Colors.red : Colors.green,
                                  balance < -0.01 ? 'بدهی‌های ${participant.name}' : 'طلب‌های ${participant.name}',
                                  participantDebts,
                                  settings,
                                  isDark,
                                );
                              }
                            }
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: balance > 0.01
                              ? Colors.green.withOpacity(0.2)
                              : balance < -0.01
                              ? Colors.red.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          balance.abs() > 0.01
                              ? settings
                                    .formatAmount(
                                      balance.abs(),
                                      withUnit: false,
                                    )
                                    .toPersianNumbers()
                              : '۰',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: balance > 0.01
                                ? Colors.green
                                : balance < -0.01
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtCard(
    BuildContext context,
    debt,
    SettingsProvider settings,
    Color eventColor,
    String eventName,
    double fairShare,
    bool showFairShare, {
    bool hideDescription = false,
  }) {
    final provider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // نام‌ها و فلش و مبلغ (چیدمان عمودی برای فضای بیشتر)
            Column(
              children: [
                // بدهکار (بالا)
                Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  message: 'بدهکار',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).scaffoldBackgroundColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.red[400]!.withOpacity(0.8)
                            : Colors.red.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 18,
                          color: isDark ? Colors.red[300]! : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            debt.debtorName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.red[300]! : Colors.red,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // کادر مبلغ تمام‌عرض با طراحی مدرن (وسط)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // خط جداکننده (خط‌چین یا کمرنگ)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        color: isDark
                            ? Colors.red[400]!.withOpacity(0.3)
                            : Colors.red.withOpacity(0.2),
                      ),
                      // کادر مبلغ
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Theme.of(context).scaffoldBackgroundColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.red[400]!.withOpacity(0.8)
                                : Colors.red.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              color: isDark ? Colors.red[300]! : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              settings
                                  .formatAmount(debt.amount)
                                  .toPersianNumbers(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.red[300]! : Colors.red,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_downward_rounded,
                              color: isDark ? Colors.red[300]! : Colors.red,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // طلبکار و شماره کارت (ادغام شده)
                Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  message: 'طلبکار',
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).scaffoldBackgroundColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.green[400]!.withOpacity(0.8)
                            : Colors.green.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        // بخش نام طلبکار
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 18,
                                color: isDark
                                    ? Colors.green[300]!
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  debt.creditorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark
                                        ? Colors.green[300]!
                                        : Colors.green,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // شماره کارت (اگر موجود باشد)
                        if (debt.creditorCardNumber != null &&
                            debt.creditorCardNumber!.isNotEmpty) ...[
                              Container(
                                height: 0.5,
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                                color: isDark
                                    ? Colors.green[700]!.withOpacity(0.3)
                                    : Colors.green.withOpacity(0.2),
                              ),
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                // بخش شماره کارت
                                Expanded(
                                    child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.credit_card_rounded,
                                          size: 18,
                                          color: isDark
                                              ? Colors.green[300]!
                                              : Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Directionality(
                                            textDirection: ui.TextDirection.ltr,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                _formatCardNumberRaw(
                                                  debt.creditorCardNumber!,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontFamily: 'monospace',
                                                  letterSpacing: 1,
                                                  color: isDark
                                                      ? Colors.green[300]!
                                                      : Colors.green,
                                                ),
                                                textAlign: TextAlign.end,
                                                maxLines: 1,
                                                softWrap: false,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // جداکننده عمودی (یکسان‌سازی شده)
                                VerticalDivider(
                                  color: isDark
                                      ? Colors.green[400]!.withOpacity(0.4)
                                      : Colors.green.withOpacity(0.5),
                                  thickness: 1,
                                  width: 1,
                                ),
                                // دکمه کپی
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                    ),
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: debt.creditorCardNumber!,
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('شماره کارت کپی شد'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 54,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.copy,
                                        size: 20,
                                        color: isDark
                                            ? Colors.green[300]!
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // کادر اکشن و یادداشت ادغام شده
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).scaffoldBackgroundColor
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: debt.isSettled
                      ? (isDark
                            ? Colors.green[400]!.withOpacity(0.8)
                            : Colors.green.withOpacity(0.5))
                      : (isDark
                            ? Colors.red[400]!.withOpacity(0.8)
                            : Colors.red.withOpacity(0.5)),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        // بخش تسویه حساب
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _RotatingIcon(
                                  icon: debt.isSettled
                                      ? Icons.check_circle_rounded
                                      : Icons.pending_actions_rounded,
                                  color: debt.isSettled
                                      ? (isDark ? Colors.green[300]! : Colors.green)
                                      : (isDark ? Colors.red[300]! : Colors.red),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    debt.isSettled ? 'تسویه شده' : 'تسویه نشده',
                                    key: ValueKey(debt.isSettled),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: debt.isSettled
                                          ? (isDark
                                                ? Colors.green[300]!
                                                : Colors.green)
                                          : (isDark
                                                ? Colors.red[300]!
                                                : Colors.red),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // آیکون تسویه
                        InkWell(
                          onTap: () async {
                            final provider = Provider.of<ExpenseProvider>(
                              context,
                              listen: false,
                            );
                            _showSettlementDialog(
                              context,
                              provider,
                              settings,
                              debt,
                              isEditing: debt.isSettled,
                            );
                          },
                          child: Container(
                            width: 54,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.edit_note_rounded,
                              size: 22,
                              color: debt.isSettled
                                  ? (isDark ? Colors.green[300]! : Colors.green)
                                  : (isDark ? Colors.red[300]! : Colors.red),
                            ),
                          ),
                        ),
                        // جداکننده عمودی
                        VerticalDivider(
                          color: debt.isSettled
                              ? (isDark
                                    ? Colors.green[700]!
                                    : Colors.green.withOpacity(0.2))
                              : (isDark
                                    ? Colors.red[700]!
                                    : Colors.red.withOpacity(0.2)),
                          thickness: 1,
                          width: 1,
                        ),
                        // بخش اشتراک‌گذاری
                        InkWell(
                          onTap: () => _showShareOptions(
                            context,
                            settings,
                            debt,
                            eventName,
                            fairShare,
                            showFairShare,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            bottomLeft: Radius.circular(
                              (debt.isSettled &&
                                          debt.settlementDescription != null &&
                                          debt
                                              .settlementDescription!
                                              .isNotEmpty) ||
                                      (debt.isSettled &&
                                          debt.settlementDate != null)
                                  ? 0
                                  : 16,
                            ),
                          ),
                          child: Container(
                            width: 54,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.share_rounded,
                              size: 20,
                              color: debt.isSettled
                                  ? (isDark ? Colors.green[300]! : Colors.green)
                                  : (isDark ? Colors.red[300]! : Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // نمایش اطلاعات تسویه (تاریخ و توضیحات)
                  if (debt.isSettled &&
                      (debt.settlementDate != null ||
                          (debt.settlementDescription != null &&
                              debt.settlementDescription!.isNotEmpty))) ...[
                    Divider(
                      color: isDark
                          ? Colors.green[700]!
                          : Colors.green.withOpacity(0.2),
                      height: 1,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // تاریخ و ساعت (بالا)
                          if (debt.settlementDate != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_outlined,
                                    size: 18,
                                    color: isDark
                                        ? Colors.green[300]!
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'تاریخ تسویه: ${_formatSettlementDate(debt.settlementDate!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.green[300]!
                                            : Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // یادداشت (پایین)
                          if (!hideDescription &&
                              debt.settlementDescription != null &&
                              debt.settlementDescription!.isNotEmpty) ...[
                            if (debt.settlementDate != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Divider(
                                  color: isDark
                                      ? Colors.green[700]!.withOpacity(0.5)
                                      : Colors.green.withOpacity(0.1),
                                  height: 1,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      debt.settlementDescription!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.green[300]!
                                            : Colors.green.shade800,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtGroupCard(
    BuildContext context,
    List debts,
    String debtorId,
    SettingsProvider settings,
    Color eventColor,
    String eventName,
    double fairShare,
    bool showFairShare, {
    bool hideDescription = false,
  }) {
    final provider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            ...debts
                .map((debt) {
                  final child = Column(
                    children: [
                      // نام بدهکار (تکرار برای هر بدهی)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Theme.of(context).scaffoldBackgroundColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.red[400]!.withOpacity(0.8)
                                : Colors.red.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 18,
                              color: isDark ? Colors.red[300]! : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                debts.first.debtorName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? Colors.red[300]! : Colors.red,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // کادر مبلغ
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              color: isDark
                                  ? Colors.red[400]!.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.2),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Theme.of(context).scaffoldBackgroundColor
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.red[400]!.withOpacity(0.8)
                                      : Colors.red.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    color: isDark
                                        ? Colors.red[300]!
                                        : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    settings
                                        .formatAmount(debt.amount)
                                        .toPersianNumbers(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.red[300]!
                                          : Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    color: isDark
                                        ? Colors.red[300]!
                                        : Colors.red,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // طلبکار + شماره کارت + وضعیت تسویه (ادغام شده)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Theme.of(context).scaffoldBackgroundColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.green[400]!.withOpacity(0.8)
                                : Colors.green.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            // نام طلبکار
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 18,
                                    color: isDark
                                        ? Colors.green[300]!
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      debt.creditorName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDark
                                            ? Colors.green[300]!
                                            : Colors.green,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // شماره کارت
                            if (debt.creditorCardNumber != null &&
                                debt.creditorCardNumber!.isNotEmpty) ...[
                              Divider(
                                color: isDark
                                    ? Colors.green[400]!.withOpacity(0.4)
                                    : Colors.green.withOpacity(0.5),
                                height: 1,
                              ),
                              IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.credit_card_rounded,
                                              size: 18,
                                              color: isDark
                                                  ? Colors.green[300]!
                                                  : Colors.green,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Directionality(
                                                textDirection: ui.TextDirection.ltr,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    _formatCardNumberRaw(
                                                      debt.creditorCardNumber!,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontFamily: 'monospace',
                                                      letterSpacing: 1,
                                                      color: isDark
                                                          ? Colors.green[300]!
                                                          : Colors.green,
                                                    ),
                                                    textAlign: TextAlign.end,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    VerticalDivider(
                                      color: isDark
                                          ? Colors.green[400]!.withOpacity(0.4)
                                          : Colors.green.withOpacity(0.5),
                                      thickness: 1,
                                      width: 1,
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(16),
                                        ),
                                        onTap: () {
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: debt.creditorCardNumber!,
                                            ),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'شماره کارت کپی شد',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: 54,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.copy,
                                            size: 20,
                                            color: isDark
                                                ? Colors.green[300]!
                                                : Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // وضعیت تسویه + دکمه اشتراک
                            Divider(
                              color: isDark
                                  ? Colors.green[400]!.withOpacity(0.4)
                                  : Colors.green.withOpacity(0.5),
                              height: 1,
                            ),
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          _RotatingIcon(
                                            icon: debt.isSettled
                                                ? Icons.check_circle_rounded
                                                : Icons.pending_actions_rounded,
                                            color: debt.isSettled
                                                ? (isDark ? Colors.green[300]! : Colors.green)
                                                : (isDark ? Colors.red[300]! : Colors.red),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 300),
                                            child: Text(
                                              debt.isSettled
                                                  ? 'تسویه شده'
                                                  : 'تسویه نشده',
                                              key: ValueKey(debt.isSettled),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: debt.isSettled
                                                    ? (isDark
                                                          ? Colors.green[300]!
                                                          : Colors.green)
                                                    : (isDark
                                                          ? Colors.red[300]!
                                                          : Colors.red),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final provider =
                                          Provider.of<ExpenseProvider>(
                                            context,
                                            listen: false,
                                          );
                                      _showSettlementDialog(
                                        context,
                                        provider,
                                        settings,
                                        debt,
                                        isEditing: debt.isSettled,
                                      );
                                    },
                                    child: Container(
                                      width: 54,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.edit_note_rounded,
                                        size: 22,
                                        color: debt.isSettled
                                            ? (isDark ? Colors.green[300]! : Colors.green)
                                            : (isDark ? Colors.red[300]! : Colors.red),
                                      ),
                                    ),
                                  ),
                                  VerticalDivider(
                                    color: isDark
                                        ? Colors.green[400]!.withOpacity(0.4)
                                        : Colors.green.withOpacity(0.5),
                                    thickness: 1,
                                    width: 1,
                                  ),
                                  InkWell(
                                    onTap: () => _showShareOptions(
                                      context,
                                      settings,
                                      debt,
                                      eventName,
                                      fairShare,
                                      showFairShare,
                                    ),
                                    child: Container(
                                      width: 54,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.share_rounded,
                                        size: 20,
                                        color: isDark
                                            ? Colors.green[300]!
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // تاریخ تسویه
                            if (!hideDescription &&
                                debt.isSettled &&
                                debt.settlementDate != null) ...[
                              Divider(
                                color: isDark
                                    ? Colors.green[400]!.withOpacity(0.4)
                                    : Colors.green.withOpacity(0.5),
                                height: 1,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_outlined,
                                      size: 18,
                                      color: isDark
                                          ? Colors.green[300]!
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'تاریخ تسویه: ${_formatSettlementDate(debt.settlementDate!)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.green[300]!
                                              : Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // توضیحات تسویه
                            if (!hideDescription &&
                                debt.isSettled &&
                                debt.settlementDescription != null &&
                                debt.settlementDescription!.isNotEmpty) ...[
                              if (debt.settlementDate != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Divider(
                                    color: isDark
                                        ? Colors.green[400]!.withOpacity(0.4)
                                        : Colors.green.withOpacity(0.5),
                                    height: 1,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        debt.settlementDescription!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.green[300]!
                                              : Colors.green.shade800,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (debt != debts.last)
                        Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  height: 1,
                                  color: eventColor.withOpacity(0.3),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Theme.of(
                                            context,
                                          ).scaffoldBackgroundColor
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: eventColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '+',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: eventColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                  return [child];
                })
                .expand((x) => x),
          ],
        ),
      ),
    );
  }

  void _showShareOptions(
    BuildContext context,
    SettingsProvider settings,
    dynamic debt,
    String eventName,
    double fairShare,
    bool showFairShare,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('اشتراک‌گذاری تسویه'),
        content: const Text('نوع اشتراک‌گذاری را انتخاب کنید:'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final now = Jalali.now();
                    final dateStr = now
                        .formatJalaliCompact()
                        .toPersianNumbers();

                    // تاریخ تسویه (اگر موجود)
                    String settlementDateStr = '';
                    if (debt.isSettled && debt.settlementDate != null) {
                      final sDate = Jalali.fromDateTime(debt.settlementDate!);
                      final timeStr =
                          '${debt.settlementDate!.hour.toString().padLeft(2, '0')}:${debt.settlementDate!.minute.toString().padLeft(2, '0')}';
                      settlementDateStr =
                          '📅 تاریخ تسویه:\n   ${sDate.formatJalaliCompact().toPersianNumbers()} ساعت ${timeStr.toPersianNumbers()}\n\n';
                    }

                    // فرمت شماره کارت برای پیام
                    String formattedCard = '';
                    if (debt.creditorCardNumber != null &&
                        debt.creditorCardNumber!.isNotEmpty) {
                      formattedCard = _formatCardNumberRaw(
                        debt.creditorCardNumber!,
                      );
                    }

                    final text =
                        '🌟 گزارش تسویه حساب دنگ چی 🌟\n'
                        '━━━━━━━━━━━━━━━\n\n'
                        '📌 نام رویداد:\n'
                        '   $eventName\n\n'
                        '📅 تاریخ:\n'
                        '   $dateStr\n\n'
                        '${showFairShare ? "👥 سهم هر نفر:\n   ${settings.formatAmount(fairShare).toPersianNumbers()}\n\n" : ""}'
                        '👤 ${debt.debtorName}\n\n'
                        '💳 ${debt.creditorName}\n\n'
                        '💰 مبلغ تسویه:\n'
                        '   ${settings.formatAmount(debt.amount).toPersianNumbers()}\n\n'
                        '$settlementDateStr'
                        '${formattedCard.isNotEmpty ? "💳 شماره کارت:\n   $formattedCard\n\n" : ""}'
                        '━━━━━━━━━━━━━━━\n'
                        '✨ مدیریت شده با دنگ چی ✨';
                    if (context.mounted) {
                      await _shareText(context, text);
                    }
                  },
                  icon: const Icon(Icons.text_fields_rounded, size: 18),
                  label: const Text('اشتراک‌گذاری متنی'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _shareSettlementPdf(
                      context,
                      settings,
                      debt,
                      eventName,
                      fairShare,
                      showFairShare,
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('اشتراک‌گذاری PDF'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    // Don't pop yet, let _shareImage handle it
                    await _shareImage(
                      context,
                      settings,
                      debt,
                      eventName,
                      fairShare,
                      showFairShare,
                    );
                  },
                  icon: const Icon(Icons.image_rounded, size: 18),
                  label: const Text('اشتراک‌گذاری تصویری'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementSharePreview({
    required BuildContext context,
    required SettingsProvider settings,
    required dynamic debt,
    required String eventName,
    required DateTime? eventStartDate,
    required DateTime? eventEndDate,
    required Color eventColor,
    required double fairShare,
    required bool showFairShare,
  }) {
    final String eventDateRange = () {
      if (eventStartDate != null && eventEndDate != null) {
        final start = Jalali.fromDateTime(
          eventStartDate,
        ).formatJalaliCompact().toPersianNumbers();
        final end = Jalali.fromDateTime(
          eventEndDate,
        ).formatJalaliCompact().toPersianNumbers();
        return '$start - $end';
      } else if (eventStartDate != null) {
        return Jalali.fromDateTime(
          eventStartDate,
        ).formatJalaliCompact().toPersianNumbers();
      } else if (eventEndDate != null) {
        return Jalali.fromDateTime(
          eventEndDate,
        ).formatJalaliCompact().toPersianNumbers();
      }
      return '';
    }();

    final isSettled = debt.isSettled == true;
    final statusColor = isSettled ? Colors.green : Colors.red;
    final statusBg = isSettled ? Colors.green.shade50 : Colors.red.shade50;
    final statusBorder = isSettled
        ? Colors.green.shade200
        : Colors.red.shade200;
    final statusText = isSettled ? 'تسویه شده' : 'در انتظار تسویه';
    final statusIcon = isSettled
        ? Icons.check_circle_rounded
        : Icons.pending_actions_rounded;
    final settlementDateText = debt.settlementDate != null
        ? 'تاریخ تسویه: ${Jalali.fromDateTime(debt.settlementDate!).formatJalaliCompact().toPersianNumbers()} ساعت ${debt.settlementDate!.hour.toString().padLeft(2, '0')}:${debt.settlementDate!.minute.toString().padLeft(2, '0')}'
              .toPersianNumbers()
        : null;
    final cardNumberText =
        debt.creditorCardNumber != null && debt.creditorCardNumber!.isNotEmpty
        ? _formatCardNumberRaw(debt.creditorCardNumber!)
        : null;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              eventColor.withOpacity(0.10),
              Colors.white,
              eventColor.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: eventColor.withOpacity(0.14), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      eventColor.withOpacity(0.14),
                      eventColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: eventColor.withOpacity(0.18)),
                ),
                child: Column(
                  children: [
                    Text(
                      eventName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color.lerp(eventColor, Colors.black, 0.22),
                        fontFamily: 'Vazirmatn',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (eventDateRange.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        eventDateRange,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontFamily: 'Vazirmatn',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.28)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 18,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              debt.debtorName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                                fontFamily: 'Vazirmatn',
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 18),
                          color: eventColor.withOpacity(0.16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: eventColor.withOpacity(0.30),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                color: eventColor,
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                settings
                                    .formatAmount(debt.amount)
                                    .toPersianNumbers(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: eventColor,
                                  fontFamily: 'Vazirmatn',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_downward_rounded,
                                color: eventColor,
                                size: 17,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.30),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  debt.creditorName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                    fontFamily: 'Vazirmatn',
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (cardNumberText != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.20),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.credit_card_rounded,
                                    size: 18,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cardNumberText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: Colors.green,
                                      ),
                                      textDirection: ui.TextDirection.ltr,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (settlementDateText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: 17,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                settlementDateText,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Vazirmatn',
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(statusIcon, size: 18, color: statusColor),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'اپلیکیشن دنگ چی',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullReportSharePreview({
    required BuildContext context,
    required String eventName,
    required List debts,
    required List participants,
    required Map<String, double> totalSpent,
    required double fairShare,
    required SettingsProvider settings,
    required Map<String, double> balances,
    required bool showFairShare,
    required DateTime? eventStartDate,
    required DateTime? eventEndDate,
    required Color eventColor,
    required double totalExpenses,
    required int expensesCount,
  }) {
    final String eventDateRange = () {
      if (eventStartDate != null && eventEndDate != null) {
        final start = Jalali.fromDateTime(
          eventStartDate,
        ).formatJalaliCompact().toPersianNumbers();
        final end = Jalali.fromDateTime(
          eventEndDate,
        ).formatJalaliCompact().toPersianNumbers();
        return '$start - $end';
      } else if (eventStartDate != null) {
        return Jalali.fromDateTime(
          eventStartDate,
        ).formatJalaliCompact().toPersianNumbers();
      } else if (eventEndDate != null) {
        return Jalali.fromDateTime(
          eventEndDate,
        ).formatJalaliCompact().toPersianNumbers();
      }
      return '';
    }();

    final visibleDebts = _getFilteredDebts(debts);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              eventColor.withOpacity(0.08),
              Colors.white,
              eventColor.withOpacity(0.03),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: eventColor.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      eventColor.withOpacity(0.16),
                      eventColor.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: eventColor.withOpacity(0.18)),
                ),
                child: Column(
                  children: [
                    Text(
                      eventName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color.lerp(eventColor, Colors.black, 0.22),
                        fontFamily: 'Vazirmatn',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (eventDateRange.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        eventDateRange,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontFamily: 'Vazirmatn',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildEventSummaryCards(
                context,
                settings,
                totalExpenses,
                participants.length,
                expensesCount,
                fairShare,
                showFairShare,
                false,
                eventColor,
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                context,
                participants,
                totalSpent,
                fairShare,
                settings,
                eventColor,
                balances,
                showFairShare,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.compare_arrows, color: eventColor, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'تسویه حساب',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._groupDebtsByDebtor(visibleDebts).map(
                (group) => _buildDebtGroupCard(
                  context,
                  group.value,
                  group.key,
                  settings,
                  eventColor,
                  eventName,
                  fairShare,
                  showFairShare,
                  hideDescription: true,
                ),
              ),
              if (visibleDebts.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'هیچ بدهی باقی نمانده است.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'اپلیکیشن دنگ چی',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareFullReportImage(
    BuildContext context,
    String eventName,
    List debts,
    List participants,
    Map<String, double> totalSpent,
    double fairShare,
    SettingsProvider settings,
    Map<String, double> balances,
    bool showFairShare,
    DateTime? eventStartDate,
    DateTime? eventEndDate,
    Color? eventColor,
    double totalExpenses,
    int expensesCount,
  ) async {
    try {
      final color = eventColor ?? Colors.teal;
      final completer = Completer<Uint8List>();
      final repaintKey = GlobalKey();
      OverlayEntry? entry;

      entry = OverlayEntry(
        builder: (BuildContext overlayContext) => Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                left: -10000,
                top: 0,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: SizedBox(
                    width: 480,
                    child: _buildFullReportSharePreview(
                      context: overlayContext,
                      eventName: eventName,
                      debts: debts,
                      participants: participants,
                      totalSpent: totalSpent,
                      fairShare: fairShare,
                      settings: settings,
                      balances: balances,
                      showFairShare: showFairShare,
                      eventStartDate: eventStartDate,
                      eventEndDate: eventEndDate,
                      eventColor: color,
                      totalExpenses: totalExpenses,
                      expensesCount: expensesCount,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      Overlay.of(context, rootOverlay: true).insert(entry);
      await Future.delayed(const Duration(milliseconds: 300));

      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          completer.complete(byteData.buffer.asUint8List());
        } else {
          completer.completeError('Failed to get image bytes');
        }
      } else {
        completer.completeError('Failed to capture widget');
      }

      entry.remove();
      final pngBytes = await completer.future;
      final fileName =
          '${eventName.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_').replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'_+'), '_').trim()}_report.png';
      if (context.mounted) {
        await _shareCapturedPng(
          context: context,
          pngBytes: pngBytes,
          fileName: fileName,
          shareText: 'گزارش رویداد $eventName',
          shareSubject: 'گزارش رویداد $eventName',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری تصویر: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _shareCapturedPng({
    required BuildContext context,
    required Uint8List pngBytes,
    required String fileName,
    required String shareText,
    required String shareSubject,
  }) async {
    final previousDownloadFallbackEnabled = Share.downloadFallbackEnabled;
    try {
      Share.downloadFallbackEnabled = false;
      await Share.shareXFiles(
        [XFile.fromData(pngBytes, mimeType: 'image/png', name: fileName)],
        text: shareText,
        subject: shareSubject,
        fileNameOverrides: [fileName],
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری تصویر: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      Share.downloadFallbackEnabled = previousDownloadFallbackEnabled;
    }
  }

  Future<void> _shareImage(
    BuildContext context,
    SettingsProvider settings,
    dynamic debt,
    String eventName,
    double fairShare,
    bool showFairShare,
  ) async {
    try {
      final eventData = Provider.of<ExpenseProvider>(
        context,
        listen: false,
      ).getEventData(widget.eventId);
      final Color eventColor = eventData?.event.color ?? Colors.teal;

      final completer = Completer<Uint8List>();
      final repaintKey = GlobalKey();
      OverlayEntry? entry;

      // Create an overlay entry to render the widget off-screen
      entry = OverlayEntry(
        builder: (BuildContext overlayContext) => Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                left: -10000,
                top: 0,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: SizedBox(
                    width: 480,
                    child: _buildSettlementSharePreview(
                      context: overlayContext,
                      settings: settings,
                      debt: debt,
                      eventName: eventName,
                      eventStartDate: eventData?.event.startDate,
                      eventEndDate: eventData?.event.endDate,
                      eventColor: eventColor,
                      fairShare: fairShare,
                      showFairShare: showFairShare,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Add the overlay
      Overlay.of(context).insert(entry!);
      await Future.delayed(const Duration(milliseconds: 300));

      // Capture the image
      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          completer.complete(byteData.buffer.asUint8List());
        } else {
          completer.completeError('Failed to get image bytes');
        }
      } else {
        completer.completeError('Failed to capture widget');
      }

      // Remove the overlay
      entry.remove();

      // Wait for capture to complete
      final pngBytes = await completer.future;

      final safeEventName = eventName
          .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .trim();
      final fileName =
          '${safeEventName}_debt_${debt.debtorName}_${debt.creditorName}.png';

      // Pop the options dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Share image
      if (context.mounted) {
        await _shareCapturedPng(
          context: context,
          pngBytes: pngBytes,
          fileName: fileName,
          shareText: 'تسویه حساب $eventName',
          shareSubject: 'تسویه حساب $eventName',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری تصویر: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _shareSettlementPdf(
    BuildContext context,
    SettingsProvider settings,
    dynamic debt,
    String eventName,
    double fairShare,
    bool showFairShare,
  ) async {
    try {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final eventData = provider.getEventData(widget.eventId);
      if (eventData == null) {
        throw Exception('رویداد یافت نشد');
      }
      final event = eventData.event;

      final participants = eventData.participants;
      final expenses = eventData.expenses;
      final debts = provider.calculateDebtsForEvent(widget.eventId);
      final balances = provider.calculateBalancesForEvent(widget.eventId);
      final totalSpent = <String, double>{};
      for (var participant in participants) {
        totalSpent[participant.id] = 0;
      }
      for (var expense in expenses) {
        totalSpent[expense.payerId] =
            (totalSpent[expense.payerId] ?? 0) + expense.amount;
      }

      await _generatePDF(
        context,
        eventName,
        debts,
        participants,
        totalSpent,
        fairShare,
        settings,
        balances,
        showFairShare,
        expenses,
        eventData.event.startDate,
        eventData.event.endDate,
        eventData.event.color,
        settlementDebt: debt,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _generatePDF(
    BuildContext context,
    String eventName,
    List debts,
    List participants,
    Map<String, double> totalSpent,
    double fairShare,
    SettingsProvider settings,
    Map<String, double> balances,
    bool showFairShare,
    List<Expense> expenses,
    DateTime? eventStartDate,
    DateTime? eventEndDate,
    Color? eventColor, {
    dynamic settlementDebt,
  }) async {
    final pdf = pw.Document();

    // Load Fonts
    final fontData = await rootBundle.load(
      "assets/fonts/Vazirmatn-Regular.ttf",
    );
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load(
      "assets/fonts/Vazirmatn-Bold.ttf",
    );
    final ttfBold = pw.Font.ttf(fontBoldData);

    final String eventDateRange = () {
      if (eventStartDate != null && eventEndDate != null) {
        final start = Jalali.fromDateTime(
          eventStartDate,
        ).formatJalaliCompact().toPersianNumbers();
        final end = Jalali.fromDateTime(
          eventEndDate,
        ).formatJalaliCompact().toPersianNumbers();
        return '$start - $end';
      } else if (eventStartDate != null) {
        return Jalali.fromDateTime(
          eventStartDate,
        ).formatJalaliCompact().toPersianNumbers();
      } else if (eventEndDate != null) {
        return Jalali.fromDateTime(
          eventEndDate,
        ).formatJalaliCompact().toPersianNumbers();
      }
      return '';
    }();

    final PdfColor headerPdfColor = eventColor != null
        ? PdfColor(
            eventColor.red / 255,
            eventColor.green / 255,
            eventColor.blue / 255,
          )
        : PdfColors.blue700;

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(1.0 * PdfPageFormat.cm),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: headerPdfColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'گزارش رویداد $eventName',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          font: ttfBold,
                          color: PdfColors.white,
                        ),
                      ),
                      if (eventDateRange.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          eventDateRange,
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.white,
                            font: ttf,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (context.pageNumber == 1) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                    border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  ),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(8),
                            ),
                            border: pw.Border.all(
                              color: PdfColors.grey300,
                              width: 1,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'تعداد اعضا',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                  font: ttf,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                '${participants.length.toString().toPersianNumbers()} نفر',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: headerPdfColor,
                                  font: ttfBold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(8),
                            ),
                            border: pw.Border.all(
                              color: PdfColors.grey300,
                              width: 1,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'جمع کل هزینه ها',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                  font: ttf,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                settings
                                    .formatAmount(
                                      totalSpent.values.fold(
                                        0.0,
                                        (a, b) => a + b,
                                      ),
                                      withUnit: true,
                                    )
                                    .toPersianNumbers(),
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: headerPdfColor,
                                  font: ttfBold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showFairShare) ...[
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(8),
                              ),
                              border: pw.Border.all(
                                color: PdfColors.grey300,
                                width: 1,
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'میانگین سهم هر نفر',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.grey700,
                                    font: ttf,
                                  ),
                                ),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                  settings
                                      .formatAmount(fairShare)
                                      .toPersianNumbers(),
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                    color: headerPdfColor,
                                    font: ttfBold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'تاریخ گزارش: ${DateTime.now().toJalali().formatJalaliCompact().toPersianNumbers()}',
                    style: const pw.TextStyle(
                      color: PdfColors.grey600,
                      fontSize: 10,
                    ),
                  ),
                  pw.Text(
                    'صفحه ${context.pageNumber.toString().toPersianNumbers()} از ${context.pagesCount.toString().toPersianNumbers()}',
                    style: const pw.TextStyle(
                      color: PdfColors.grey600,
                      fontSize: 10,
                    ),
                  ),
                  pw.Text(
                    'اپلیکیشن دنگ چی',
                    style: const pw.TextStyle(
                      color: PdfColors.grey600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 15),

            if (settlementDebt != null) ...[
              _buildSettlementPdfDetailsSection(
                debt: settlementDebt,
                titleFont: ttfBold,
                bodyFont: ttf,
                boldFont: ttfBold,
                headerPdfColor: headerPdfColor,
              ),
              pw.SizedBox(height: 20),
              pw.NewPage(),
            ],

            // Summary Table Section
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildPdfSectionTitle('خلاصه وضعیت', ttfBold, headerPdfColor),
                _buildTopRoundedPdfTable(
                  child: pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1),
                    },
                    border: pw.TableBorder(
                      top: const pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 1,
                      ),
                      bottom: const pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 1,
                      ),
                      left: const pw.BorderSide(
                        color: PdfColors.grey200,
                        width: 0.5,
                      ),
                      right: const pw.BorderSide(
                        color: PdfColors.grey200,
                        width: 0.5,
                      ),
                      verticalInside: const pw.BorderSide(
                        color: PdfColors.grey200,
                        width: 0.5,
                      ),
                      horizontalInside: const pw.BorderSide(
                        color: PdfColors.grey200,
                        width: 0.5,
                      ),
                    ),
                    children: [
                      // سرستون‌ها
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: headerPdfColor),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 10,
                            ),
                            child: pw.Text(
                              'تراز',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: ttfBold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'وضعیت',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: ttfBold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'پرداختی',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: ttfBold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'نام',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: ttfBold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      // داده‌ها
                      ...participants.asMap().entries.map((entry) {
                        int index = entry.key;
                        var p = entry.value;
                        final spent = totalSpent[p.id] ?? 0;
                        final balance = balances[p.id] ?? 0.0;
                        String status;
                        String amountDisplay = '';
                        PdfColor textColor = PdfColors.black;

                        if (balance > 0.01) {
                          status = 'طلبکار';
                          amountDisplay =
                              '+${settings.formatAmount(balance.abs(), withUnit: false).toPersianNumbers()}';
                          textColor = PdfColors.green;
                        } else if (balance < -0.01) {
                          status = 'بدهکار';
                          amountDisplay =
                              '-${settings.formatAmount(balance.abs(), withUnit: false).toPersianNumbers()}';
                          textColor = PdfColors.red;
                        } else {
                          status = 'بی حساب';
                          amountDisplay = '۰';
                          textColor = PdfColors.grey;
                        }

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: index.isEven
                                ? PdfColors.grey50
                                : PdfColors.white,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 10,
                              ),
                              child: pw.Text(
                                amountDisplay,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: textColor,
                                  font: ttf,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                status,
                                style: const pw.TextStyle(fontSize: 12),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                settings.formatAmount(spent).toPersianNumbers(),
                                style: const pw.TextStyle(fontSize: 12),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                p.name,
                                style: const pw.TextStyle(fontSize: 12),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 40),

            // Expense Details Section
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (expenses.isEmpty)
                  pw.Center(
                    child: pw.Text(
                      'هیچ هزینه‌ای ثبت نشده است.',
                      style: const pw.TextStyle(color: PdfColors.grey600),
                    ),
                  )
                else
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _buildPdfSectionTitle(
                        'جزئیات هزینه ها',
                        ttfBold,
                        headerPdfColor,
                      ),
                      _buildTopRoundedPdfTable(
                        child: pw.Table(
                          columnWidths: {
                            0: const pw.FlexColumnWidth(1),
                            1: const pw.FlexColumnWidth(1),
                            2: const pw.FlexColumnWidth(1),
                            3: const pw.FlexColumnWidth(1),
                          },
                          border: pw.TableBorder(
                            top: const pw.BorderSide(
                              color: PdfColors.grey300,
                              width: 1,
                            ),
                            bottom: const pw.BorderSide(
                              color: PdfColors.grey300,
                              width: 1,
                            ),
                            left: const pw.BorderSide(
                              color: PdfColors.grey200,
                              width: 0.5,
                            ),
                            right: const pw.BorderSide(
                              color: PdfColors.grey200,
                              width: 0.5,
                            ),
                            verticalInside: const pw.BorderSide(
                              color: PdfColors.grey200,
                              width: 0.5,
                            ),
                            horizontalInside: const pw.BorderSide(
                              color: PdfColors.grey200,
                              width: 0.5,
                            ),
                          ),
                          children: [
                            pw.TableRow(
                              decoration: pw.BoxDecoration(
                                color: headerPdfColor,
                              ),
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  child: pw.Text(
                                    'تاریخ',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                      font: ttfBold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  child: pw.Text(
                                    'پرداخت کننده',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                      font: ttfBold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  child: pw.Text(
                                    'مبلغ',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                      font: ttfBold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  child: pw.Text(
                                    'عنوان هزینه',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                      font: ttfBold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            ...expenses.asMap().entries.map((entry) {
                              int index = entry.key;
                              var e = entry.value;
                              final payerName = participants
                                  .firstWhere(
                                    (p) => p.id == e.payerId,
                                    orElse: () =>
                                        Participant(id: '', name: 'نامشخص'),
                                  )
                                  .name
                                  .replaceAll('\u200c', ' ');
                              final dateStr = e.date != null
                                  ? Jalali.fromDateTime(
                                      e.date!,
                                    ).formatJalaliCompact().toPersianNumbers()
                                  : '-';
                              final cleanTitle = e.title.replaceAll(
                                '\u200c',
                                ' ',
                              );
                              return pw.TableRow(
                                decoration: pw.BoxDecoration(
                                  color: index.isEven
                                      ? PdfColors.grey50
                                      : PdfColors.white,
                                ),
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    child: pw.Text(
                                      dateStr,
                                      style: const pw.TextStyle(fontSize: 10),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    child: pw.Text(
                                      payerName,
                                      style: const pw.TextStyle(fontSize: 10),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    child: pw.Text(
                                      settings
                                          .formatAmount(e.amount)
                                          .toPersianNumbers(),
                                      style: const pw.TextStyle(fontSize: 10),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    child: pw.Text(
                                      cleanTitle,
                                      style: const pw.TextStyle(fontSize: 10),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            pw.SizedBox(height: 40),

            // Debts Table Section
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (debts.isEmpty)
                  pw.Center(
                    child: pw.Text(
                      'هیچ تراکنشی لازم نیست.',
                      style: const pw.TextStyle(color: PdfColors.grey600),
                    ),
                  )
                else
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _buildPdfSectionTitle(
                        'تسویه حساب',
                        ttfBold,
                        headerPdfColor,
                      ),
                      _buildTopRoundedPdfTable(
                        child: pw.Table(
                          columnWidths: {
                            0: const pw.FlexColumnWidth(1),
                            1: const pw.FlexColumnWidth(1),
                            2: const pw.FlexColumnWidth(1),
                            3: const pw.FlexColumnWidth(1),
                          },
                          border: pw.TableBorder(
                            top: const pw.BorderSide(
                              color: PdfColors.grey300,
                              width: 1,
                            ),
                            bottom: const pw.BorderSide(
                              color: PdfColors.grey300,
                              width: 1,
                            ),
                            left: const pw.BorderSide(
                              color: PdfColors.grey200,
                              width: 0.5,
                            ),
                            right: const pw.BorderSide(
                              color: PdfColors.grey200,
                              width: 0.5,
                            ),
                            verticalInside: const pw.BorderSide(
                              color: PdfColors.grey200,
                              width: 0.5,
                            ),
                            horizontalInside: const pw.BorderSide(
                              color: PdfColors.grey200,
                              width: 0.5,
                            ),
                          ),
                          children: [
                            // سرستون‌ها
                            pw.TableRow(
                              decoration: pw.BoxDecoration(
                                color: headerPdfColor,
                              ),
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  child: pw.Text(
                                    'تاریخ تسویه',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                      font: ttfBold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  child: pw.Text(
                                    'طلبکار',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                      font: ttfBold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  child: pw.Text(
                                    'مبلغ',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                      font: ttfBold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 10,
                                  ),
                                  child: pw.Text(
                                    'بدهکار',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                      font: ttfBold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            // داده‌ها
                            ...debts.asMap().entries.map((entry) {
                              int index = entry.key;
                              var debt = entry.value;
                              return pw.TableRow(
                                decoration: pw.BoxDecoration(
                                  color: index.isEven
                                      ? PdfColors.grey50
                                      : PdfColors.white,
                                ),
                                children: [
                                  // تاریخ تسویه
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    child: pw.Text(
                                      debt.isSettled
                                          ? debt.settlementDate != null
                                                ? '${Jalali.fromDateTime(debt.settlementDate!).formatJalaliCompact().toPersianNumbers()} ${debt.settlementDate!.hour.toString().padLeft(2, '0')}:${debt.settlementDate!.minute.toString().padLeft(2, '0')}'
                                                      .toPersianNumbers()
                                                : 'تسویه شده'
                                          : '-',
                                      style: const pw.TextStyle(fontSize: 12),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                  // طلبکار
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    child: pw.Text(
                                      debt.creditorName,
                                      style: const pw.TextStyle(fontSize: 12),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                  // مبلغ
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    child: pw.Text(
                                      settings
                                          .formatAmount(debt.amount)
                                          .toPersianNumbers(),
                                      style: pw.TextStyle(
                                        fontSize: 12,
                                        color: headerPdfColor,
                                      ),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                  // بدهکار
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    child: pw.Text(
                                      debt.debtorName,
                                      style: const pw.TextStyle(fontSize: 12),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 20),
          ];
        },
      ),
    );

    // ساخت نام فایل بر اساس نام event
    String safeEventName = eventName
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();

    if (safeEventName.isEmpty || safeEventName.length < 2) {
      safeEventName = 'dangchi_report';
    }

    if (safeEventName.length > 50) {
      safeEventName = safeEventName.substring(0, 50);
    }

    String fileName = settlementDebt != null
        ? '${safeEventName}_settlement_report.pdf'
        : '${safeEventName}_report.pdf';

    // Share PDF با نام فایل دلخواه
    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }
}

class _TopRoundedClip extends pw.SingleChildWidget {
  _TopRoundedClip({required this.radius, pw.Widget? child})
    : super(child: child);

  final double radius;

  @override
  void paint(pw.Context context) {
    super.paint(context);

    if (child != null) {
      final mat = Matrix4.identity();
      mat.translate(box!.x, box!.y);
      final borderRadius = pw.BorderRadius.only(
        topLeft: pw.Radius.circular(radius),
        topRight: pw.Radius.circular(radius),
      );

      context.canvas..saveContext();
      borderRadius.paint(context, box!);
      context.canvas.clipPath();
      context.canvas.setTransform(mat);
      child!.paint(context);
      context.canvas.restoreContext();
    }
  }
}

/// آیکون چرخان با مکث — یه دور میچرخه، مکث میکنه، دوباره
class _RotatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _RotatingIcon({
    required this.icon,
    required this.color,
    this.size = 18,
  });

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    // کل سیکل: ۱.۲ ثانیه چرخش + ۱.۸ ثانیه مکث = ۳ ثانیه
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _rotation = TweenSequence<double>([
      // چرخش کامل ۳۶۰ درجه در ۴۰٪ از زمان
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      // مکث در ۶۰٪ باقیمانده
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotation,
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}
