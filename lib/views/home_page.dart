import 'package:flutter/material.dart';
import 'package:libre_organization_client/credentials.dart';
import 'package:libre_organization_client/socket_client.dart';
import 'package:libre_organization_client/views/settings_view.dart';
import 'package:provider/provider.dart';

import 'package:libre_organization_client/views/chat_view.dart';

import 'package:libre_organization_client/views/settings_view.dart';
import 'package:libre_organization_client/views/organization_view.dart';
import 'package:libre_organization_client/presenters/organization_presenter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedNavIndex = 1;
  dynamic userData;
  List<dynamic> selfHostedOrganizations = [];

  @override
  void initState() {
    super.initState();
    final presenter = Provider.of<OrganizationPresenter>(
      context,
      listen: false,
    );
    presenter.getOrganizations(); // Fetch organizations on initialization
  }

  Widget _buildContent() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildActivityContent();
      case 1:
        return ChatView();
      case 2:
        return OrganizationView();
      case 3:
        return _buildToDoContent();
      case 4:
        return _buildCalendarContent();
      default:
        return Center(child: Text('Select a section'));
    }
  }

  /*
  All content builders should have this basic structure:
  return Row(
    children: <Widget>[
      SizedBox(
        width: 250,
        child: ListView.builder(
          itemCount: // However many items
          itemBuilder: (context, index) {
            return // Your list item widget
          },
        ),
      ),
      const VerticalDivider(),
      // Main content area
    ],
  );
  */

  Widget _buildActivityContent() {
    return Center(
      child: Text('Activity', style: Theme.of(context).textTheme.headlineSmall),
    );
  }

  Widget _buildCalendarContent() {
    return Center(
      child: Text('Calendar', style: Theme.of(context).textTheme.headlineSmall),
    );
  }

  Widget _buildToDoContent() {
    return Center(
      child: Text('To-Do', style: Theme.of(context).textTheme.headlineSmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            selectedIndex: _selectedNavIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedNavIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.notifications),
                label: Text('Activity'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.chat),
                label: Text('Chats'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.groups),
                label: Text('Organizations'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.checklist),
                label: Text('To-Do'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today),
                label: Text('Calendar'),
              ),
            ],
          ),
          // Main Content
          Expanded(
            child: Consumer<OrganizationPresenter>(
              builder: (context, presenter, child) {
                return Column(
                  children: [
                    // Top Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Search Bar
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // User Profile with Menu
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsView(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withOpacity(0.5),
                              ),
                            ),
                            child: Consumer<OrganizationPresenter>(
                              builder: (context, presenter, child) {
                                final pfpPath =
                                    presenter.currentUser?['pfp_path'];
                                if (pfpPath != null) {
                                  return CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      'http://localhost:3000/user_files$pfpPath',
                                    ),
                                  );
                                } else {
                                  return CircleAvatar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Text(
                                      presenter.currentUser != null
                                          ? (presenter.currentUser!['default_name'] ??
                                                    '?')
                                                .substring(0, 1)
                                                .toUpperCase()
                                          : '?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                          ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dynamic Content Area
                    Expanded(child: _buildContent()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
