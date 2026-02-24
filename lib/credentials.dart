import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class Credentials {
  static final Credentials _instance = Credentials._();

  Credentials._();
  factory Credentials() => _instance;

  String _email = '';
  String _password = '';
  int _userId = 0;

  String get email => _email;
  set email(String value) => _email = value;

  String get password => _password;
  set password(String value) => _password = value;

  int get userId => _userId;
  set userId(int value) => _userId = value;

  String get hashedPassword => sha512.convert(utf8.encode(password)).toString();

  void clear() {
    _email = '';
    _password = '';
    FlutterSecureStorage().deleteAll();
  }
}
