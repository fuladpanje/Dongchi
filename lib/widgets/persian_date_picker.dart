import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../utils/jalali_extension.dart';

class PersianDatePickerDialog extends StatefulWidget {
  final Jalali? initialDate;
  final Jalali firstDate;
  final Jalali lastDate;
  final Color primaryColor;
  final String? title;
  final Jalali? rangeStart; // Optional start of range for highlighting

  const PersianDatePickerDialog({
    super.key,
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.primaryColor = Colors.teal,
    this.title,
    this.rangeStart,
  });

  @override
  State<PersianDatePickerDialog> createState() =>
      _PersianDatePickerDialogState();
}

class _PersianDatePickerDialogState extends State<PersianDatePickerDialog> {
  late Jalali _selectedDate;
  late Jalali _displayedMonth;
  Jalali? _rangeStart; // Store range start if provided

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? Jalali.now();
    _displayedMonth = Jalali(_selectedDate.year, _selectedDate.month, 1);
    _rangeStart = widget.rangeStart;
  }

  void _previousMonth() {
    setState(() {
      if (_displayedMonth.month == 1) {
        _displayedMonth = Jalali(_displayedMonth.year - 1, 12, 1);
      } else {
        _displayedMonth = Jalali(
          _displayedMonth.year,
          _displayedMonth.month - 1,
          1,
        );
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_displayedMonth.month == 12) {
        _displayedMonth = Jalali(_displayedMonth.year + 1, 1, 1);
      } else {
        _displayedMonth = Jalali(
          _displayedMonth.year,
          _displayedMonth.month + 1,
          1,
        );
      }
    });
  }

  List<String> get _weekDayNames => ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  String get _monthName {
    const months = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];
    return months[_displayedMonth.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _selectedDate); // Save on Back Button
        return false;
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Custom Barrier: Click outside to save
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(_selectedDate),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.black54),
              ),
            ),

            // Dialog Content
            Center(
              child: GestureDetector(
                onTap: () {}, // Prevent clicks from hitting barrier
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title (if provided)
                      if (widget.title != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            widget.title!,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _selectedDate.formatPersianFullDate(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Month/Year selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _previousMonth,
                          ),
                          Text(
                            '$_monthName ${_displayedMonth.year}'
                                .toPersianNumbers(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.titleMedium?.color,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _nextMonth,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Week day names
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _weekDayNames
                            .map(
                              (day) => SizedBox(
                                width: 40,
                                child: Center(
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const Divider(),

                      // Calendar grid
                      _buildCalendarGrid(),

                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(
                              context,
                            ), // Cancel returns null? User said: "Should save if clicked outside". Keep cancel as cancel.
                            child: const Text('انصراف'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, _selectedDate),
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('تأیید'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = _displayedMonth.monthLength;
    final firstDayOfWeek = _displayedMonth.weekDay; // 1 = شنبه

    List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of month
    for (int i = 0; i < firstDayOfWeek - 1; i++) {
      dayWidgets.add(const SizedBox(width: 40, height: 40));
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = Jalali(_displayedMonth.year, _displayedMonth.month, day);
      final isSelected =
          date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
      final isToday =
          date.year == Jalali.now().year &&
          date.month == Jalali.now().month &&
          date.day == Jalali.now().day;

      // Determine if date is within range (if rangeStart provided)
      bool isInRange = false;
      if (_rangeStart != null) {
        final start = _rangeStart!;
        final end = _selectedDate;
        if (start.compareTo(end) <= 0) {
          isInRange = date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
        } else {
          // start after end (unlikely for end picker), swap
          isInRange = date.compareTo(end) >= 0 && date.compareTo(start) <= 0;
        }
      }

      // Check if date is outside the allowed range
      final isDisabled =
          date.compareTo(widget.firstDate) < 0 ||
          date.compareTo(widget.lastDate) > 0;

      dayWidgets.add(
        InkWell(
          onTap: isDisabled
              ? null
              : () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? widget.primaryColor
                  : (isInRange ? widget.primaryColor.withOpacity(0.3) : null),
              border: isToday && !isSelected
                  ? Border.all(color: widget.primaryColor)
                  : null,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '$day'.toPersianNumbers(),
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isInRange
                      ? Colors.white70
                      : (isDisabled ? Theme.of(context).disabledColor : null),
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(spacing: 4, runSpacing: 4, children: dayWidgets);
  }
}

// Helper function to show the picker
Future<Jalali?> showCustomPersianDatePicker({
  required BuildContext context,
  Jalali? initialDate,
  required Jalali firstDate,
  required Jalali lastDate,
  Color primaryColor = Colors.teal,
  String? title,
  Jalali? rangeStart,
}) async {
  return await showDialog<Jalali>(
    context: context,
    barrierDismissible: false, // We handle barrier dismissal manually
    barrierColor: Colors.transparent, // We draw our own barrier
    builder: (context) => PersianDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      primaryColor: primaryColor,
      title: title,
      rangeStart: rangeStart,
    ),
  );
}
