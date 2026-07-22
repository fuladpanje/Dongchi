import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../models/participant.dart';
import '../models/expense.dart';

// مدل برای نمایش بدهی‌ها
class Debt {
  final String debtorName; // بدهکار
  final String creditorName; // طلبکار
  final String debtorId;
  final String creditorId;
  final double amount; // مبلغ
  final String? creditorCardNumber; // شماره کارت طلبکار
  final String? debtorCardNumber; // شماره کارت بدهکار
  bool isSettled; // آیا تسویه شده است
  String? settlementDescription; // توضیحات تسویه
  DateTime? settlementDate; // تاریخ تسویه

  Debt({
    required this.debtorName,
    required this.creditorName,
    required this.debtorId,
    required this.creditorId,
    required this.amount,
    this.creditorCardNumber,
    this.debtorCardNumber,
    this.isSettled = false,
    this.settlementDescription,
    this.settlementDate,
  });
}

// داده‌های کامل یک رویداد
class EventData {
  final Event event;
  final List<Participant> participants;
  final List<Expense> expenses;

  EventData({
    required this.event,
    required this.participants,
    required this.expenses,
  });

  Map<String, dynamic> toJson() {
    return {
      'event': event.toJson(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
    };
  }

  factory EventData.fromJson(Map<String, dynamic> json) {
    return EventData(
      event: Event.fromJson(json['event']),
      participants: (json['participants'] as List)
          .map((p) => Participant.fromJson(p))
          .toList(),
      expenses: (json['expenses'] as List)
          .map((e) => Expense.fromJson(e))
          .toList(),
    );
  }
}

// Provider برای مدیریت وضعیت برنامه
class ExpenseProvider with ChangeNotifier {
  final Map<String, EventData> _events = {}; // eventId -> EventData
  final Map<String, bool> _settledDebts = {}; // debtKey -> isSettled
  final Map<String, String> _settlementDescriptions =
      {}; // debtKey -> description
  final Map<String, String> _settlementDates =
      {}; // debtKey -> iso8601 string date
  final Uuid _uuid = const Uuid();
  bool _isLoading = false;

  Map<String, EventData> get events => Map.unmodifiable(_events);
  bool get isLoading => _isLoading;

  List<Event> get eventsList =>
      _events.values.map((e) => e.event).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // بارگذاری داده‌ها از حافظه محلی
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString('events');

      _events.clear();
      if (eventsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(eventsJson);
        decoded.forEach((key, value) {
          _events[key] = EventData.fromJson(value);
        });
      }

      // بارگذاری وضعیت تسویه‌ها
      final settledDebtsJson = prefs.getString('settledDebts');
      _settledDebts.clear();
      if (settledDebtsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(settledDebtsJson);
        decoded.forEach((key, value) {
          _settledDebts[key] = value as bool;
        });
      }

      // بارگذاری توضیحات تسویه‌ها
      final descriptionsJson = prefs.getString('settlementDescriptions');
      _settlementDescriptions.clear();
      if (descriptionsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(descriptionsJson);
        decoded.forEach((key, value) {
          _settlementDescriptions[key] = value as String;
        });
      }

      // بارگذاری تاریخ تسویه‌ها
      final datesJson = prefs.getString('settlementDates');
      _settlementDates.clear();
      if (datesJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(datesJson);
        decoded.forEach((key, value) {
          _settlementDates[key] = value as String;
        });
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ذخیره داده‌ها در حافظه محلی
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsMap = <String, dynamic>{};
    _events.forEach((key, value) {
      eventsMap[key] = value.toJson();
    });
    await prefs.setString('events', jsonEncode(eventsMap));
    await prefs.setString('settledDebts', jsonEncode(_settledDebts));
    await prefs.setString(
      'settlementDescriptions',
      jsonEncode(_settlementDescriptions),
    );
    await prefs.setString('settlementDates', jsonEncode(_settlementDates));
  }

  // افزودن رویداد جدید
  Future<void> addEvent(String name) async {
    if (name.trim().isEmpty) return;

    final event = Event(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );

    _events[event.id] = EventData(event: event, participants: [], expenses: []);

    await _saveData();
    notifyListeners();
  }

  // حذف رویداد
  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
    await _saveData();
    notifyListeners();
  }

