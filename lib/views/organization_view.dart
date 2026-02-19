import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:libre_organization_client/presenters/organization_presenter.dart';

class OrganizationView extends StatefulWidget {
  const OrganizationView({Key? key}) : super(key: key);

  @override
  State<OrganizationView> createState() => _OrganizationViewState();
}

class _OrganizationViewState extends State<OrganizationView> {
  int _currentOrganizationIndex = -1;
  bool _showAddButton = true;

  List<Widget> _buildOrganizationList() {
    List<Widget> organizations = [];
    for (int i = 0; i < OrganizationPresenter().organizations.length; i++) {
      var organization = OrganizationPresenter().organizations[i];
      organizations.add(
        TextButton.icon(
          onPressed: () {
            setState(() {
              _currentOrganizationIndex = i;
              _showAddButton = false;
              OrganizationPresenter().getOrganizationsChannels(
                organization['serverUrl'],
              );
            });
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.all(15),
            alignment: Alignment.centerLeft,
          ),
          label: Text(
            organization['name'],
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          icon: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              organization['iconUrl'],
              width: 35,
              height: 35,
              fit: BoxFit.cover,
              errorBuilder: (context, exception, stackTrace) {
                return SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),
          ),
        ),
      );
    }
    organizations.add(Padding(padding: EdgeInsetsGeometry.all(80)));
    return organizations;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        // Sidebar with organizations and their channels
        Stack(
          children: [
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
                      if (_currentOrganizationIndex >= 0) {
                        // Render back arrow and organization name
                        // Render organization's channels
                        return Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _currentOrganizationIndex = -1;
                                      _showAddButton = true;
                                    });
                                  },
                                  icon: Icon(Icons.arrow_back),
                                ),
                                Spacer(),
                                Text(
                                  value
                                      .organizations[_currentOrganizationIndex]['name'],
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Spacer(),
                                PopupMenuButton(
                                  onSelected: (value) {
                                    // Handle selection (e.g., navigate, update state)
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'Invite',
                                      child: Text('Invite'),
                                    ),
                                    PopupMenuItem(
                                      value: 'Settings',
                                      child: Text('Settings'),
                                    ),
                                    PopupMenuItem(
                                      value: 'Leave',
                                      child: Text('Leave'),
                                    ),
                                  ],
                                  icon: Icon(Icons.more_horiz),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: OrganizationPresenter()
                                  .buildOrganizationChannels(
                                    value
                                        .organizations[_currentOrganizationIndex],
                                    context,
                                  ),
                            ),
                          ],
                        );
                      } else {
                        // Create organizations list
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildOrganizationList(),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            if (_showAddButton)
              Positioned(
                bottom: 16, // Adjust spacing from bottom
                right: 16, // Adjust spacing from right
                child: FloatingActionButton(
                  onPressed: () {
                    // Handle FAB tap
                  },
                  child: Icon(Icons.add),
                  //mini: true,
                ),
              ),
          ],
        ),
        //const VerticalDivider(),
        VerticalDivider(width: 2.0, indent: 0.0, endIndent: 0.0),
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
