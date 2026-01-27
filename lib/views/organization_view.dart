import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:libre_organization_client/presenters/organization_presenter.dart';

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
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        value.organizations[index]['iconUrl'],
                        width: 35,
                        height: 35,
                        fit: BoxFit.cover,
                      ),
                    ),
                    expandedAlignment: Alignment.topLeft,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    onExpansionChanged: (bool isExpanded) {
                      if (isExpanded) {
                        OrganizationPresenter().getOrganizationsChannels(
                          value.organizations[index]['serverUrl'],
                        );
                      }
                    },
                    children: OrganizationPresenter().buildOrganizationChannels(
                      value.organizations[index],
                      context,
                    ),
                  );
                },
              );
            },
          ),
        ),
        const VerticalDivider(),
        // Main content area
        Expanded(
          child: Consumer<OrganizationPresenter>(
            builder: (context, value, child) {
              return OrganizationPresenter().buildChannelContent(context);
            },
          ),
        ),
      ],
    );
  }
}