  // ویرایش رویداد
  Future<void> updateEvent({
    required String eventId,
    required String name,
    DateTime? startDate,
    DateTime? endDate,
    Color? color,
    IconData? icon,
  }) async {
    if (!_events.containsKey(eventId) || name.trim().isEmpty) return;

    final eventData = _events[eventId]!;
    _events[eventId] = EventData(
      event: Event(
        id: eventData.event.id,
        name: name.trim(),
        createdAt: eventData.event.createdAt,
        startDate: startDate,
        endDate: endDate,
        color: color,
        iconCodePoint: icon?.codePoint,
      ),
      participants: eventData.participants,
      expenses: eventData.expenses,
    );

    await _saveData();
    notifyListeners();
  }

  // افزودن شرکت‌کننده به رویداد
  Future<void> addParticipantToEvent(
    String eventId,
    String name, {
    String? bankCardNumber,
  }) async {
    if (name.trim().isEmpty || !_events.containsKey(eventId)) return;

    final participant = Participant(
      id: _uuid.v4(),
      name: name.trim(),
      bankCardNumber: bankCardNumber,
    );

    final eventData = _events[eventId]!;
    _events[eventId] = EventData(
      event: eventData.event,
      participants: [...eventData.participants, participant],
      expenses: eventData.expenses,
    );

    await _saveData();
    notifyListeners();
  }

  Future<void> addParticipantIdToAllEqualExpenses(
    String eventId,
    String participantId,
  ) async {
    if (!_events.containsKey(eventId)) return;
    final eventData = _events[eventId]!;

    final updatedExpenses = eventData.expenses.map((e) {
      if (e.splitType == 'equal') {
        if (e.involvedParticipantIds.contains(participantId)) return e;
        return Expense(
          id: e.id,
          title: e.title,
          amount: e.amount,
          payerId: e.payerId,
          involvedParticipantIds: [...e.involvedParticipantIds, participantId],
          customWeights: e.customWeights,
          splitType: e.splitType,
          date: e.date,
          description: e.description,
          receiptPath: e.receiptPath,
          iconCodePoint: e.iconCodePoint,
        );
      }
      return e;
    }).toList();

    _events[eventId] = EventData(
      event: eventData.event,
      participants: eventData.participants,
      expenses: updatedExpenses,
    );

    await _saveData();
    notifyListeners();
  }

  Future<void> addParticipantToSingleExpense(
    String eventId,
    String expenseId,
    String participantId,
  ) async {
    if (!_events.containsKey(eventId)) return;
    final eventData = _events[eventId]!;

    final updatedExpenses = eventData.expenses.map((e) {
      if (e.id == expenseId) {
        if (e.involvedParticipantIds.contains(participantId)) return e;
        return Expense(
          id: e.id,
          title: e.title,
          amount: e.amount,
          payerId: e.payerId,
          involvedParticipantIds: [...e.involvedParticipantIds, participantId],
          customWeights: e.customWeights,
          splitType: e.splitType,
          date: e.date,
          description: e.description,
          receiptPath: e.receiptPath,
          iconCodePoint: e.iconCodePoint,
        );
      }
      return e;
    }).toList();

    _events[eventId] = EventData(
      event: eventData.event,
      participants: eventData.participants,
      expenses: updatedExpenses,
    );

    await _saveData();
    notifyListeners();
  }

  // حذف شرکت‌کننده از رویداد
  Future<void> removeParticipantFromEvent(
    String eventId,
    String participantId,
  ) async {
    if (!_events.containsKey(eventId)) return;

    final eventData = _events[eventId]!;
    final updatedExpenses = eventData.expenses.map((e) {
      final newInvolved = e.involvedParticipantIds
          .where((id) => id != participantId)
          .toList();
      final newWeights = e.customWeights != null
          ? Map<String, double>.from(e.customWeights!)
          : null;
      if (newWeights != null) {
        newWeights.remove(participantId);
      }
      if (newInvolved.length == e.involvedParticipantIds.length &&
          newWeights == e.customWeights) {
        return e;
      }
      return Expense(
        id: e.id,
        title: e.title,
        amount: e.amount,
        payerId: e.payerId,
        involvedParticipantIds: newInvolved,
        customWeights: newWeights,
        splitType: e.splitType,
        date: e.date,
        description: e.description,
        receiptPath: e.receiptPath,
        iconCodePoint: e.iconCodePoint,
      );
    }).toList();

    _events[eventId] = EventData(
      event: eventData.event,
      participants: eventData.participants
          .where((p) => p.id != participantId)
          .toList(),
      expenses: updatedExpenses,
    );

    await _saveData();
    notifyListeners();
  }

