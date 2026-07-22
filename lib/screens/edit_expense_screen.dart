import 'dart:io';
import 'package:flutter/foundation.dart'; // Add this
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/persian_date_picker.dart';
import '../utils/jalali_extension.dart';
import '../utils/thousands_separator_formatter.dart';
import 'package:intl/intl.dart';

class EditExpenseScreen extends StatefulWidget {
  final String eventId;
  final String expenseId;

  const EditExpenseScreen({
    super.key,
    required this.eventId,
    required this.expenseId,
  });

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedPayerId;
  Jalali? _selectedDate;
  XFile? _receiptImage;
  String? _existingReceiptPath;
  Set<String> _involvedParticipantIds = {};
  String _splitType = 'equal'; // 'equal', 'percent', 'shares', 'amount'
  Map<String, double> _participantWeights =
      {}; // شناسه شرکت‌کننده -> مقدار (درصد یا سهم)

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    final eventData = provider.getEventData(widget.eventId);
    Expense? expense;
    if (eventData != null) {
      expense = eventData.expenses.firstWhere(
        (e) => e.id == widget.expenseId,
        orElse: () => Expense(id: '', title: '', amount: 0, payerId: ''),
      );
      if (expense.id.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }
      _titleController.text = expense.title;
      _descriptionController.text = expense.description ?? '';
      _existingReceiptPath = expense.receiptPath;

      _involvedParticipantIds = expense.involvedParticipantIds.toSet();
      _splitType = expense.splitType;

      // اگر لیست افراد خالی بود (هزینه‌های قدیمی)، همه را تیک بزن
      if (_involvedParticipantIds.isEmpty) {
        _involvedParticipantIds = eventData.participants
            .map((p) => p.id)
            .toSet();
      }

      // مقداردهی سهم‌ها
      if (expense.customWeights != null) {
        _participantWeights = Map<String, double>.from(expense.customWeights!);
      } else {
        // پیش‌فرض برای همه ۱
        for (var p in eventData.participants) {
          _participantWeights[p.id] = 1.0;
        }
      }

      // Format amount with commas
      final formatter = NumberFormat('#,###', 'en_US');
      double displayAmount = expense.amount;

      if (settings.isRial) {
        displayAmount *= 10;
      }

      _amountController.text = formatter.format(displayAmount.toInt());

      _selectedPayerId = expense.payerId;
      if (expense.date != null) {
        _selectedDate = Jalali.fromDateTime(expense.date!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _receiptImage = pickedFile;
        _existingReceiptPath = null; // Clear existing if new picked
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedPayerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لطفاً پرداخت‌کننده را انتخاب کنید')),
        );
        return;
      }

      // اعتبارسنجی انتخاب شرکای هزینه
      if (_involvedParticipantIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لطفاً حداقل یک نفر را به عنوان شریک هزینه انتخاب کنید',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // اعتبارسنجی تقسیم هزینه
      if (_involvedParticipantIds.isNotEmpty) {
        if (_splitType == 'percent') {
          final totalPercent = _participantWeights.entries
              .where((e) => _involvedParticipantIds.contains(e.key))
              .fold(0.0, (sum, e) => sum + e.value);
          if ((totalPercent - 100.0).abs() > 0.01) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'مجموع درصدها باید ۱۰۰ باشد (حالا: ${totalPercent.toInt()})',
                ),
              ),
            );
            return;
          }
        } else if (_splitType == 'amount') {
          final amountText = _amountController.text.replaceAll(',', '');
          final totalAmount = double.tryParse(amountText) ?? 0.0;
          final currentSum = _participantWeights.entries
              .where((e) => _involvedParticipantIds.contains(e.key))
              .fold(0.0, (sum, e) => sum + e.value);
          if ((currentSum - totalAmount).abs() > 0.01) {
            final settings = Provider.of<SettingsProvider>(
              context,
              listen: false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'مجموع مبالغ باید برابر هزینه کل باشد (اختلاف: ${settings.formatAmount((totalAmount - currentSum).abs())})',
                ),
              ),
            );
            return;
          }
        }
      }

      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      final amountText = _amountController.text.replaceAll(',', '');
      double amount = double.parse(amountText);

      // Convert from Rial to Toman if needed
      if (settings.isRial) {
        amount = amount / 10;
      }

      provider.updateExpense(
        eventId: widget.eventId,
        expenseId: widget.expenseId,
        title: _titleController.text,
        amount: amount,
        payerId: _selectedPayerId!,
        involvedParticipantIds: _involvedParticipantIds.toList(),
        splitType: _splitType,
        customWeights: _splitType == 'equal' ? null : _participantWeights,
        date: _selectedDate?.toDateTime(),
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        receiptPath: _receiptImage?.path ?? _existingReceiptPath,
      );

      Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus(); // Unfocus all fields
    final picked = await showCustomPersianDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: Jalali(1400),
      lastDate: Jalali(1410),
      title: 'انتخاب تاریخ هزینه',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final eventData = provider.getEventData(widget.eventId);
    final eventColor = eventData?.event.color ?? Colors.teal;

    final currencyLabel = settings.isRial ? 'ریال' : 'تومان';

    if (eventData == null || eventData.participants.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ویرایش هزینه')),
        body: const Center(child: Text('خطا در بارگذاری اطلاعات')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش هزینه'),
        centerTitle: true,
        backgroundColor: eventColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, size: 28),
            tooltip: 'ذخیره',
            onPressed: _submit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.title, color: eventColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'عنوان هزینه',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _titleController,
                        textAlign: TextAlign.right,
                        maxLength: 25,
                        decoration: InputDecoration(
                          hintText: 'مثال: شام رستوران',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'لطفاً عنوان را وارد کنید';
                          }
                          if (value.trim().length > 25) {
                            return 'عنوان نمی‌تواند بیش از 25 کاراکتر باشد';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.attach_money, color: eventColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'مبلغ ($currencyLabel)',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _amountController,
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsSeparatorInputFormatter(),
                        ],
                        decoration: InputDecoration(
                          hintText: settings.isRial
                              ? 'مثال: 500,000'
                              : 'مثال: 50,000',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: currencyLabel,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'لطفاً مبلغ را وارد کنید';
                          }
                          final amountText = value.replaceAll(',', '');
                          final number = double.tryParse(amountText);
                          if (number == null || number <= 0) {
                            return 'مبلغ باید بیشتر از صفر باشد';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: eventColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'پرداخت‌کننده',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedPayerId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.person),
                          helperText: 'چه کسی این هزینه را پرداخت کرد؟',
                        ),
                        hint: const Text('انتخاب کنید'),
                        items: eventData.participants.map((participant) {
                          return DropdownMenuItem(
                            value: participant.id,
                            child: Text(participant.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPayerId = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),

              // بخش یکپارچه شریک در هزینه و نحوه تقسیم
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: eventColor,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'شریک در هزینه و نحوه تقسیم',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_involvedParticipantIds.length ==
                                    eventData.participants.length) {
                                  _involvedParticipantIds.clear();
                                } else {
                                  _involvedParticipantIds = eventData
                                      .participants
                                      .map((p) => p.id)
                                      .toSet();
                                }
                              });
                            },
                            child: Text(
                              _involvedParticipantIds.length ==
                                      eventData.participants.length
                                  ? 'حذف همه'
                                  : 'انتخاب همه',
                              style: TextStyle(fontSize: 12, color: eventColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: 'equal',
                              label: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.drag_handle, size: 16),
                                  SizedBox(height: 6),
                                  Text('مساوی', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            ButtonSegment(
                              value: 'shares',
                              label: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pie_chart_outline, size: 16),
                                  SizedBox(height: 6),
                                  Text('سهمی', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            ButtonSegment(
                              value: 'percent',
                              label: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.percent, size: 16),
                                  SizedBox(height: 6),
                                  Text('درصدی', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            ButtonSegment(
                              value: 'amount',
                              label: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.payments_outlined, size: 16),
                                  SizedBox(height: 6),
                                  Text('مبلغی', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                          selected: {_splitType},
                          onSelectionChanged: (newSelection) {
                            setState(() {
                              _splitType = newSelection.first;
                              if (_splitType == 'percent' &&
                                  _involvedParticipantIds.isNotEmpty) {
                                final count = _involvedParticipantIds.length;
                                final base = (100 / count).floor();
                                final remainder = 100 - base * count;
                                int i = 0;
                                for (var id in _involvedParticipantIds) {
                                  _participantWeights[id] =
                                      (i < remainder ? base + 1 : base)
                                          .toDouble();
                                  i++;
                                }
                              } else if (_splitType == 'shares') {
                                for (var id in _involvedParticipantIds) {
                                  _participantWeights[id] = 1.0;
                                }
                              } else if (_splitType == 'amount' &&
                                  _involvedParticipantIds.isNotEmpty) {
                                final amountText = _amountController.text
                                    .replaceAll(',', '');
                                final totalAmount =
                                    double.tryParse(amountText) ?? 0.0;
                                final equalAmount =
                                    totalAmount /
                                    _involvedParticipantIds.length;
                                for (var id in _involvedParticipantIds) {
                                  _participantWeights[id] = double.parse(
                                    equalAmount.toStringAsFixed(0),
                                  );
                                }
                              }
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: eventColor.withOpacity(
                              0.2,
                            ),
                            selectedForegroundColor: eventColor,
                            visualDensity: VisualDensity.standard,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 6,
                            ),
                            minimumSize: const Size(0, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      if (_splitType == 'percent')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                          child: Text(
                            'مجموع درصدها: ${_participantWeights.entries.where((e) => _involvedParticipantIds.contains(e.key)).fold(0.0, (sum, e) => sum + e.value).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  (_participantWeights.entries
                                          .where(
                                            (e) => _involvedParticipantIds
                                                .contains(e.key),
                                          )
                                          .fold(
                                            0.0,
                                            (sum, e) => sum + e.value,
                                          ) -
                                      100).abs() > 0.01
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ),
                      if (_splitType == 'amount')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                          child: Builder(
                            builder: (context) {
                              final amountText = _amountController.text
                                  .replaceAll(',', '');
                              final totalAmount =
                                  double.tryParse(amountText) ?? 0.0;
                              final currentSum = _participantWeights.entries
                                  .where(
                                    (e) =>
                                        _involvedParticipantIds.contains(e.key),
                                  )
                                  .fold(0.0, (sum, e) => sum + e.value);
                              final diff = totalAmount - currentSum;

                              return Text(
                                'مجموع مبالغ: ${settings.formatAmount(currentSum).toPersianNumbers()} $currencyLabel '
                                '${diff == 0 ? '(تکمیل)' : '(اختلاف: ${settings.formatAmount(diff).toPersianNumbers()})'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: diff != 0 ? Colors.red : Colors.green,
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: eventData.participants.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final participant = eventData.participants[index];
                            final isSelected = _involvedParticipantIds.contains(
                              participant.id,
                            );

                            return CheckboxListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            participant.name,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isSelected
                                                  ? null
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                        if (!isSelected) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.card_giftcard,
                                            size: 16,
                                            color: eventColor.withOpacity(0.8),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '(مهمان)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: eventColor.withOpacity(
                                                0.8,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isSelected && _splitType != 'equal')
                                    SizedBox(
                                      width: 100,
                                      height: 35,
                                      child: TextFormField(
                                        key: ValueKey(
                                          '${participant.id}_$_splitType',
                                        ),
                                        initialValue: _splitType == 'percent'
                                            ? (_participantWeights[participant
                                                          .id] ??
                                                      (100 /
                                                          _involvedParticipantIds
                                                              .length))
                                                  .toStringAsFixed(0)
                                            : _splitType == 'amount'
                                            ? NumberFormat(
                                                '#,###',
                                                'en_US',
                                              ).format(
                                                (_participantWeights[participant
                                                            .id] ??
                                                        0)
                                                    .toInt(),
                                              )
                                            : (_participantWeights[participant
                                                          .id] ??
                                                      1.0)
                                                  .toStringAsFixed(0),
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                        inputFormatters: _splitType == 'amount'
                                            ? [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                ThousandsSeparatorInputFormatter(),
                                              ]
                                            : [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.all(4),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          final cleanValue = value.replaceAll(
                                            ',',
                                            '',
                                          );
                                          final val = double.tryParse(
                                            cleanValue,
                                          );
                                          if (val != null) {
                                            setState(() {
                                              _participantWeights[participant
                                                      .id] =
                                                  val;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                              value: isSelected,
                              activeColor: eventColor,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _involvedParticipantIds.add(participant.id);
                                  } else {
                                    _involvedParticipantIds.remove(
                                      participant.id,
                                    );
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),

              // توضیحات
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description, color: eventColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'توضیحات (اختیاری)',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _descriptionController,
                        textAlign: TextAlign.right,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'توضیحات بیشتر...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),

              // تصویر رسید
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.image, color: eventColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'تصویر رسید',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_receiptImage != null)
                        Stack(
                          alignment: Alignment.topLeft,
                          children: [
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: kIsWeb
                                      ? NetworkImage(_receiptImage!.path)
                                      : FileImage(File(_receiptImage!.path))
                                            as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _receiptImage = null;
                                });
                              },
                              icon: const CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Icon(Icons.close, color: Colors.red),
                              ),
                            ),
                          ],
                        )
                      else if (_existingReceiptPath != null)
                        Stack(
                          alignment: Alignment.topLeft,
                          children: [
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: kIsWeb
                                      ? NetworkImage(_existingReceiptPath!)
                                      : FileImage(File(_existingReceiptPath!))
                                            as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _existingReceiptPath = null;
                                });
                              },
                              icon: const CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Icon(Icons.close, color: Colors.red),
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: Icon(Icons.camera_alt),
                          label: const Text('انتخاب/تغییر تصویر رسید'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            foregroundColor: eventColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: eventColor,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'تاریخ هزینه (اختیاری)',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _pickDate,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _selectedDate != null
                                          ? eventColor.withOpacity(0.15)
                                          : Colors.grey.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                      color: _selectedDate != null
                                          ? eventColor
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'تاریخ',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedDate != null
                                              ? _selectedDate!
                                                    .formatJalaliCompact()
                                              : 'انتخاب تاریخ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _selectedDate != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: _selectedDate != null
                                                ? Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color
                                                : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_selectedDate != null)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedDate = null);
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
