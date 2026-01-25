import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Credentials {
  static final Credentials _instance = Credentials._();

  Credentials._();
  factory Credentials() => _instance;

  String _email = '';
  String _password = '';

  String get email => _email;
  set email(String value) => _email = value;

  String get password => _password;
  set password(String value) => _password = value;

  void clear() {
    _email = '';
    _password = '';
    FlutterSecureStorage().deleteAll();
  }
}
