import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/participant.dart';

class ContactsProvider with ChangeNotifier {
  List<Participant> _contacts = [];
  late SharedPreferences _prefs;
  bool _isLoading = true;

  List<Participant> get contacts => _contacts;
  bool get isLoading => _isLoading;

  ContactsProvider() {
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final String? json = _prefs.getString('contacts');
      _contacts = [];
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        _contacts = decoded
            .map((item) => Participant.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveContacts() async {
    try {
      final json = jsonEncode(_contacts.map((c) => c.toJson()).toList());
      await _prefs.setString('contacts', json);
    } catch (e) {
      print('Error saving contacts: $e');
    }
  }

  Future<void> addContact(String name, String bankCardNumber) async {
    final newContact = Participant(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      bankCardNumber: bankCardNumber,
    );
    _contacts.add(newContact);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> updateContact(String id, String name, String bankCardNumber) async {
    final index = _contacts.indexWhere((c) => c.id == id);
    if (index >= 0) {
      _contacts[index] = Participant(
        id: id,
        name: name,
        bankCardNumber: bankCardNumber,
      );
      await _saveContacts();
      notifyListeners();
    }
  }

  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> reload() async {
    await _loadContacts();
  }

  Future<void> clearAll() async {
    _contacts = [];
    await _saveContacts();
    notifyListeners();
  }

  String _normalizeDigits(String input) {
    return input.replaceAllMapped(RegExp(r'[۰-۹٠-٩]'), (match) {
      final code = match.group(0)!.codeUnitAt(0);
      if (code >= 0x06F0 && code <= 0x06F9) {
        return String.fromCharCode(code - 0x06F0 + 0x30);
      }
      return String.fromCharCode(code - 0x0660 + 0x30);
    });
  }

  List<Participant> searchContacts(String query) {
    if (query.isEmpty) return _contacts;
    final normalizedQuery = _normalizeDigits(query);
    return _contacts
        .where((c) =>
            _normalizeDigits(c.name).contains(normalizedQuery) ||
            _normalizeDigits(c.bankCardNumber ?? '').contains(normalizedQuery))
        .toList();
  }
}
