import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/participant.dart';
import '../providers/expense_provider.dart';
import '../utils/card_input_formatter.dart';
import '../utils/jalali_extension.dart';
import '../utils/thousands_separator_formatter.dart';

class EditParticipantScreen extends StatefulWidget {
  final String eventId;
  final String participantId;
  final String participantName;
  final String? bankCardNumber;

  const EditParticipantScreen({
    super.key,
    required this.eventId,
    required this.participantId,
    required this.participantName,
    this.bankCardNumber,
  });

  @override
  State<EditParticipantScreen> createState() => _EditParticipantScreenState();
}

class _EditParticipantScreenState extends State<EditParticipantScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _cardController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.participantName);

    // فرمت کردن شماره کارت اولیه برای نمایش صحیح (4-4-4-4)
    String initialCard = widget.bankCardNumber ?? '';
    if (initialCard.isNotEmpty) {
      final digits = initialCard.replaceAll(RegExp(r'\D'), '');
      String formatted = '';
      for (int i = 0; i < digits.length; i++) {
        if (i > 0 && i % 4 == 0) {
          formatted += '-';
        }
        formatted += digits[i];
      }
      initialCard = formatted;
    }
    _cardController = TextEditingController(text: initialCard);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  String _generateUniqueName(String name, List<Participant> existingParticipants, {String? excludeId}) {
    final trimmedName = name.trim();
    final existingNames = existingParticipants
        .where((p) => excludeId == null || p.id != excludeId)
        .map((p) => p.name.trim())
        .toSet();

    if (!existingNames.contains(trimmedName)) return trimmedName;

    int counter = 2;
    while (existingNames.contains('$trimmedName $counter')) {
      counter++;
    }
    return '$trimmedName $counter';
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final eventData = provider.getEventData(widget.eventId);
      final existingParticipants = eventData?.participants ?? [];
      final cardNumber = _cardController.text.trim();
      final cleanCardNumber = cardNumber.replaceAll('-', '');
      final uniqueName = _generateUniqueName(
        _nameController.text.trim(),
        existingParticipants,
        excludeId: widget.participantId,
      );
      provider.updateParticipant(
        eventId: widget.eventId,
        participantId: widget.participantId,
        name: uniqueName,
        bankCardNumber: cleanCardNumber.isEmpty ? null : cleanCardNumber,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final eventData = provider.getEventData(widget.eventId);
    final eventColor = eventData?.event.color ?? Colors.teal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش شرکت‌کننده'),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: eventColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'نام شرکت‌کننده',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameController,
                        autofocus: true,
                        textAlign: TextAlign.right,
                        maxLength: 25,
                        inputFormatters: [LengthLimitingTextInputFormatter(25)],
                        decoration: InputDecoration(
                          hintText: 'مثال: رضا',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'لطفاً نام را وارد کنید';
                          }
                          if (value.trim().length > 25) {
                            return 'نام نمی‌تواند بیش از ۲۵ کاراکتر باشد';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.credit_card, color: eventColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'شماره کارت بانکی (اختیاری)',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _cardController,
                        textAlign: TextAlign.left,
                        decoration: InputDecoration(
                          hintText: '0000-0000-0000-0000',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.credit_card),
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 19, // 16 رقم + 3 خط تیره
                        inputFormatters: [CardNumberInputFormatter()],
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final digitsOnly = value.replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            if (digitsOnly.length != 16) {
                              return 'شماره کارت باید 16 رقم باشد';
                            }
                          }
                          return null;
                        },
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
