import 'package:flutter/material.dart';

class OrganizationPresenter extends ChangeNotifier {
  List<Map<String, dynamic>> organizations = [];

  static final OrganizationPresenter _singleton =
      OrganizationPresenter._internal();

  factory OrganizationPresenter() => _singleton;

  OrganizationPresenter._internal();

  void updateOrganizations(List<Map<String, dynamic>> newOrganizations) {
    organizations = newOrganizations;
    print('Organizations updated: $organizations');
    notifyListeners();
  }
}
