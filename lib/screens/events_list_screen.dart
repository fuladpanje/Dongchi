import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:async';
import '../models/event.dart';
import '../models/participant.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../utils/jalali_extension.dart';
import '../providers/settings_provider.dart';
import '../widgets/persian_date_picker.dart';
import 'event_detail_screen.dart';
import 'add_event_screen.dart';
import 'edit_event_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import 'contacts_screen.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _searchByParticipant = false; // حالت جستجو بر اساس شرکت‌کننده
  final Set<int> _selectedIconCodePoints =
      {}; // تغییر به Set برای انتخاب چندگانه
  Jalali? _startDateFilter;
  Jalali? _endDateFilter;
  final FocusNode _pageFocusNode = FocusNode(debugLabel: 'eventsListPageFocus');
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'eventsListSearchFocus',
  );
  final ScrollController _eventsScrollController = ScrollController();
  bool _isFabVisible = true;

  void _updateFabVisibility(double offset) {
    final shouldShow = offset < 20;
    if (shouldShow != _isFabVisible) {
      setState(() {
        _isFabVisible = shouldShow;
      });
    }
  }

  void _updateFabVisibilityFromNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta;
      if (scrollDelta == null) {
        _updateFabVisibility(notification.metrics.pixels);
      } else if (scrollDelta > 0) {
        _updateFabVisibility(double.infinity);
      } else {
        _updateFabVisibility(0);
      }
      return;
    }

    if (notification is ScrollEndNotification) {
      _updateFabVisibility(notification.metrics.pixels);
    }
  }

  void _clearSearchFocus() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_pageFocusNode.canRequestFocus) {
      _pageFocusNode.requestFocus();
    }
  }

  Future<void> _pushWithoutSearchFocus(
    BuildContext context,
    Widget page,
  ) async {
    _clearSearchFocus();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      _searchController.clear();
      _clearSearchFocus();
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _eventsScrollController.dispose();
    _pageFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('در حال بارگذاری...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final allEvents = List.from(provider.eventsList);
    allEvents.sort((a, b) {
      final dateA = a.startDate ?? a.createdAt;
      final dateB = b.startDate ?? b.createdAt;
      return dateB.compareTo(dateA);
    });

    final filteredEvents = allEvents.where((event) {
      bool matchesSearch = false;
      if (_searchQuery.trim().isEmpty) {
        matchesSearch = true;
      } else {
        final query = _searchQuery.trim().toLowerCase();
        if (_searchByParticipant) {
          // جستجو در نام شرکت‌کنندگان این برنامه
          final eventData = provider.getEventData(event.id);
          matchesSearch =
              eventData?.participants.any(
                (p) => p.name.toLowerCase().contains(query),
              ) ??
              false;
        } else {
          // جستجو در نام خود برنامه
          matchesSearch = event.name.toLowerCase().contains(query);
        }
      }

      bool matchesIcon = true;
      if (_selectedIconCodePoints.isNotEmpty) {
        matchesIcon =
            event.iconCodePoint != null &&
            _selectedIconCodePoints.contains(event.iconCodePoint);
      }

      bool matchesDate = true;
      if (_startDateFilter != null || _endDateFilter != null) {
        final eventStart = event.startDate ?? event.createdAt;
        final eventEnd = event.endDate ?? eventStart;

        final jalaliStart = Jalali.fromDateTime(eventStart);
        final jalaliEnd = Jalali.fromDateTime(eventEnd);

        if (_startDateFilter != null && _endDateFilter != null) {
          // بازه کامل: برنامه باید با بازه انتخاب شده تداخل داشته باشد
          // تداخل زمانی: (start1 <= end2) && (end1 >= start2)
          matchesDate =
              jalaliStart.compareTo(_endDateFilter!) <= 0 &&
              jalaliEnd.compareTo(_startDateFilter!) >= 0;
        } else if (_startDateFilter != null) {
          // فقط تاریخ شروع: برنامه‌هایی که بعد از این تاریخ هستند یا در این تاریخ جریان دارند
          matchesDate = jalaliEnd.compareTo(_startDateFilter!) >= 0;
        } else if (_endDateFilter != null) {
          // فقط تاریخ پایان: برنامه‌هایی که قبل از این تاریخ هستند یا در این تاریخ جریان دارند
          matchesDate = jalaliStart.compareTo(_endDateFilter!) <= 0;
        }
      }

      return matchesSearch && matchesIcon && matchesDate;
    }).toList();

    // استخراج تمام آیکون‌های استفاده شده در برنامه‌ها
    final Set<int?> usedIconCodePoints = allEvents
        .map((e) => e.iconCodePoint)
        .where((codePoint) => codePoint != null)
        .cast<int?>()
        .toSet();

    // بعد از rebuild، position اسکرول رو دوباره چک کن تا اگه محتوا کوچک‌تر شد، FAB برگرده
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _eventsScrollController.hasClients) {
        _updateFabVisibility(_eventsScrollController.offset);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const _AnimatedTitle(),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts),
            tooltip: 'مخاطبین',
            onPressed: () =>
                _pushWithoutSearchFocus(context, const ContactsScreen()),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: Image.asset(
                      'assets/icon/1024.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'دنگ چی',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('تنظیمات'),
              onTap: () {
                Navigator.pop(context);
                _pushWithoutSearchFocus(context, const SettingsScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('درباره ما'),
              onTap: () {
                Navigator.pop(context);
                _pushWithoutSearchFocus(context, const AboutScreen());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('اشتراک‌گذاری برنامه'),
              onTap: () {
                Navigator.pop(context);
                Share.share(
                  'دنگ چی - مدیریت هوشمند هزینه‌های گروهی\n\n'
                  '📱 دانلود اپلیکیشن:\n'
                  'مایکت:\n'
                  'https://myket.ir/app/com.takbaran.dangchi\n\n'
                  'کافه بازار:\n'
                  'https://cafebazaar.ir/app/com.takbaran.dangchi\n\n'
                  '🖥️ دانلود ویندوز و اندروید:\n'
                  'https://dl.dongchiapp.ir/\n\n'
                  '🌐 نسخه تحت وب (iOS):\n'
                  'https://dongchiapp.ir',
                );
              },
            ),
          ],
        ),
      ),
      body: Focus(
        focusNode: _pageFocusNode,
        skipTraversal: true,
        child: allEvents.isEmpty
            ? _buildEmptyState(context)
            : Column(
                children: [
                  // ردیف جستجو و فیلتر ادغام شده
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        // فیلد جستجو
                        Expanded(
                          child: TextField(
                            focusNode: _searchFocusNode,
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: _searchByParticipant
                                  ? 'جستجوی شرکت‌کننده...'
                                  : 'جستجوی رویداد...',
                              prefixIcon: _searchQuery.isEmpty
                                  ? const Icon(Icons.search, size: 20)
                                  : IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        _clearSearchFocus();
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 20,
                                      tooltip: 'پاک کردن متن جستجو',
                                    ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message:
                                        'تغییر به جستجوی ${_searchByParticipant ? "رویداد" : "شرکت‌کننده"}',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(15),
                                      onTap: () {
                                        setState(() {
                                          _searchByParticipant =
                                              !_searchByParticipant;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                        child: Icon(
                                          _searchByParticipant
                                              ? Icons.person_pin_rounded
                                              : Icons.person_outline_rounded,
                                          color: _searchByParticipant
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.7),
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.withOpacity(0.1),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                            ),
                            // onChanged دیگر لازم نیست چون از addListener استفاده می‌کنیم
                          ),
                        ),
                        const SizedBox(width: 8),
                        // دکمه فیلتر آیکون
                        GestureDetector(
                          onTap: () =>
                              _showIconFilterSheet(context, usedIconCodePoints),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedIconCodePoints.isEmpty
                                  ? Colors.grey.withOpacity(0.1)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedIconCodePoints.isEmpty
                                    ? Colors.grey.withOpacity(0.3)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  _selectedIconCodePoints.isEmpty
                                      ? Icons.filter_list
                                      : Icons.filter_alt,
                                  size: 20,
                                  color: _selectedIconCodePoints.isEmpty
                                      ? Colors.grey[700]
                                      : Theme.of(context).colorScheme.primary,
                                ),
                                if (_selectedIconCodePoints.isNotEmpty)
                                  Positioned(
                                    top: -5,
                                    right: -5,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        _selectedIconCodePoints.length
                                            .toString()
                                            .toPersianNumbers(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // دکمه فیلتر تاریخ
                        GestureDetector(
                          onTap: () => _showDateRangePicker(context),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  (_startDateFilter == null &&
                                      _endDateFilter == null)
                                  ? Colors.grey.withOpacity(0.1)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    (_startDateFilter == null &&
                                        _endDateFilter == null)
                                    ? Colors.grey.withOpacity(0.3)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                            child: Icon(
                              (_startDateFilter == null &&
                                      _endDateFilter == null)
                                  ? Icons.calendar_today_outlined
                                  : Icons.date_range,
                              size: 20,
                              color:
                                  (_startDateFilter == null &&
                                      _endDateFilter == null)
                                  ? Colors.grey[700]
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        if (_selectedIconCodePoints.isNotEmpty ||
                            _startDateFilter != null ||
                            _endDateFilter != null)
                          const SizedBox(width: 8),
                        if (_selectedIconCodePoints.isNotEmpty ||
                            _startDateFilter != null ||
                            _endDateFilter != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedIconCodePoints.clear();
                              _startDateFilter = null;
                              _endDateFilter = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.5),
                                ),
                              ),
                              child: Tooltip(
                                message: 'پاک کردن تمام فیلترها',
                                child: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredEvents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'رویدادی یافت نشد',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              _updateFabVisibilityFromNotification(
                                notification,
                              );
                              return false;
                            },
                            child: ListView.builder(
                              controller: _eventsScrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredEvents.length,
                              itemBuilder: (context, index) {
                                final event = filteredEvents[index];
                                final eventData = provider.getEventData(
                                  event.id,
                                );
                                if (eventData == null)
                                  return const SizedBox.shrink();
                                return _buildEventCard(
                                  context,
                                  provider,
                                  event,
                                  eventData,
                                  settings,
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: _isFabVisible
          ? FloatingActionButton.extended(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              onPressed: () => _navigateToAddEvent(context),
              backgroundColor: Colors.teal.shade700,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'رویداد جدید',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showIconFilterSheet(
    BuildContext context,
    Set<int?> usedIconCodePoints,
  ) {
    _clearSearchFocus();
    const defaultAppColor = Colors.teal;
    final List<Map<String, dynamic>> suggestedIcons = [
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'فیلتر بر اساس آیکون',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() => _selectedIconCodePoints.clear());
                          setState(() {});
                        },
                        child: const Text('پاک کردن انتخاب‌ها'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: suggestedIcons.length,
                    itemBuilder: (context, index) {
                      final item = suggestedIcons[index];
                      final icon = item['icon'] as IconData;
                      final isSelected = _selectedIconCodePoints.contains(
                        icon.codePoint,
                      );
                      final isUsed = usedIconCodePoints.contains(
                        icon.codePoint,
                      );

                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              _selectedIconCodePoints.remove(icon.codePoint);
                            } else {
                              _selectedIconCodePoints.add(icon.codePoint);
                            }
                          });
                          setState(() {});
                        },
                        child: Tooltip(
                          message: item['label'] as String,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? defaultAppColor
                                  : (isUsed
                                        ? defaultAppColor.withOpacity(0.15)
                                        : defaultAppColor.withOpacity(0.08)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? defaultAppColor
                                    : (isUsed
                                          ? defaultAppColor.withOpacity(0.5)
                                          : Colors.grey.shade300),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  icon,
                                  color: isSelected
                                      ? Colors.white
                                      : (isUsed
                                            ? defaultAppColor
                                            : defaultAppColor.withOpacity(0.7)),
                                  size: 22,
                                ),
                                if (isSelected)
                                  const Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('اعمال فیلتر'),
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

  void _showDateRangePicker(BuildContext context) {
    _clearSearchFocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Initialize internal state for the modal
        bool localIsSingleDay =
            _startDateFilter != null && _startDateFilter == _endDateFilter;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'فیلتر تاریخ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _startDateFilter = null;
                            _endDateFilter = null;
                          });
                          Navigator.pop(context);
                          _clearSearchFocus();
                        },
                        child: const Text('پاک کردن'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Toggle between Single Day and Range
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => localIsSingleDay = true);
                              // If switching to single day and we have a date, sync them immediately
                              if (_startDateFilter != null) {
                                _endDateFilter = _startDateFilter;
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: localIsSingleDay
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'یک روز',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: localIsSingleDay
                                      ? Colors.white
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  fontWeight: localIsSingleDay
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => localIsSingleDay = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !localIsSingleDay
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'بازه زمانی',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !localIsSingleDay
                                      ? Colors.white
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  fontWeight: !localIsSingleDay
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (localIsSingleDay)
                    Center(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showCustomPersianDatePicker(
                            context: context,
                            initialDate: _startDateFilter ?? Jalali.now(),
                            firstDate: Jalali(1400),
                            lastDate: Jalali(1410),
                            title: 'انتخاب تاریخ',
                          );
                          if (picked != null) {
                            // Only update local variables and trigger setModalState for UI
                            // The final setState will happen on 'اعمال فیلتر' or implicitly
                            setModalState(() {
                              _startDateFilter = picked;
                              _endDateFilter = picked;
                            });
                          }
                        },
                        child: _buildDateBox(
                          'تاریخ انتخابی',
                          _startDateFilter,
                          isSingleDay: true,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showCustomPersianDatePicker(
                                context: context,
                                initialDate: _startDateFilter ?? Jalali.now(),
                                firstDate: Jalali(1400),
                                lastDate: Jalali(1410),
                                title: 'تاریخ شروع بازه',
                                rangeStart: _endDateFilter,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  _startDateFilter = picked;
                                });
                              }
                            },
                            child: _buildDateBox('از تاریخ', _startDateFilter),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showCustomPersianDatePicker(
                                context: context,
                                initialDate:
                                    _endDateFilter ??
                                    _startDateFilter ??
                                    Jalali.now(),
                                firstDate: _startDateFilter ?? Jalali(1400),
                                lastDate: Jalali(1410),
                                title: 'تاریخ پایان بازه',
                                rangeStart: _startDateFilter,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  _endDateFilter = picked;
                                });
                              }
                            },
                            child: _buildDateBox('تا تاریخ', _endDateFilter),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                        _clearSearchFocus();
                      },
                      child: const Text('اعمال فیلتر'),
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

  Widget _buildDateBox(String label, Jalali? date, {bool isSingleDay = false}) {
    return Container(
      width: isSingleDay ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: date != null
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date != null
                ? date.formatJalaliCompact().toPersianNumbers()
                : 'انتخاب کنید',
            style: TextStyle(
              fontSize: 14,
              fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
              color: date != null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 100,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'هنوز رویدادی ثبت نکرده‌اید',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    ExpenseProvider provider,
    event,
    eventData,
    SettingsProvider settings,
  ) {
    final participantCount = eventData.participants.length;
    final expenseCount = eventData.expenses.length;
    final totalAmount = eventData.expenses.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );

    // محاسبه وضعیت تسویه کل برنامه
    final debts = provider.calculateDebtsForEvent(event.id);
    final allSettled = debts.isEmpty || debts.every((d) => d.isSettled);
    final hasPendingDebts = !allSettled && debts.isNotEmpty;

    // پیدا کردن شرکت‌کنندگان منطبق با جستجو (اگر حالت جستجوی شرکت‌کننده فعال باشد)
    List<Participant> matchingParticipants = [];
    if (_searchByParticipant && _searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      matchingParticipants = eventData.participants
          .where((Participant p) => p.name.toLowerCase().contains(query))
          .toList();
    }

    return _HoverEventCard(
      onTap: () => _navigateToEventDetail(context, event.id),
      onLongPress: () => _showDeleteEventDialog(context, provider, event),
      eventColor: event.color ?? Colors.blue,
      child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: Icon(event.icon ?? Icons.event, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatEventDate(event),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16), // اضافه کردن فاصله از فلش
                  if (hasPendingDebts || (allSettled && debts.isNotEmpty)) ...[
                    Tooltip(
                      message: allSettled
                          ? '✅ تمام تسویه‌ها انجام شده'
                          : '⏳ تسویه‌های در انتظار پرداخت',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: allSettled
                            ? const Icon(
                                Icons.task_alt_rounded,
                                size: 20,
                                color: Colors.white,
                              )
                            : _RotatingPendingIcon(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
              if (!settings.hideAmounts) ...[
                const Divider(height: 20, color: Colors.white38),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      'شرکت‌کنندگان',
                      participantCount.toString().toPersianNumbers(),
                      Icons.people,
                    ),
                    _buildStatItem(
                      context,
                      'هزینه‌ها',
                      expenseCount.toString().toPersianNumbers(),
                      Icons.receipt_long,
                    ),
                    _buildStatItem(
                      context,
                      'مجموع',
                      settings.formatAmount(totalAmount).toPersianNumbers(),
                      Icons.attach_money,
                    ),
                  ],
                ),
              ],
              if (matchingParticipants.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_search_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: matchingParticipants.map((p) {
                            final hasUnsettledDebt = debts.any(
                              (debt) =>
                                  debt.debtorId == p.id && !debt.isSettled,
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasUnsettledDebt
                                        ? Icons.pending_actions_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 12,
                                    color: hasUnsettledDebt
                                        ? Colors.redAccent.shade100
                                        : Colors.greenAccent.shade100,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.white),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  String _formatEventDate(dynamic event) {
    if (event.startDate == null) {
      final created = Jalali.fromDateTime(event.createdAt);
      return 'تاریخ ایجاد: ${created.formatJalaliCompact().toPersianNumbers()}';
    }

    final start = Jalali.fromDateTime(event.startDate!);
    final sb = StringBuffer();
    sb.write(start.formatJalaliCompact().toPersianNumbers());

    if (event.endDate != null) {
      final end = Jalali.fromDateTime(event.endDate!);
      sb.write(' تا ');
      sb.write(end.formatJalaliCompact().toPersianNumbers());
    }

    return sb.toString();
  }

  void _navigateToAddEvent(BuildContext context) {
    _pushWithoutSearchFocus(context, const AddEventScreen());
  }

  void _navigateToEventDetail(BuildContext context, String eventId) {
    _pushWithoutSearchFocus(context, EventDetailScreen(eventId: eventId));
  }

  void _showDeleteEventDialog(
    BuildContext context,
    ExpenseProvider provider,
    event,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: event.color ?? Colors.blue,
              child: Icon(event.icon ?? Icons.event, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                event.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: event.color ?? Colors.teal.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _pushWithoutSearchFocus(
                          context,
                          EditEventScreen(eventId: event.id),
                        );
                      },
                      child: const Text('ویرایش'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmationDialog(context, provider, event);
                      },
                      child: const Text('حذف'),
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
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    ExpenseProvider provider,
    event,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'تأیید حذف',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'رویداد "${event.name}" حذف شود؟',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تمام شرکت‌کنندگان و هزینه‌ها حذف خواهند شد',
                      style: TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('انصراف'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    provider.deleteEvent(event.id);
                    Navigator.pop(context);
                  },
                  child: const Text('حذف کن'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final ValueNotifier<int> _globalRotationTick = ValueNotifier<int>(0);
Timer? _globalRotationTimer;

void _ensureGlobalRotationTimer() {
  if (_globalRotationTimer != null) return;
  _globalRotationTimer = Timer.periodic(const Duration(seconds: 8), (_) {
    _globalRotationTick.value++;
  });
}

class _RotatingPendingIcon extends StatefulWidget {
  @override
  State<_RotatingPendingIcon> createState() => _RotatingPendingIconState();
}

class _RotatingPendingIconState extends State<_RotatingPendingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _ensureGlobalRotationTimer();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _globalRotationTick.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _globalRotationTick.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159,
          child: child,
        );
      },
      child: const Icon(
        Icons.pending_actions_rounded,
        size: 20,
        color: Colors.white,
      ),
    );
  }
}

class _AnimatedTitle extends StatefulWidget {
  const _AnimatedTitle();

  @override
  State<_AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<_AnimatedTitle>
    with TickerProviderStateMixin {
  late AnimationController _enterController;
  late AnimationController _exitController;
  late Animation<Offset> _enterSlide;
  late Animation<double> _enterFade;
  late Animation<Offset> _exitSlide;
  late Animation<double> _exitFade;

  int _currentIndex = 0;
  Timer? _holdTimer;
  bool _showingText = true;
  String _displayedText = '';
  int _charIndex = 0;
  Timer? _typewriterTimer;

  // لیست آیکون‌های رویدادها
  final List<IconData> _eventIcons = [
    Icons.forest,
    Icons.hiking,
    Icons.beach_access,
    Icons.flight,
    Icons.restaurant,
    Icons.celebration,
    Icons.sports_soccer,
    Icons.local_cafe,
  ];

  @override
  void initState() {
    super.initState();

    // کنترلر ورود: اسلاید از راست به مرکز
    _enterController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _enterSlide = Tween<Offset>(
      begin: const Offset(1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic));
    _enterFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeIn),
    );

    // کنترلر خروج: اسلاید از مرکز به چپ
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _exitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.2, 0.0),
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic));
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOut),
    );

    _startTypewriterAnimation();
  }

  void _startTypewriterAnimation() {
    const appName = 'دنگ چی';
    _displayedText = '';
    _charIndex = 0;
    _showingText = true;

    _typewriterTimer = Timer.periodic(
      const Duration(milliseconds: 150),
      (timer) {
        if (!mounted) { timer.cancel(); return; }
        if (_charIndex < appName.length) {
          setState(() {
            _displayedText = appName.substring(0, _charIndex + 1);
            _charIndex++;
          });
        } else {
          _typewriterTimer?.cancel();
          // بعد از تایپ کامل، مکث و سپس شروع نمایش آیکون‌ها
          Future.delayed(const Duration(seconds: 4), () {
            if (!mounted) return;
            setState(() {
              _showingText = false;
              _currentIndex = 0;
            });
            _showNextIcon();
          });
        }
      },
    );
  }

  void _showNextIcon() {
    if (!mounted) return;
    // ریست و شروع انیمیشن ورود
    _exitController.reset();
    _enterController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      // مکث برای نمایش آیکون
      _holdTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        // انیمیشن خروج به چپ
        _exitController.forward(from: 0.0).then((_) {
          if (!mounted) return;
          _currentIndex++;
          if (_currentIndex >= _eventIcons.length) {
            // همه آیکون‌ها نمایش داده شدند، برگرد به متن
            setState(() {
              _showingText = true;
              _currentIndex = 0;
            });
            _startTypewriterAnimation();
          } else {
            setState(() {});
            _showNextIcon();
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    _exitController.dispose();
    _holdTimer?.cancel();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showingText) {
      return Text(
        _displayedText,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    // نمایش آیکون با انیمیشن ورود/خروج همزمان
    return AnimatedBuilder(
      animation: Listenable.merge([_enterController, _exitController]),
      builder: (context, child) {
        // اگه خروج شروع شده، از اسلاید خروج استفاده کن
        final isExiting = _exitController.isAnimating || _exitController.value > 0;
        final slideAnim = isExiting ? _exitSlide : _enterSlide;
        final fadeAnim = isExiting ? _exitFade : _enterFade;

        return SlideTransition(
          position: slideAnim,
          child: FadeTransition(
            opacity: fadeAnim,
            child: child,
          ),
        );
      },
      child: Icon(
        _eventIcons[_currentIndex.clamp(0, _eventIcons.length - 1)],
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class _HoverEventCard extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Color eventColor;
  final Widget child;

  const _HoverEventCard({
    required this.onTap,
    required this.onLongPress,
    required this.eventColor,
    required this.child,
  });

  @override
  State<_HoverEventCard> createState() => _HoverEventCardState();
}

class _HoverEventCardState extends State<_HoverEventCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      widget.eventColor,
                      widget.eventColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: widget.child,
              ),
              if (_hovered)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
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
