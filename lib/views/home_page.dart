import 'package:flutter/material.dart';
import 'package:libre_organization_client/credentials.dart';
import 'package:libre_organization_client/socket_client.dart';

import 'package:libre_organization_client/views/chat_view.dart';

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
    OrganizationPresenter()
        .getOrganizations(); // Fetch organizations on initialization
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
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
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
                      PopupMenuButton<String>(
                        onSelected: (String result) {
                          if (result == 'logout') {
                            Credentials().clear(); // Clear stored credentials
                            SocketClient()
                                .dispose(); // Close socket connections
                            Navigator.pushReplacementNamed(context, '/auth');
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'profile',
                                child: Text('Profile'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'settings',
                                child: Text('Settings'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                value: 'logout',
                                child: Text('Logout'),
                              ),
                            ],
                        child: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            'JD',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Dynamic Content Area
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