  // افزودن هزینه به رویداد
  Future<void> addExpenseToEvent({
    required String eventId,
    required String title,
    required double amount,
    required String payerId,
    List<String> involvedParticipantIds = const [],
    Map<String, double>? customWeights,
    String splitType = 'equal',
    DateTime? date,
    String? description,
    String? receiptPath,
  }) async {
    if (title.trim().isEmpty || amount <= 0 || !_events.containsKey(eventId)) {
      return;
    }

    final expense = Expense(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount,
      payerId: payerId,
      involvedParticipantIds: involvedParticipantIds,
      customWeights: customWeights,
      splitType: splitType,
      date: date,
      description: description,
      receiptPath: receiptPath,
    );

    final eventData = _events[eventId]!;
    _events[eventId] = EventData(
      event: eventData.event,
      participants: eventData.participants,
      expenses: [...eventData.expenses, expense],
    );

    await _saveData();
    notifyListeners();
  }

  // حذف هزینه از رویداد
  Future<void> removeExpenseFromEvent(String eventId, String expenseId) async {
    if (!_events.containsKey(eventId)) return;

    final eventData = _events[eventId]!;
    _events[eventId] = EventData(
      event: eventData.event,
      participants: eventData.participants,
      expenses: eventData.expenses.where((e) => e.id != expenseId).toList(),
    );

    await _saveData();
    notifyListeners();
  }

  // ویرایش هزینه
  Future<void> updateExpense({
    required String eventId,
    required String expenseId,
    required String title,
    required double amount,
    required String payerId,
    List<String> involvedParticipantIds = const [],
    Map<String, double>? customWeights,
    String splitType = 'equal',
    DateTime? date,
    String? description,
    String? receiptPath,
  }) async {
    if (!_events.containsKey(eventId) || title.trim().isEmpty || amount <= 0)
      return;

    final eventData = _events[eventId]!;

    final updatedExpenses = eventData.expenses.map((e) {
      if (e.id == expenseId) {
        return Expense(
          id: e.id,
          title: title.trim(),
          amount: amount,
          payerId: payerId,
          involvedParticipantIds: involvedParticipantIds,
          customWeights: customWeights,
          splitType: splitType,
          date: date,
          description: description,
          receiptPath: receiptPath,
        );
      }
      return e;
    }).toList();

    _events[eventId] = EventData(
      event: eventData.event,
      participants: eventData.participants,
      expenses: updatedExpenses,
    );

    await _saveData();
    notifyListeners();
  }

  // ویرایش شرکت‌کننده
  Future<void> updateParticipant({
    required String eventId,
    required String participantId,
    required String name,
    String? bankCardNumber,
  }) async {
    if (!_events.containsKey(eventId) || name.trim().isEmpty) return;

    final eventData = _events[eventId]!;
    final updatedParticipants = eventData.participants.map((p) {
      if (p.id == participantId) {
        return Participant(
          id: p.id,
          name: name.trim(),
          bankCardNumber: bankCardNumber,
        );
      }
      return p;
    }).toList();

    _events[eventId] = EventData(
      event: eventData.event,
      participants: updatedParticipants,
      expenses: eventData.expenses,
    );

    await _saveData();
    notifyListeners();
  }

  // دریافت داده‌های یک رویداد
  EventData? getEventData(String eventId) {
    return _events[eventId];
  }

  // به‌روزرسانی وضعیت تسویه یک بدهی
  Future<void> updateDebtSettlement(
    String eventId,
    String debtorId,
    String creditorId,
    String debtorName,
    String creditorName,
    bool isSettled, {
    String? description,
    DateTime? settlementDate,
  }) async {
    final debtKey = '$eventId-$debtorId-$creditorId';
    final legacyDebtKey = '$eventId-$debtorName-$creditorName';
    _settledDebts[debtKey] = isSettled;
    _settledDebts[legacyDebtKey] = isSettled;
    if (description != null) {
      _settlementDescriptions[debtKey] = description;
      _settlementDescriptions[legacyDebtKey] = description;
    } else if (!isSettled) {
      _settlementDescriptions.remove(debtKey);
      _settlementDescriptions.remove(legacyDebtKey);
    }
    if (settlementDate != null) {
      _settlementDates[debtKey] = settlementDate.toIso8601String();
      _settlementDates[legacyDebtKey] = settlementDate.toIso8601String();
    } else {
      _settlementDates.remove(debtKey);
      _settlementDates.remove(legacyDebtKey);
    }
    await _saveData();
    notifyListeners();
  }

