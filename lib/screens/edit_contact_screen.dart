import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/contacts_provider.dart';
import '../models/participant.dart';
import '../utils/card_input_formatter.dart';

class EditContactScreen extends StatefulWidget {
  final Participant contact;

  const EditContactScreen({super.key, required this.contact});

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _cardController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);

    // فرمت کردن شماره کارت اولیه برای نمایش صحیح (4-4-4-4)
    String initialCard = widget.contact.bankCardNumber ?? '';
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final contactsProvider = Provider.of<ContactsProvider>(
        context,
        listen: false,
      );
      final cardNumber = _cardController.text.trim();
      final cleanCardNumber = cardNumber.replaceAll('-', '');

      contactsProvider.updateContact(
        widget.contact.id,
        _nameController.text.trim(),
        cleanCardNumber.isEmpty ? '' : cleanCardNumber,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('مخاطب به‌روز شد')));

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش مخاطب'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          Icon(
                            Icons.person_rounded,
                            color: Colors.teal.shade700,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'نام مخاطب',
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
                          hintText: 'مثال: علی',
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
                            return 'نام نمی‌تواند بیش از 25 کاراکتر باشد';
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
                          Icon(
                            Icons.credit_card,
                            color: Colors.teal.shade700,
                            size: 22,
                          ),
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
