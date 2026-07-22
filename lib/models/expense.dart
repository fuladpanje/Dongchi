// مدل هزینه
class Expense {
  final String id;
  final String title;
  final double amount; // مبلغ به تومان
  final String payerId; // شناسه کسی که پرداخت کرده
  final DateTime? date; // تاریخ هزینه
  final String? description; // توضیحات
  final String? receiptPath; // مسیر فایل رسید
  final List<String> involvedParticipantIds; // افراد درگیر در این هزینه
  final Map<String, double>? customWeights; // سهم‌های سفارشی (درصد یا مبلغ)
  final String splitType; // 'equal', 'percent', 'amount', 'shares'
  final int? iconCodePoint; // کد آیکون

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.payerId,
    this.involvedParticipantIds = const [],
    this.customWeights,
    this.splitType = 'equal',
    this.date,
    this.description,
    this.receiptPath,
    this.iconCodePoint,
  });

  // تبدیل به Map برای ذخیره‌سازی
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'payerId': payerId,
      'involvedParticipantIds': involvedParticipantIds,
      'customWeights': customWeights,
      'splitType': splitType,
      'date': date?.toIso8601String(),
      'description': description,
      'receiptPath': receiptPath,
      'iconCodePoint': iconCodePoint,
    };
  }

  // ساخت از Map
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      payerId: json['payerId'] as String,
      involvedParticipantIds: json['involvedParticipantIds'] != null
          ? List<String>.from(json['involvedParticipantIds'])
          : [],
      customWeights: json['customWeights'] != null
          ? (json['customWeights'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            )
          : null,
      splitType: json['splitType'] as String? ?? 'equal',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : null,
      description: json['description'] as String?,
      receiptPath: json['receiptPath'] as String?,
      iconCodePoint: json['iconCodePoint'] as int?,
    );
  }
}
