import 'package:flutter/material.dart';

class ChatPresenter extends ChangeNotifier {
  List<Map<String, dynamic>> contacts = [];

  static final ChatPresenter _singleton = ChatPresenter._internal();
  factory ChatPresenter() => _singleton;

  ChatPresenter._internal();

  void updateContacts(List<Map<String, dynamic>> newContacts) {
    contacts = newContacts;
    print('Contacts updated: $contacts');
    notifyListeners();
  }
}
