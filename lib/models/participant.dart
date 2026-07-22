// مدل شرکت‌کننده
class Participant {
  final String id;
  final String name;
  final String? bankCardNumber; // شماره کارت بانکی

  Participant({
    required this.id,
    required this.name,
    this.bankCardNumber,
  });

  // تبدیل به Map برای ذخیره‌سازی
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bankCardNumber': bankCardNumber,
    };
  }

  // ساخت از Map
  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String,
      name: json['name'] as String,
      bankCardNumber: json['bankCardNumber'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
