// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/contacts_provider.dart';
import '../utils/jalali_extension.dart';
import '../models/participant.dart';
import '../utils/card_input_formatter.dart';
import 'add_contact_screen.dart';
import 'edit_contact_screen.dart';
import 'add_contact_screen.dart';
import 'edit_contact_screen.dart';

class ContactsScreen extends StatefulWidget {
  final bool allowSelection;

  const ContactsScreen({super.key, this.allowSelection = false});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedContactIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCardNumber(String cardNumber) {
    try {
      // تبدیل اعداد فارسی به انگلیسی و حذف کاراکترهای غیر رقمی
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
      // استفاده از LRM برای نمایش صحیح در حالت RTL
      const lrm = '\u200E';
      return '$lrm${buffer.toString().toPersianNumbers()}$lrm';
    } catch (e) {
      return cardNumber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                '${_selectedContactIds.length.toString().toPersianNumbers()} مخاطب انتخاب شده',
              )
            : const Text('مخاطبین'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedContactIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (!_isSelectionMode)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
              child: Tooltip(
                message: 'حذف گروهی',
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.select_all, size: 20, color: Colors.white),
                ),
              ),
            ),
          if (_isSelectionMode)
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final provider = Provider.of<ContactsProvider>(
                      context,
                      listen: false,
                    );
                    setState(() {
                      _selectedContactIds = provider.contacts
                          .map((c) => c.id)
                          .toSet();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),

                    child: Tooltip(
                      message: 'انتخاب همه',
                      child: const Icon(
                        Icons.check_box,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _selectedContactIds.isEmpty
                      ? null
                      : () => _showDeleteSelectedDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),

                    child: Tooltip(
                      message: 'حذف انتخاب شده‌ها',
                      child: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Consumer<ContactsProvider>(
        builder: (context, contactsProvider, child) {
          if (contactsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredContacts = contactsProvider.searchContacts(
            _searchQuery,
          );

          return Column(
            children: [
              // Search Field
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'جستجو بر اساس نام یا شماره کارت',
                    prefixIcon: _searchQuery.isEmpty
                        ? const Icon(Icons.search)
                        : IconButton(
                            icon: const Icon(Icons.clear),
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
              ),
              // Contacts List
              Expanded(
                child: filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add,
                              size: 80,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'هنوز مخاطبی اضافه نشده'
                                  : 'مخاطبی پیدا نشد',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = filteredContacts[index];
                          return _buildContactCard(
                            context,
                            contact,
                            contactsProvider,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddContactScreen(),
                ),
              ),
              backgroundColor: Colors.teal.shade700,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'افزودن مخاطب',
                style: TextStyle(color: Colors.white),
              ),
            ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    contact,
    ContactsProvider provider,
  ) {
    final isSelected = _selectedContactIds.contains(contact.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Colors.teal.shade700, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedContactIds.remove(contact.id);
                if (_selectedContactIds.isEmpty) {
                  _isSelectionMode = false;
                }
              } else {
                _selectedContactIds.add(contact.id);
              }
            });
          } else if (widget.allowSelection) {
            Navigator.pop(context, contact);
          } else {
            _showContactOptions(context, contact, provider);
          }
        },
        onLongPress: widget.allowSelection
            ? null
            : () {
                setState(() {
                  _isSelectionMode = true;
                  _selectedContactIds.add(contact.id);
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedContactIds.add(contact.id);
                        } else {
                          _selectedContactIds.remove(contact.id);
                          if (_selectedContactIds.isEmpty) {
                            _isSelectionMode = false;
                          }
                        }
                      });
                    },
                  ),
                ),
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors
                    .primaries[contact.name.hashCode % Colors.primaries.length],
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0] : '؟',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (contact.bankCardNumber != null &&
                        contact.bankCardNumber!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.credit_card,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatCardNumber(contact.bankCardNumber!),
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (!_isSelectionMode)
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddContactScreen()),
    );
  }

  void _showContactOptions(
    BuildContext context,
    contact,
    ContactsProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors
                  .primaries[contact.name.hashCode % Colors.primaries.length],
              child: Text(
                contact.name.isNotEmpty ? contact.name[0] : '؟',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                contact.name,
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
            if (contact.bankCardNumber != null &&
                contact.bankCardNumber!.isNotEmpty)
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
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _formatCardNumber(contact.bankCardNumber!),
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.ltr,
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
                              final clipboard = contact.bankCardNumber!;
                              final data = ClipboardData(text: clipboard);
                              Clipboard.setData(data);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                        Navigator.pop(dialogContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditContactScreen(contact: contact),
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
                        Navigator.pop(dialogContext);
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
                                    'حذف مخاطب',
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
                                  'مخاطب "${contact.name}" حذف شود؟',
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
                                            provider.deleteContact(contact.id);
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('مخاطب حذف شد'),
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
                      },
                      child: const Text('حذف'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('بستن'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog(
    BuildContext context,
    contact,
    ContactsProvider provider,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditContactScreen(contact: contact),
      ),
    );
  }

  void _showDeleteSelectedDialog(BuildContext context) {
    final provider = Provider.of<ContactsProvider>(context, listen: false);
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
                'حذف گروهی',
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
              '${_selectedContactIds.length.toString().toPersianNumbers()} مخاطب حذف شوند؟',
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
                        for (final id in _selectedContactIds) {
                          provider.deleteContact(id);
                        }
                        setState(() {
                          _selectedContactIds.clear();
                          _isSelectionMode = false;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('مخاطبین انتخاب شده حذف شدند'),
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
}
