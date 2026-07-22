import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/participant.dart';
import '../providers/contacts_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/card_input_formatter.dart';
import '../utils/jalali_extension.dart';
import '../utils/thousands_separator_formatter.dart';
import 'contacts_screen.dart';

class AddParticipantScreen extends StatefulWidget {
  final String eventId;

  const AddParticipantScreen({super.key, required this.eventId});

  @override
  State<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends State<AddParticipantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cardController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _addToContacts = false;
  Set<String> _selectedExpenseIds = {};
  Set<String> _selectedContactIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _cardController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _submit() {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final eventData = provider.getEventData(widget.eventId);
    final expenses = eventData?.expenses ?? [];
    final hasExpenses = expenses.isNotEmpty;
    final allEqual = hasExpenses && expenses.every((e) => e.splitType == 'equal');

    if (hasExpenses) {
      _showExpenseWarningDialog(() => _performSubmit(provider), allEqual: allEqual);
    } else {
      _performSubmit(provider);
    }
  }

  void _showExpenseWarningDialog(VoidCallback onConfirm, {required bool allEqual}) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final eventData = provider.getEventData(widget.eventId);
    final expenses = eventData?.expenses ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'توجه کنید',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'قبلاً هزینه‌هایی در این رویداد ثبت شده است. شرکت‌کننده جدید به صورت خودکار در هزینه‌های قبلی سهیم نخواهد بود.',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        if (!allEqual)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18, color: Colors.orange.shade800),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'برخی هزینه‌ها دارای سهم سفارشی هستند و فقط هزینه‌های مساوی قابل انتخاب‌اند.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'انتخاب هزینه‌ها:',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              '${_selectedExpenseIds.length}/${expenses.length}'.toPersianNumbers(),
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        CheckboxListTile(
                          value: _selectedExpenseIds.length == expenses.length,
                          tristate: _selectedExpenseIds.isNotEmpty && _selectedExpenseIds.length != expenses.length,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                _selectedExpenseIds = expenses.map((e) => e.id).toSet();
                              } else {
                                _selectedExpenseIds.clear();
                              }
                            });
                            setState(() {
                              if (value == true) {
                                _selectedExpenseIds = expenses.map((e) => e.id).toSet();
                              } else {
                                _selectedExpenseIds.clear();
                              }
                            });
                          },
                          title: const Text(
                            'افزودن به تمام هزینه‌های قبلی',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const Divider(height: 1),
                        ...expenses.map((expense) {
                          final isSelected = _selectedExpenseIds.contains(expense.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedExpenseIds.add(expense.id);
                                } else {
                                  _selectedExpenseIds.remove(expense.id);
                                }
                              });
                              setState(() {
                                if (value == true) {
                                  _selectedExpenseIds.add(expense.id);
                                } else {
                                  _selectedExpenseIds.remove(expense.id);
                                }
                              });
                            },
                            title: Text(
                              expense.title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${settings.formatAmount(expense.amount).toPersianNumbers()} تومان',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            secondary: Icon(
                              Icons.receipt_long,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                                  Navigator.pop(ctx);
                                  onConfirm();
                                },
                          child: const Text('متوجه شدم، اضافه کن'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('انصراف'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  void _performSubmit(ExpenseProvider provider) {
    final eventData = provider.getEventData(widget.eventId);
    final existingParticipants = List<Participant>.from(eventData?.participants ?? []);

    if (_selectedContactIds.isNotEmpty) {
      // افزودن چندتا مخاطب
      final contactsProvider = Provider.of<ContactsProvider>(
        context,
        listen: false,
      );

      for (final contactId in _selectedContactIds) {
        final contact = contactsProvider.contacts.firstWhere(
          (c) => c.id == contactId,
          orElse: () => Participant(id: '', name: '', bankCardNumber: null),
        );
        if (contact.id.isEmpty) continue;
        final cleanCardNumber = (contact.bankCardNumber ?? '').replaceAll(
          '-',
          '',
        );
        final uniqueName = _generateUniqueName(contact.name, existingParticipants);

        provider.addParticipantToEvent(
          widget.eventId,
          uniqueName,
          bankCardNumber: cleanCardNumber.isEmpty ? null : cleanCardNumber,
        );

        // Track used names for subsequent contacts in the same batch
        final addedParticipant = provider.getEventData(widget.eventId)?.participants.last;
        if (addedParticipant != null) {
          existingParticipants.add(addedParticipant);

          if (_selectedExpenseIds.isNotEmpty) {
            for (final expenseId in _selectedExpenseIds) {
              provider.addParticipantToSingleExpense(widget.eventId, expenseId, addedParticipant.id);
            }
          }
        }
      }
      Navigator.pop(context);
    } else if (_formKey.currentState!.validate()) {
      // افزودن یک شرکت کننده
      final contactsProvider = Provider.of<ContactsProvider>(
        context,
        listen: false,
      );
      final cardNumber = _cardController.text.trim();
      final cleanCardNumber = cardNumber.replaceAll('-', '');
      final uniqueName = _generateUniqueName(_nameController.text, existingParticipants);

      provider.addParticipantToEvent(
        widget.eventId,
        uniqueName,
        bankCardNumber: cardNumber.isEmpty ? null : cleanCardNumber,
      );

      if (_selectedExpenseIds.isNotEmpty) {
        final newParticipant = provider.getEventData(widget.eventId)?.participants.last;
        if (newParticipant != null) {
          for (final expenseId in _selectedExpenseIds) {
            provider.addParticipantToSingleExpense(widget.eventId, expenseId, newParticipant.id);
          }
        }
      }

      // اگر checkbox تیک شده باشد، به مخاطبین هم اضافه کن
      if (_addToContacts && _nameController.text.isNotEmpty) {
        contactsProvider.addContact(
          _nameController.text,
          cleanCardNumber.isEmpty ? '' : cleanCardNumber,
        );
      }

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
        title: const Text('افزودن شرکت‌کننده'),
        centerTitle: true,
        backgroundColor: eventColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, size: 28),
            tooltip: 'افزودن',
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
              AbsorbPointer(
                absorbing: _selectedContactIds.isNotEmpty,
                child: Opacity(
                  opacity: _selectedContactIds.isNotEmpty ? 0.5 : 1.0,
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_add_rounded,
                                color: eventColor,
                                size: 22,
                              ),
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
                                return 'نام نمی‌تواند بیش از 25 کاراکتر باشد';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.credit_card,
                                color: eventColor,
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
                            maxLength: 19,
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
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: _addToContacts,
                            onChanged: (value) {
                              setState(() => _addToContacts = value ?? false);
                            },
                            title: const Text(
                              'افزودن به مخاطبین',
                              style: TextStyle(fontSize: 14),
                            ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'انتخاب از مخاطبین:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedContactIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: eventColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedContactIds.length}',
                        style: TextStyle(
                          color: eventColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'جستجو بر اساس نام یا شماره کارت بانکی',
                  prefixIcon: _searchQuery.isEmpty
                      ? const Icon(Icons.search, size: 20)
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
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
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
              const SizedBox(height: 10),
              Consumer<ContactsProvider>(
                builder: (context, contactsProvider, child) {
                  final filteredContacts = contactsProvider.searchContacts(
                    _searchQuery,
                  );

                  if (filteredContacts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'هنوز مخاطبی اضافه نشده'
                              : 'مخاطبی پیدا نشد',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final isSelected = _selectedContactIds.contains(
                        contact.id,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected ? eventColor.withOpacity(0.1) : null,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedContactIds.remove(contact.id);
                              } else {
                                _selectedContactIds.add(contact.id);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value ?? false) {
                                        _selectedContactIds.add(contact.id);
                                      } else {
                                        _selectedContactIds.remove(contact.id);
                                      }
                                    });
                                  },
                                ),
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      Colors.primaries[contact.name.hashCode %
                                          Colors.primaries.length],
                                  child: Text(
                                    contact.name.isNotEmpty
                                        ? contact.name[0]
                                        : '؟',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (contact.bankCardNumber != null &&
                                          contact.bankCardNumber!.isNotEmpty)
                                        Text(
                                          contact.bankCardNumber!
                                              .replaceAllMapped(
                                                RegExp(r'.{1,4}'),
                                                (match) => '${match.group(0)}-',
                                              )
                                              .replaceAll(RegExp(r'-$'), ''),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
