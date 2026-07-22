import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../providers/expense_provider.dart';
import '../widgets/persian_date_picker.dart';
import '../utils/jalali_extension.dart';
import '../models/event.dart';

class EditEventScreen extends StatefulWidget {
  final String eventId;

  const EditEventScreen({super.key, required this.eventId});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Color _selectedColor = Colors.teal;
  IconData _selectedIcon = Icons.event;
  Jalali? _startDate;
  Jalali? _endDate;

  // رنگ‌های پیشنهادی
  final List<Color> _suggestedColors = [
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.deepPurple,
    Colors.pink,
    Colors.red,
    Colors.deepOrange,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.lightGreen,
    Colors.cyan,
    Colors.lightBlue,
    Colors.brown,
    Colors.blueGrey,
  ];

  // آیکون‌های پیشنهادی
  final List<Map<String, dynamic>> _suggestedIcons = [
    {'icon': Icons.event, 'label': 'رویداد'},
    {'icon': Icons.restaurant, 'label': 'رستوران'},
    {'icon': Icons.flight, 'label': 'سفر'},
    {'icon': Icons.beach_access, 'label': 'ساحل'},
    {'icon': Icons.forest, 'label': 'جنگل'},
    {'icon': Icons.hiking, 'label': 'کوهنوردی'},
    {'icon': Icons.business, 'label': 'رسمی'},
    {'icon': Icons.celebration, 'label': 'جشن'},
    {'icon': Icons.sports_soccer, 'label': 'ورزشی'},
    {'icon': Icons.local_cafe, 'label': 'کافه'},
    {'icon': Icons.shopping_bag, 'label': 'خرید'},
    {'icon': Icons.movie, 'label': 'سینما'},
    {'icon': Icons.music_note, 'label': 'کنسرت'},
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final eventData = provider.getEventData(widget.eventId);
    if (eventData != null) {
      final event = eventData.event;
      _nameController.text = event.name;
      _selectedColor = event.color ?? Colors.teal;
      _selectedIcon = event.icon ?? Icons.event;
      if (event.startDate != null)
        _startDate = Jalali.fromDateTime(event.startDate!);
      if (event.endDate != null) _endDate = Jalali.fromDateTime(event.endDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        final provider = Provider.of<ExpenseProvider>(context, listen: false);
        await provider.updateEvent(
          eventId: widget.eventId,
          name: _nameController.text,
          color: _selectedColor,
          icon: _selectedIcon,
          startDate: _startDate?.toDateTime(),
          endDate: _endDate?.toDateTime(),
        );
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطا: $e')));
        }
      }
    }
  }

  Future<void> _pickStartDate() async {
    FocusScope.of(context).unfocus(); // Unfocus all fields
    final picked = await showCustomPersianDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: Jalali(1400),
      lastDate: Jalali(1410),
      primaryColor: _selectedColor,
      title: 'انتخاب تاریخ شروع',
      rangeStart: _endDate,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.compareTo(_startDate!) < 0) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    FocusScope.of(context).unfocus(); // Unfocus all fields
    // If no start date is selected, show a message
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً ابتدا تاریخ شروع را انتخاب کنید')),
      );
      return;
    }

    final picked = await showCustomPersianDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate!,
      lastDate: Jalali(1410),
      primaryColor: _selectedColor,
      title: 'انتخاب تاریخ پایان',
      rangeStart: _startDate,
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش رویداد'),
        centerTitle: true,
        backgroundColor: _selectedColor,
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
              // ─── کارت نام + رنگ + آیکون ───
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // نام برنامه
                      Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            color: _selectedColor,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'نام رویداد',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameController,
                        textAlign: TextAlign.right,
                        maxLength: 25,
                        inputFormatters: [LengthLimitingTextInputFormatter(25)],
                        onChanged: (value) {
                          if (value.length > 25) {
                            _nameController.text = value.substring(0, 25);
                            _nameController
                                .selection = TextSelection.fromPosition(
                              TextPosition(offset: _nameController.text.length),
                            );
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'نام رویداد',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'لطفاً نام رویداد را وارد کنید';
                          }
                          if (value.trim().length > 25) {
                            return 'نام رویداد نمی‌تواند بیش از 25 کاراکتر باشد';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // انتخاب رنگ
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context)
                                    .copyWith(
                                      dragDevices: {
                                        PointerDeviceKind.touch,
                                        PointerDeviceKind.mouse,
                                      },
                                    ),
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _suggestedColors.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final color = _suggestedColors[index];
                                    final isSelected =
                                        _selectedColor.value == color.value;
                                    return GestureDetector(
                                      onTap: () => setState(
                                        () => _selectedColor = color,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 2.5,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 16,
                                              )
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // انتخاب آیکون
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context)
                                    .copyWith(
                                      dragDevices: {
                                        PointerDeviceKind.touch,
                                        PointerDeviceKind.mouse,
                                      },
                                    ),
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _suggestedIcons.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final item = _suggestedIcons[index];
                                    final isSelected =
                                        _selectedIcon == item['icon'];
                                    return GestureDetector(
                                      onTap: () => setState(
                                        () => _selectedIcon = item['icon'],
                                      ),
                                      child: Tooltip(
                                        message: item['label'] as String,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _selectedColor
                                                : _selectedColor.withOpacity(
                                                    0.08,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? _selectedColor
                                                  : Colors.grey.shade300,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Icon(
                                            item['icon'] as IconData,
                                            color: isSelected
                                                ? Colors.white
                                                : _selectedColor,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey.withOpacity(0.15),
                        ),
                      ),

                      // بازه زمانی
                      Row(
                        children: [
                          Icon(
                            Icons.date_range_rounded,
                            color: _selectedColor,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'بازه زمانی (اختیاری)',
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
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // تاریخ شروع
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickStartDate,
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
                                              color: _startDate != null
                                                  ? _selectedColor.withOpacity(
                                                      0.15,
                                                    )
                                                  : Colors.grey.withOpacity(
                                                      0.08,
                                                    ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.calendar_today_rounded,
                                              size: 14,
                                              color: _startDate != null
                                                  ? _selectedColor
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
                                                  'شروع',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _startDate != null
                                                      ? _startDate!
                                                            .formatJalaliCompact()
                                                      : 'انتخاب تاریخ',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        _startDate != null
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: _startDate != null
                                                        ? Theme.of(context)
                                                              .textTheme
                                                              .bodyLarge
                                                              ?.color
                                                        : Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_startDate != null)
                                            GestureDetector(
                                              onTap: () {
                                                setState(
                                                  () => _startDate = null,
                                                );
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

                                // خط جداکننده
                                VerticalDivider(
                                  width: 1,
                                  thickness: 1,
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withOpacity(0.12),
                                  indent: 8,
                                  endIndent: 8,
                                ),

                                // تاریخ پایان
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickEndDate,
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
                                              color: _endDate != null
                                                  ? _selectedColor.withOpacity(
                                                      0.15,
                                                    )
                                                  : Colors.grey.withOpacity(
                                                      0.08,
                                                    ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.calendar_month_rounded,
                                              size: 14,
                                              color: _endDate != null
                                                  ? _selectedColor
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
                                                  'پایان',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _endDate != null
                                                      ? _endDate!
                                                            .formatJalaliCompact()
                                                      : 'انتخاب تاریخ',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: _endDate != null
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: _endDate != null
                                                        ? Theme.of(context)
                                                              .textTheme
                                                              .bodyLarge
                                                              ?.color
                                                        : Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_endDate != null)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() => _endDate = null);
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
