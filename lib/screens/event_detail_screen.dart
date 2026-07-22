import 'dart:io'; // Add this
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/expense.dart';
import '../models/participant.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/jalali_extension.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/persian_date_picker.dart';
import 'add_participant_screen.dart';
import 'add_expense_screen.dart';
import 'edit_expense_screen.dart';
import 'edit_participant_screen.dart';
import 'add_event_screen.dart';
import 'result_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _participantSearchController =
      TextEditingController();
  final TextEditingController _expenseSearchController =
      TextEditingController();
  final FocusNode _participantSearchFocusNode = FocusNode();
  final FocusNode _expenseSearchFocusNode = FocusNode();
  final FocusNode _pageFocusNode = FocusNode();
  final ScrollController _participantScrollController = ScrollController();
  final ScrollController _expenseScrollController = ScrollController();
  bool _isDetailFabVisible = true;
  Set<String> _selectedPayerIds = {};
  String _searchQuery = '';
  String _participantSearchQuery = '';
  bool _isParticipantSelectionMode = false;
  Set<String> _selectedParticipantIds = {};
  bool _isExpenseSelectionMode = false;
  Set<String> _selectedExpenseIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      _clearFocus();
      _updateDetailFabVisibility();
    });

    _participantSearchController.addListener(() {
      setState(() {
        _participantSearchQuery = _participantSearchController.text;
      });
    });

    _expenseSearchController.addListener(() {
      setState(() {
        _searchQuery = _expenseSearchController.text;
      });
    });
  }

  void _updateDetailFabVisibility([double? offset]) {
    final activeScrollController = _tabController.index == 0
        ? _participantScrollController
        : _expenseScrollController;
    final activeOffset =
        offset ??
        (activeScrollController.hasClients
            ? activeScrollController.offset
            : 0.0);
    final shouldShow = activeOffset < 20;
    if (shouldShow != _isDetailFabVisible) {
      setState(() {
        _isDetailFabVisible = shouldShow;
      });
    }
  }

  void _updateDetailFabVisibilityFromNotification(
    ScrollNotification notification,
  ) {
    if (notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta;
      if (scrollDelta == null) {
        _updateDetailFabVisibility(notification.metrics.pixels);
      } else if (scrollDelta > 0) {
        _updateDetailFabVisibility(double.infinity);
      } else {
        _updateDetailFabVisibility(0);
      }
      return;
    }

    if (notification is ScrollEndNotification) {
      _updateDetailFabVisibility(notification.metrics.pixels);
    }
  }

  void _showDeleteSelectedParticipantsDialog(
    BuildContext context,
    ExpenseProvider provider,
    EventData eventData,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'حذف گروهی شرکت‌کنندگان',
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
              '${_selectedParticipantIds.length.toString().toPersianNumbers()} شرکت‌کننده حذف شوند؟',
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
                      'تمام هزینه‌های ثبت شده توسط این اشخاص نیز حذف خواهند شد و این عمل قابل بازگشت نیست',
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
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
                        for (final id in _selectedParticipantIds) {
                          provider.removeParticipantFromEvent(
                            widget.eventId,
                            id,
                          );
                        }
                        setState(() {
                          _selectedParticipantIds.clear();
                          _isParticipantSelectionMode = false;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('شرکت‌کنندگان انتخاب شده حذف شدند'),
                          ),
                        );
                      },
                      child: const Text('حذف کن'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteSelectedExpensesDialog(
    BuildContext context,
    ExpenseProvider provider,
    EventData eventData,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'حذف گروهی هزینه‌ها',
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
              '${_selectedExpenseIds.length.toString().toPersianNumbers()} هزینه حذف شود؟',
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
                      'این عمل قابل بازگشت نیست',
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
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
                        for (final id in _selectedExpenseIds) {
                          provider.removeExpenseFromEvent(widget.eventId, id);
                        }
                        setState(() {
                          _selectedExpenseIds.clear();
                          _isExpenseSelectionMode = false;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('هزینه‌های انتخاب شده حذف شدند'),
                          ),
                        );
                      },
                      child: const Text('حذف کن'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _clearFocus() {
    _participantSearchFocusNode.unfocus();
    _expenseSearchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    if (_pageFocusNode.canRequestFocus) {
      _pageFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _participantSearchController.dispose();
    _expenseSearchController.dispose();
    _participantSearchFocusNode.dispose();
    _expenseSearchFocusNode.dispose();
    _pageFocusNode.dispose();
    _participantScrollController.dispose();
    _expenseScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final eventData = provider.getEventData(widget.eventId);

    if (eventData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطا')),
        body: const Center(child: Text('رویداد یافت نشد')),
      );
    }

    final totalExpenses = eventData.expenses.fold<double>(
      0.0,
      (double sum, Expense e) => sum + e.amount,
    );
    final eventColor = eventData.event.color ?? Colors.teal;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          eventData.event.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: eventColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: eventData.participants.length < 2
                ? 'برای محاسبه حداقل ۲ شرکت‌کننده نیاز است'
                : 'محاسبه تسویه',
            onPressed: eventData.participants.length >= 2
                ? () {
                    _clearFocus();
                    _navigateToResults(context);
                  }
                : null,
            color: Colors.white,
            disabledColor: Colors.white.withOpacity(0.5),
          ),
          PopupMenuButton<String>(
            tooltip: 'گزینه‌های بیشتر',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              _clearFocus();
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEventScreen(
                      eventId: widget.eventId,
                      initialName: eventData.event.name,
                      initialColor: eventData.event.color,
                      initialIcon: eventData.event.icon,
                      initialStartDate: eventData.event.startDate,
                      initialEndDate: eventData.event.endDate,
                    ),
                  ),
                );
              } else if (value == 'delete') {
                _showDeleteEventDialog(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 10),
                    const Text('ویرایش رویداد'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('حذف رویداد', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Focus(
        focusNode: _pageFocusNode,
        child: Column(
          children: [
            // TabBar
            Container(
              color: eventColor,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people),
                      const SizedBox(height: 4),
                      const Text('شرکت‌کنندگان'),
                      Text(
                        eventData.participants.length
                            .toString()
                            .toPersianNumbers(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long),
                      const SizedBox(height: 4),
                      const Text('هزینه‌ها'),
                      Text(
                        settings.formatAmount(totalExpenses).toPersianNumbers(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // TabBar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildParticipantsTab(context, provider, eventData, settings),
                  _buildExpensesTab(context, provider, eventData, settings),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _EventDetailFAB(
        tabController: _tabController,
        eventColor: eventColor,
        isVisible: _isDetailFabVisible,
        isSelectionMode: _isParticipantSelectionMode || _isExpenseSelectionMode,
        hasParticipants: eventData.participants.isNotEmpty,
        onAddParticipant: () => _navigateToAddParticipant(context),
        onAddExpense: () => _navigateToAddExpense(context),
        onShowNoParticipantSnackbar: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ابتدا شرکت‌کننده اضافه کنید')),
          );
        },
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    EventData eventData,
  ) async {
    final eventColor = eventData.event.color ?? Colors.teal;
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
            final filteredParticipants = eventData.participants
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
                        'فیلتر بر اساس افراد',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() => _selectedPayerIds.clear());
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
                                final isSelected = _selectedPayerIds.contains(
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
                                        _selectedPayerIds.add(p.id);
                                      } else {
                                        _selectedPayerIds.remove(p.id);
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

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 36, color: Colors.white),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
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

  Widget _buildParticipantsTab(
    BuildContext context,
    ExpenseProvider provider,
    EventData eventData,
    SettingsProvider settings,
  ) {
    final allParticipants = eventData.participants;
    final filteredParticipants = _participantSearchQuery.isEmpty
        ? allParticipants
        : allParticipants
              .where(
                (p) => p.name.toLowerCase().contains(
                  _participantSearchQuery.toLowerCase(),
                ),
              )
              .toList();

    if (allParticipants.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'هنوز شرکت‌کننده‌ای اضافه نشده',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // فیلد جستجوی شرکت‌کننده
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _participantSearchController,
                  focusNode: _participantSearchFocusNode,
                  decoration: InputDecoration(
                    hintText: _isParticipantSelectionMode
                        ? 'انتخاب شرکت‌کننده‌ها'
                        : 'جستجوی شرکت‌کننده...',
                    prefixIcon: _participantSearchQuery.isEmpty
                        ? const Icon(Icons.search, size: 20)
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () =>
                                _participantSearchController.clear(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 20,
                            tooltip: 'پاک کردن متن جستجو',
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // فیلتر حذف گروهی شرکت‌کنندگان
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isParticipantSelectionMode = !_isParticipantSelectionMode;
                    if (!_isParticipantSelectionMode) {
                      _selectedParticipantIds.clear();
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isParticipantSelectionMode
                        ? Colors.red.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isParticipantSelectionMode
                          ? Colors.red.withOpacity(0.5)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Tooltip(
                    message: _isParticipantSelectionMode
                        ? 'خروج از حالت انتخاب'
                        : 'حذف گروهی',
                    child: Icon(
                      _isParticipantSelectionMode
                          ? Icons.close
                          : Icons.select_all,
                      size: 20,
                      color: _isParticipantSelectionMode
                          ? Colors.red
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              if (_isParticipantSelectionMode)
                Row(
                  children: [
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedParticipantIds = allParticipants
                              .map((p) => p.id)
                              .toSet();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Tooltip(
                          message: 'انتخاب همه',
                          child: const Icon(
                            Icons.check_box,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _selectedParticipantIds.isEmpty
                          ? null
                          : () => _showDeleteSelectedParticipantsDialog(
                              context,
                              provider,
                              eventData,
                            ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedParticipantIds.isEmpty
                              ? Colors.grey.withOpacity(0.1)
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedParticipantIds.isEmpty
                                ? Colors.grey.withOpacity(0.3)
                                : Colors.red.withOpacity(0.5),
                          ),
                        ),
                        child: Tooltip(
                          message: 'حذف انتخاب شده‌ها',
                          child: Icon(
                            Icons.delete,
                            size: 20,
                            color: _selectedParticipantIds.isEmpty
                                ? Colors.grey
                                : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: filteredParticipants.isEmpty
              ? const Center(
                  child: Text(
                    'شرکت‌کننده‌ای یافت نشد',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _updateDetailFabVisibilityFromNotification(notification);
                    return false;
                  },
                  child: ListView.builder(
                    controller: _participantScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredParticipants.length,
                    itemBuilder: (context, index) {
                      final participant = filteredParticipants[index];

                      // Calculate stats
                      final participantExpenses = eventData.expenses
                          .where((e) => e.payerId == participant.id)
                          .toList();
                      final expenseCount = participantExpenses.length;
                      final totalPaid = participantExpenses.fold<double>(
                        0.0,
                        (double sum, Expense e) => sum + e.amount,
                      );

                      final isInactive = eventData.expenses.every(
                        (e) =>
                            !e.involvedParticipantIds.contains(participant.id),
                      );

                      // Calculate if participant has unsettled debts
                      final debts = provider.calculateDebtsForEvent(
                        widget.eventId,
                      );
                      final hasUnsettledDebts = debts.any(
                        (debt) =>
                            debt.debtorId == participant.id && !debt.isSettled,
                      );

                      return _buildParticipantRow(
                        context,
                        provider,
                        participant,
                        expenseCount,
                        totalPaid,
                        settings,
                        isInactive: isInactive,
                        hasUnsettledDebts: hasUnsettledDebts,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildParticipantRow(
    BuildContext context,
    ExpenseProvider provider,
    participant,
    int expenseCount,
    double totalPaid,
    SettingsProvider settings, {
    bool isInactive = false,
    bool hasUnsettledDebts = false,
  }) {
    final isSelected = _selectedParticipantIds.contains(participant.id);
    return Opacity(
      opacity: isInactive ? 0.55 : 1.0,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () {
            if (_isParticipantSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedParticipantIds.remove(participant.id);
                  if (_selectedParticipantIds.isEmpty) {
                    _isParticipantSelectionMode = false;
                  }
                } else {
                  _selectedParticipantIds.add(participant.id);
                }
              });
            } else {
              _showParticipantOptions(context, provider, settings, participant);
            }
          },
          onLongPress: () {
            if (!_isParticipantSelectionMode) {
              setState(() {
                _isParticipantSelectionMode = true;
                _selectedParticipantIds.add(participant.id);
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (_isParticipantSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedParticipantIds.add(participant.id);
                          } else {
                            _selectedParticipantIds.remove(participant.id);
                            if (_selectedParticipantIds.isEmpty) {
                              _isParticipantSelectionMode = false;
                            }
                          }
                        });
                      },
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: hasUnsettledDebts
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    child: Icon(
                      hasUnsettledDebts
                          ? Icons.pending_actions_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 28,
                      color: hasUnsettledDebts ? Colors.red : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
                      Text(
                        '$expenseCount تراکنش'.toPersianNumbers(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isParticipantSelectionMode)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'مجموع پرداختی',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        settings.formatAmount(totalPaid).toPersianNumbers(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesTab(
    BuildContext context,
    ExpenseProvider provider,
    EventData eventData,
    SettingsProvider settings,
  ) {
    final List<Expense> allExpenses = eventData.expenses;
    final List<Expense> filteredByPayer = _selectedPayerIds.isEmpty
        ? allExpenses
        : allExpenses
              .where((Expense e) => _selectedPayerIds.contains(e.payerId))
              .toList();
    final List<Expense> filteredExpenses = _searchQuery.isEmpty
        ? filteredByPayer
        : filteredByPayer
              .where(
                (Expense e) =>
                    e.title.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    if (allExpenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'هنوز هزینه‌ای ثبت نشده',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final eventColor = eventData.event.color ?? Colors.teal;

    return Column(
      children: [
        // ردیف فیلتر و جستجو ادغام شده
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // فیلد جستجو
              Expanded(
                child: TextField(
                  controller: _expenseSearchController,
                  focusNode: _expenseSearchFocusNode,
                  decoration: InputDecoration(
                    hintText: _isExpenseSelectionMode
                        ? 'انتخاب هزینه‌ها'
                        : 'جستجوی هزینه...',
                    prefixIcon: _searchQuery.isEmpty
                        ? const Icon(Icons.search, size: 20)
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _expenseSearchController.clear(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 20,
                            tooltip: 'پاک کردن متن جستجو',
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // دکمه فیلتر مدرن (only show when not in selection mode)
              if (!_isExpenseSelectionMode)
                GestureDetector(
                  onTap: () async {
                    _clearFocus();
                    await _showFilterSheet(context, eventData);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedPayerIds.isEmpty
                          ? Colors.grey.withOpacity(0.1)
                          : eventColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedPayerIds.isEmpty
                            ? Colors.grey.withOpacity(0.3)
                            : eventColor.withOpacity(0.5),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Icon(
                          _selectedPayerIds.isEmpty
                              ? Icons.filter_list
                              : Icons.filter_alt,
                          size: 20,
                          color: _selectedPayerIds.isEmpty
                              ? Colors.grey[700]
                              : eventColor,
                        ),
                        if (_selectedPayerIds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${_selectedPayerIds.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // فیلتر حذف گروهی هزینه‌ها
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpenseSelectionMode = !_isExpenseSelectionMode;
                    if (!_isExpenseSelectionMode) {
                      _selectedExpenseIds.clear();
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isExpenseSelectionMode
                        ? Colors.red.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isExpenseSelectionMode
                          ? Colors.red.withOpacity(0.5)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Tooltip(
                    message: _isExpenseSelectionMode
                        ? 'خروج از حالت انتخاب'
                        : 'حذف گروهی',
                    child: Icon(
                      _isExpenseSelectionMode ? Icons.close : Icons.select_all,
                      size: 20,
                      color: _isExpenseSelectionMode
                          ? Colors.red
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              if (_isExpenseSelectionMode)
                Row(
                  children: [
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedExpenseIds = filteredExpenses
                              .map((e) => e.id)
                              .toSet();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Tooltip(
                          message: 'انتخاب همه',
                          child: const Icon(
                            Icons.check_box,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _selectedExpenseIds.isEmpty
                          ? null
                          : () => _showDeleteSelectedExpensesDialog(
                              context,
                              provider,
                              eventData,
                            ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedExpenseIds.isEmpty
                              ? Colors.grey.withOpacity(0.1)
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedExpenseIds.isEmpty
                                ? Colors.grey.withOpacity(0.3)
                                : Colors.red.withOpacity(0.5),
                          ),
                        ),
                        child: Tooltip(
                          message: 'حذف انتخاب شده‌ها',
                          child: Icon(
                            Icons.delete,
                            size: 20,
                            color: _selectedExpenseIds.isEmpty
                                ? Colors.grey
                                : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              // پاک کردن فیلتر (only show when not in selection mode)
              if (!_isExpenseSelectionMode && _selectedPayerIds.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _selectedPayerIds.clear()),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.5),
                      ),
                    ),
                    child: const Tooltip(
                      message: 'پاک کردن فیلتر',
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: filteredExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'هزینه‌ای با این فیلتر یافت نشد',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _updateDetailFabVisibilityFromNotification(notification);
                    return false;
                  },
                  child: ListView.builder(
                    controller: _expenseScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = filteredExpenses[index];

                      // Find payer safely
                      final payer = eventData.participants.firstWhere(
                        (p) => p.id == expense.payerId,
                        orElse: () => Participant(id: '', name: 'نامشخص'),
                      );

                      return _buildExpenseCard(
                        context,
                        provider,
                        expense,
                        payer,
                        settings,
                        eventData.participants,
                        eventColor,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    ExpenseProvider provider,
    expense,
    payer,
    SettingsProvider settings,
    List participants,
    Color eventColor,
  ) {
    final isSelected = _selectedExpenseIds.contains(expense.id);
    final allParticipantsInvolved =
        expense.involvedParticipantIds.length == participants.length;
    // Format date if available
    String? dateStr;
    if (expense.date != null) {
      final jalali = Jalali.fromDateTime(expense.date!);
      dateStr = jalali.formatJalaliCompact().toPersianNumbers();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (_isExpenseSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedExpenseIds.remove(expense.id);
                if (_selectedExpenseIds.isEmpty) {
                  _isExpenseSelectionMode = false;
                }
              } else {
                _selectedExpenseIds.add(expense.id);
              }
            });
          } else {
            _showExpenseOptions(context, provider, expense);
          }
        },
        onLongPress: () {
          if (!_isExpenseSelectionMode) {
            setState(() {
              _isExpenseSelectionMode = true;
              _selectedExpenseIds.add(expense.id);
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isExpenseSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedExpenseIds.add(expense.id);
                        } else {
                          _selectedExpenseIds.remove(expense.id);
                          if (_selectedExpenseIds.isEmpty) {
                            _isExpenseSelectionMode = false;
                          }
                        }
                      });
                    },
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Icon, Title and Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  expense.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          settings
                              .formatAmount(expense.amount)
                              .toPersianNumbers(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Row 2: Payer and Date (Compact Metadata)
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            payer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        if (dateStr != null) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        if (expense.receiptPath != null &&
                            !_isExpenseSelectionMode) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _showReceiptImage(
                              context,
                              expense.receiptPath!,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.image,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'مشاهده رسید',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Row 3: Description (if exists)
                    if (expense.description != null &&
                        expense.description!.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(height: 1, thickness: 0.5),
                      ),
                      Text(
                        expense.description!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCardNumber(String cardNumber) {
    if (cardNumber.isEmpty) return '';
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
      const lrm = '\u200E';
      return '$lrm${buffer.toString().toPersianNumbers()}$lrm';
    } catch (e) {
      return cardNumber;
    }
  }

  void _showParticipantOptions(
    BuildContext context,
    ExpenseProvider provider,
    SettingsProvider settings,
    Participant participant,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          final eventData = provider.getEventData(widget.eventId);
          final hasExpenses =
              eventData?.expenses.any((e) => e.payerId == participant.id) ??
              false;
          final debts = provider.calculateDebtsForEvent(widget.eventId);
          final hasUnsettledDebts = debts.any(
            (debt) => debt.debtorId == participant.id && !debt.isSettled,
          );
          final hasParticipantDebts = debts.any(
            (debt) => debt.debtorId == participant.id,
          );

          return AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasUnsettledDebts
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  child: Icon(
                    hasUnsettledDebts
                        ? Icons.pending_actions_rounded
                        : Icons.check_circle_outline_rounded,
                    color: hasUnsettledDebts ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    participant.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (participant.bankCardNumber != null &&
                    participant.bankCardNumber!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'شماره کارت:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatCardNumber(
                                      participant.bankCardNumber!,
                                    ),
                                    textAlign: TextAlign.center,
                                    textDirection: ui.TextDirection.ltr,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('کپی شماره کارت'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('شماره کارت کپی شد'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  // کپی کردن شماره کارت بدون فاصله‌ها
                                  final clipboard = participant.bankCardNumber!;
                                  final data = ClipboardData(text: clipboard);
                                  Clipboard.setData(data);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: hasParticipantDebts
                          ? () async {
                              final debts = provider.calculateDebtsForEvent(
                                widget.eventId,
                              );
                              final participantDebts = debts
                                  .where((d) => d.debtorId == participant.id)
                                  .toList();

                              if (participantDebts.isEmpty) return;

                              _showDebtSelectionDialog(
                                context,
                                provider,
                                settings,
                                participant,
                                participantDebts,
                              );
                            }
                          : null,
                      icon: Icon(
                        hasParticipantDebts
                            ? (hasUnsettledDebts
                                  ? Icons.pending_actions_rounded
                                  : Icons.check_circle_outline_rounded)
                            : Icons.check_circle_outline,
                        size: 18,
                        color: hasParticipantDebts
                            ? (hasUnsettledDebts ? Colors.red : Colors.green)
                            : Colors.grey,
                      ),
                      label: Text(
                        'تسویه حساب',
                        style: TextStyle(
                          color: hasParticipantDebts
                              ? (hasUnsettledDebts ? Colors.red : Colors.green)
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: hasExpenses
                          ? () {
                              Navigator.pop(context);
                              setState(() {
                                _selectedPayerIds = {participant.id};
                              });
                              _tabController.animateTo(1);
                            }
                          : null,
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('مشاهده هزینه‌ها'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditParticipantScreen(
                                  eventId: widget.eventId,
                                  participantId: participant.id,
                                  participantName: participant.name,
                                  bankCardNumber: participant.bankCardNumber,
                                ),
                              ),
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
                            final eventData = provider.getEventData(
                              widget.eventId,
                            );
                            final participantExpenses =
                                eventData?.expenses
                                    .where((e) => e.payerId == participant.id)
                                    .toList() ??
                                [];

                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (ctx) {
                                final selectedExpenseIds = <String>{
                                  for (var expense in participantExpenses)
                                    expense.id,
                                };
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Row(
                                    children: [
                                      Icon(
                                        Icons.warning_rounded,
                                        color: Colors.red,
                                        size: 28,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'حذف شرکت‌کننده',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'شرکت‌کننده "${participant.name}" حذف شود؟',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (participantExpenses.isNotEmpty) ...[
                                        const Text(
                                          'هزینه‌های ثبت شده:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(
                                              0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.withOpacity(
                                                0.2,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              ...participantExpenses.map((
                                                expense,
                                              ) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.receipt_long,
                                                        size: 18,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              expense.title,
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                            Text(
                                                              settings
                                                                  .formatAmount(
                                                                    expense
                                                                        .amount,
                                                                  )
                                                                  .toPersianNumbers(),
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.info_outline,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                participantExpenses.isNotEmpty
                                                    ? 'تمام هزینه‌های ثبت شده توسط این شخص نیز حذف خواهد شد و این عمل قابل بازگشت نیست'
                                                    : 'این عمل قابل بازگشت نیست',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actionsPadding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  actions: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
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
                                                  // First, delete selected expenses
                                                  for (var expenseId
                                                      in selectedExpenseIds) {
                                                    provider
                                                        .removeExpenseFromEvent(
                                                          widget.eventId,
                                                          expenseId,
                                                        );
                                                  }
                                                  // Then delete the participant
                                                  provider
                                                      .removeParticipantFromEvent(
                                                        widget.eventId,
                                                        participant.id,
                                                      );
                                                  Navigator.pop(ctx);
                                                },
                                                child: const Text('حذف کن'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
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
          );
        },
      ),
    );
  }

  Future<void> _showSettlementDialog(
    BuildContext context,
    ExpenseProvider provider,
    SettingsProvider settings,
    dynamic debt, {
    Participant? participant,
    bool isEditing = false,
  }) {
    final controller = TextEditingController(
      text: isEditing ? debt.settlementDescription : '',
    );
    Jalali? selectedSettlementDate;
    TimeOfDay? selectedSettlementTime;
    final eventData = provider.getEventData(widget.eventId);
    Participant? creditor;
    for (final participant
        in eventData?.participants ?? const <Participant>[]) {
      if (participant.id == debt.creditorId) {
        creditor = participant;
        break;
      }
    }
    final creditorCardNumber = creditor?.bankCardNumber;
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
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
                                _formatCardNumber(creditorCardNumber!),
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
                              ClipboardData(text: creditorCardNumber!),
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
                        if (selectedSettlementDate != null ||
                            selectedSettlementTime != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setDialogState(() {
                                  selectedSettlementDate = null;
                                  selectedSettlementTime = null;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ردیف ساعت
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          final now = TimeOfDay.now();
                          // مقدار اولیه رو از همون ابتدا set کن تا اگه کاربر چیزی نچرخوند هم ساعت ذخیره بشه
                          TimeOfDay tempTime = selectedSettlementTime ?? now;
                          setDialogState(() {
                            selectedSettlementTime = tempTime;
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
                                    tempTime.hour,
                                    tempTime.minute,
                                  ),
                                  use24hFormat: true,
                                  onDateTimeChanged: (dateTime) {
                                    tempTime = TimeOfDay(
                                      hour: dateTime.hour,
                                      minute: dateTime.minute,
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('انصراف'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedSettlementTime = tempTime;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: const Text('تایید'),
                                ),
                              ],
                            ),
                          );
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
                                Navigator.pop(context);
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
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
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

  void _showDebtSelectionDialog(
    BuildContext context,
    ExpenseProvider provider,
    SettingsProvider settings,
    Participant participant,
    List<Debt> debts,
  ) {
    final unsettledTotalDebt = debts
        .where((debt) => !debt.isSettled)
        .fold<double>(0, (sum, debt) => sum + debt.amount);
    final isFullySettled = unsettledTotalDebt == 0;
    final hasSettledDebt = debts.any((debt) => debt.isSettled);
    final totalDebtTitle = hasSettledDebt ? 'باقی مانده بدهی' : 'جمع کل بدهی';
    final totalDebtColor = isFullySettled ? Colors.green : Colors.red;
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تسویه حساب'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...debts.map((debt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await _showSettlementDialog(
                        parentContext,
                        provider,
                        settings,
                        debt,
                        participant: participant,
                        isEditing: debt.isSettled,
                      );
                      if (!parentContext.mounted) return;

                      final updatedDebts = provider
                          .calculateDebtsForEvent(widget.eventId)
                          .where((debt) => debt.debtorId == participant.id)
                          .toList();
                      if (updatedDebts.isNotEmpty) {
                        _showDebtSelectionDialog(
                          parentContext,
                          provider,
                          settings,
                          participant,
                          updatedDebts,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                debt.isSettled
                                    ? Icons.check_circle_outline
                                    : Icons.pending_actions_rounded,
                                color: debt.isSettled
                                    ? Colors.green
                                    : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  debt.creditorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet,
                                size: 20,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                settings
                                    .formatAmount(debt.amount)
                                    .toPersianNumbers(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
              if (debts.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: totalDebtColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: totalDebtColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: totalDebtColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              totalDebtTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: totalDebtColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            settings
                                .formatAmount(unsettledTotalDebt)
                                .toPersianNumbers(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: totalDebtColor,
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
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              label: const Text('بستن'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditParticipantDialog(
    BuildContext context,
    ExpenseProvider provider,
    participant,
  ) {
    final controller = TextEditingController(text: participant.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ویرایش نام'),
        content: TextField(
          controller: controller,
          maxLength: 25,
          decoration: const InputDecoration(
            labelText: 'نام شرکت‌کننده',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                if (name.length > 25) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('نام نمی‌تواند بیش از 25 کاراکتر باشد'),
                    ),
                  );
                  return;
                }
                provider.updateParticipant(
                  eventId: widget.eventId,
                  participantId: participant.id,
                  name: name,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _showExpenseOptions(
    BuildContext context,
    ExpenseProvider provider,
    expense,
  ) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final eventData = provider.getEventData(widget.eventId);

    // Find payer info
    final payer =
        eventData?.participants.firstWhere(
          (p) => p.id == expense.payerId,
          orElse: () => Participant(id: '', name: 'نامشخص'),
        ) ??
        Participant(id: '', name: 'نامشخص');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.2),
              child: Icon(
                Icons.receipt_long,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                expense.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (payer.name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            payer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.payments,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        settings
                            .formatAmount(expense.amount)
                            .toPersianNumbers(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
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
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditExpenseScreen(
                              eventId: widget.eventId,
                              expenseId: expense.id,
                            ),
                          ),
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
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: Colors.red,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'حذف هزینه',
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
                                  'هزینه "${expense.title}" حذف شود؟',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'این عمل قابل بازگشت نیست',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actionsPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            actions: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(ctx),
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
                                        provider.removeExpenseFromEvent(
                                          widget.eventId,
                                          expense.id,
                                        );
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('حذف کن'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
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

  void _navigateToAddParticipant(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddParticipantScreen(eventId: widget.eventId),
      ),
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(eventId: widget.eventId),
      ),
    );
  }

  void _navigateToResults(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(eventId: widget.eventId),
      ),
    );
  }

  void _showDeleteEventDialog(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final eventData = provider.getEventData(widget.eventId);

    if (eventData == null) return;

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
                'حذف رویداد',
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
              'رویداد "${eventData.event.name}" حذف شود؟',
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                        provider.deleteEvent(widget.eventId);
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text('حذف کن'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReceiptImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('تصویر رسید'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                // Allow scrolling if image is tall
                child: kIsWeb
                    ? Image.network(path, fit: BoxFit.contain)
                    : Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small, self-contained FAB that listens to tab changes and rebuilds
/// only itself — avoiding a full-screen rebuild on every tab switch.
class _EventDetailFAB extends StatefulWidget {
  final TabController tabController;
  final Color eventColor;
  final bool isSelectionMode;
  final bool isVisible;
  final bool hasParticipants;
  final VoidCallback onAddParticipant;
  final VoidCallback onAddExpense;
  final VoidCallback onShowNoParticipantSnackbar;

  const _EventDetailFAB({
    required this.tabController,
    required this.eventColor,
    required this.isSelectionMode,
    required this.isVisible,
    required this.hasParticipants,
    required this.onAddParticipant,
    required this.onAddExpense,
    required this.onShowNoParticipantSnackbar,
  });

  @override
  State<_EventDetailFAB> createState() => _EventDetailFABState();
}

class _EventDetailFABState extends State<_EventDetailFAB> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSelectionMode || !widget.isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: widget.tabController.animation!,
      builder: (context, child) {
        final isParticipantsTab =
            widget.tabController.animation!.value.round() == 0;
        return Material(
          color: widget.eventColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          elevation: 6,
          child: InkWell(
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            onTap: () {
              if (isParticipantsTab) {
                widget.onAddParticipant();
              } else if (widget.hasParticipants) {
                widget.onAddExpense();
              } else {
                widget.onShowNoParticipantSnackbar();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    isParticipantsTab ? 'افزودن شرکت‌کننده' : 'افزودن هزینه',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