  // دریافت وضعیت تسویه یک بدهی
  bool getDebtSettlement(
    String eventId,
    String debtorId,
    String creditorId,
    String debtorName,
    String creditorName,
  ) {
    final debtKey = '$eventId-$debtorId-$creditorId';
    final legacyDebtKey = '$eventId-$debtorName-$creditorName';
    return _settledDebts[debtKey] ?? _settledDebts[legacyDebtKey] ?? false;
  }

  // دریافت توضیحات تسویه یک بدهی
  String? getSettlementDescription(
    String eventId,
    String debtorId,
    String creditorId,
    String debtorName,
    String creditorName,
  ) {
    final debtKey = '$eventId-$debtorId-$creditorId';
    final legacyDebtKey = '$eventId-$debtorName-$creditorName';
    return _settlementDescriptions[debtKey] ??
        _settlementDescriptions[legacyDebtKey];
  }

  // محاسبه بدهی‌ها برای یک رویداد (با در نظر گرفتن انواع تقسیم هزینه)
  List<Debt> calculateDebtsForEvent(String eventId) {
    final eventData = _events[eventId];
    if (eventData == null || eventData.participants.isEmpty) {
      return [];
    }

    final participants = eventData.participants;
    final expenses = eventData.expenses;

    // محاسبه تراز هر شخص
    // balance = (کل مبلغی که پرداخت کرده) - (کل سهمی که باید پرداخت می‌کرده)
    final Map<String, double> balances = {};
    for (var participant in participants) {
      balances[participant.id] = 0.0;
    }

    for (var expense in expenses) {
      // ۱. اضافه کردن مبلغ به حساب پرداخت‌کننده
      balances[expense.payerId] =
          (balances[expense.payerId] ?? 0.0) + expense.amount;

      // ۲. کسر سهم هر نفر از حسابش
      final involvedIds = expense.involvedParticipantIds.isNotEmpty
          ? expense.involvedParticipantIds
          : participants.map((p) => p.id).toList();

      if (expense.splitType == 'equal') {
        final share = expense.amount / involvedIds.length;
        for (var id in involvedIds) {
          balances[id] = (balances[id] ?? 0.0) - share;
        }
      } else if (expense.splitType == 'shares') {
        double totalShares = 0;
        for (var id in involvedIds) {
          totalShares += (expense.customWeights?[id] ?? 1.0);
        }
        if (totalShares > 0) {
          for (var id in involvedIds) {
            final share =
                expense.amount *
                ((expense.customWeights?[id] ?? 1.0) / totalShares);
            balances[id] = (balances[id] ?? 0.0) - share;
          }
        }
      } else if (expense.splitType == 'percent') {
        for (var id in involvedIds) {
          final share =
              expense.amount * ((expense.customWeights?[id] ?? 0.0) / 100.0);
          balances[id] = (balances[id] ?? 0.0) - share;
        }
      } else if (expense.splitType == 'amount') {
        for (var id in involvedIds) {
          final share = expense.customWeights?[id] ?? 0.0;
          balances[id] = (balances[id] ?? 0.0) - share;
        }
      }
    }

    // جداسازی بدهکاران و طلبکاران
    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];

