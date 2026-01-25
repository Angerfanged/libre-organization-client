import 'package:flutter/material.dart';

import 'package:libre_organization_client/presenters/organization_presenter.dart';
import 'package:provider/provider.dart';

class OrganizationView extends StatefulWidget {
  const OrganizationView({Key? key}) : super(key: key);

  @override
  State<OrganizationView> createState() => _OrganizationViewState();
}

class _OrganizationViewState extends State<OrganizationView> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        // Sidebar with organizations and their channels
        SizedBox(
          width: 250,
          child: Consumer<OrganizationPresenter>(
            builder: (context, value, child) {
              return ListView.builder(
                itemCount: value.organizations.length,
                itemBuilder: (context, index) {
                  if (value.organizations.length == 0) {
                    return const ListTile(
                      title: Text('Join or Create an Organization'),
                    );
                  }
                  return ExpansionTile(
                    title: Text(value.organizations[index]['name']),
                    children: <Widget>[Text('Organization Channel')],
                  );
                },
              );
            },
          ),
        ),
        const VerticalDivider(),
        // Main content area
        Center(
          child: Text(
            'Organization Window',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    );
  }
}