    balances.forEach((id, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(id, -balance));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(id, balance));
      }
    });

    // محاسبه تسویه‌ها (الگوریتم حریصانه برای حداقل کردن تعداد تراکنش‌ها)
    final List<Debt> debts = [];
    int debtorIndex = 0;
    int creditorIndex = 0;

    // کپی برای تغییر مقادیر در طول محاسبه
    final List<double> debtorAmounts = debtors.map((e) => e.value).toList();
    final List<double> creditorAmounts = creditors.map((e) => e.value).toList();

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtorId = debtors[debtorIndex].key;
      final creditorId = creditors[creditorIndex].key;

      final debtorParticipant = participants.firstWhere(
        (p) => p.id == debtorId,
        orElse: () => Participant(id: debtorId, name: 'نامشخص'),
      );
      final creditorParticipant = participants.firstWhere(
        (p) => p.id == creditorId,
        orElse: () => Participant(id: creditorId, name: 'نامشخص'),
      );

      final amount = debtorAmounts[debtorIndex] < creditorAmounts[creditorIndex]
          ? debtorAmounts[debtorIndex]
          : creditorAmounts[creditorIndex];

      if (amount > 0.01) {
        final debtKey =
            '$eventId-$debtorId-$creditorId';
        final legacyDebtKey =
            '$eventId-${debtorParticipant.name}-${creditorParticipant.name}';
        final settlementDateStr =
            _settlementDates[debtKey] ?? _settlementDates[legacyDebtKey];
        final isSettled =
            _settledDebts[debtKey] ?? _settledDebts[legacyDebtKey] ?? false;
        final settlementDescription =
            _settlementDescriptions[debtKey] ??
            _settlementDescriptions[legacyDebtKey];
        debts.add(
          Debt(
            debtorName: debtorParticipant.name,
            creditorName: creditorParticipant.name,
            debtorId: debtorId,
            creditorId: creditorId,
            amount: amount,
            creditorCardNumber: creditorParticipant.bankCardNumber,
            debtorCardNumber: debtorParticipant.bankCardNumber,
            isSettled: isSettled,
            settlementDescription: settlementDescription,
            settlementDate: settlementDateStr != null
                ? DateTime.parse(settlementDateStr)
                : null,
          ),
        );
      }

      debtorAmounts[debtorIndex] -= amount;
      creditorAmounts[creditorIndex] -= amount;

      if (debtorAmounts[debtorIndex] < 0.01) debtorIndex++;
      if (creditorAmounts[creditorIndex] < 0.01) creditorIndex++;
    }

    return debts;
  }

  // محاسبه تراز مالی هر شخص (چقدر پرداخت کرده منهای چقدر سهمش بوده)
  Map<String, double> calculateBalancesForEvent(String eventId) {
    final eventData = _events[eventId];
    if (eventData == null || eventData.participants.isEmpty) {
      return {};
    }

    final participants = eventData.participants;
    final expenses = eventData.expenses;

    final Map<String, double> balances = {};
    for (var participant in participants) {
      balances[participant.id] = 0.0;
    }

    for (var expense in expenses) {
      // مبلغ پرداخت شده توسط شخص
      balances[expense.payerId] =
          (balances[expense.payerId] ?? 0.0) + expense.amount;

      // کسر سهم هر نفر
      final involvedIds = expense.involvedParticipantIds.isNotEmpty
          ? expense.involvedParticipantIds
          : participants.map((p) => p.id).toList();

      if (expense.splitType == 'equal') {
        final share = expense.amount / involvedIds.length;
        for (var id in involvedIds) {
          balances[id] = (balances[id] ?? 0.0) - share;
        }
      } else if (expense.splitType == 'shares') {
        double totalShares = 0;
        for (var id in involvedIds) {
          totalShares += (expense.customWeights?[id] ?? 1.0);
        }
        if (totalShares > 0) {
          for (var id in involvedIds) {
            final share =
                expense.amount *
                ((expense.customWeights?[id] ?? 1.0) / totalShares);
            balances[id] = (balances[id] ?? 0.0) - share;
          }
        }
      } else if (expense.splitType == 'percent') {
        for (var id in involvedIds) {
          final share =
              expense.amount * ((expense.customWeights?[id] ?? 0.0) / 100.0);
          balances[id] = (balances[id] ?? 0.0) - share;
        }
      } else if (expense.splitType == 'amount') {
        for (var id in involvedIds) {
          final share = expense.customWeights?[id] ?? 0.0;
          balances[id] = (balances[id] ?? 0.0) - share;
        }
      }
    }

    return balances;
  }

  // پاک کردن همه داده‌ها
  Future<void> clearAll() async {
    _events.clear();
    _settledDebts.clear();
    _settlementDescriptions.clear();
    _settlementDates.clear();
    await _saveData();
    notifyListeners();
  }
}
