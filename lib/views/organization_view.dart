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

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _organizationScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _organizationScrollController.addListener(_organizationScrollListener);
  }

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
              OrganizationPresenter().getOrganizationsChannels(i);
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
              'localhost:3000/public/icon.png',
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

  List<Widget> _buildChannelList() {
    List<Widget> channels = [];
    var organization =
        OrganizationPresenter().organizations[_currentOrganizationIndex];
    if (organization['channels'] == null) {
      return [Text('Could not load channels')];
    }
    for (var channel in organization['channels']) {
      switch (channel['type']) {
        case 'text':
          channels.add(
            TextButton.icon(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: EdgeInsets.all(5),
                alignment: Alignment.centerLeft,
              ),
              icon: Icon(Icons.tag),
              label: Text(channel['name']),
              onPressed: () {
                OrganizationPresenter().changeChannel(
                  _currentOrganizationIndex,
                  channel,
                );
                OrganizationPresenter().getMessageHistory(
                  _currentOrganizationIndex,
                );
              },
            ),
          );
          break;
        case 'voice':
          channels.add(
            TextButton.icon(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: EdgeInsets.all(5),
                alignment: Alignment.centerLeft,
              ),
              icon: Icon(Icons.volume_up),
              label: Text(channel['name']),
              onPressed: () {
                OrganizationPresenter().changeChannel(
                  _currentOrganizationIndex,
                  channel,
                );
              },
            ),
          );
          break;
        case 'divider':
          channels.add(
            Row(
              children: [
                Expanded(child: Divider()),
                Text(
                  ' ${channel['name']} ',
                  style: TextStyle(color: Theme.of(context).dividerColor),
                ),
                Expanded(child: Divider()),
              ],
            ),
          );
          break;
        default:
          break;
      }
    }
    return channels;
  }

  Widget _buildChannelContent() {
    switch (OrganizationPresenter().currentDisplayedChannel['type']) {
      case 'text':
        return Column(
          children: [
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  Padding(padding: EdgeInsetsGeometry.all(2.5)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(padding: EdgeInsetsGeometry.all(2.5)),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: (Row(
                          children: [
                            Padding(padding: EdgeInsetsGeometry.all(5)),
                            Icon(
                              Icons.tag,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            Text(
                              OrganizationPresenter()
                                      .currentDisplayedChannel['name'] ??
                                  '',
                              style: Theme.of(context).textTheme.titleLarge!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                            ),
                            Padding(padding: EdgeInsetsGeometry.all(8)),
                          ],
                        )),
                      ),

                      Padding(padding: EdgeInsetsGeometry.all(12)),
                      TextButton.icon(
                        icon: Icon(
                          Icons.chat,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        label: Text(
                          'Chat',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        onPressed: () {},
                      ),
                      Padding(padding: EdgeInsetsGeometry.all(12)),
                      TextButton.icon(
                        icon: Icon(
                          Icons.folder,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        label: Text(
                          'Files',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        onPressed: () {},
                      ),
                      Padding(padding: EdgeInsetsGeometry.all(12)),
                      TextButton.icon(
                        icon: Icon(
                          Icons.group,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        label: Text(
                          'People',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        onPressed: () {},
                      ),
                      Padding(padding: EdgeInsetsGeometry.all(12)),
                      TextButton.icon(
                        icon: Icon(
                          Icons.settings,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        label: Text(
                          'Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  Padding(padding: EdgeInsetsGeometry.all(2.5)),
                ],
              ),
            ),
            // Chat content goes here
            Expanded(
              child: ListView.builder(
                controller: _organizationScrollController,
                reverse: true,
                itemCount:
                    OrganizationPresenter().currentChannelsMessages.length,
                itemBuilder: (context, index) {
                  var message =
                      OrganizationPresenter()
                          .currentChannelsMessages[OrganizationPresenter()
                              .currentChannelsMessages
                              .length -
                          1 -
                          index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        'JD',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    title: Text(message['author_id'].toString()),
                    subtitle: Text(message['content'].toString()),
                  );
                },
              ),
            ),
            Row(
              children: [
                IconButton(onPressed: () {}, icon: Icon(Icons.add)),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Message channel',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 5,
                        horizontal: 16,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isEmpty) return;
                      // Send message to server
                      OrganizationPresenter().sendMessage(
                        _currentOrganizationIndex,
                        value.trim(),
                      );
                      _messageController.clear();
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_messageController.text.trim().isEmpty) return;
                    // Send message to server
                    OrganizationPresenter().sendMessage(
                      _currentOrganizationIndex,
                      _messageController.text.trim(),
                    );
                    _messageController.clear();
                  },
                  icon: Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary,
                ),
                Padding(padding: EdgeInsetsGeometry.all(5)),
              ],
            ),
            Padding(padding: EdgeInsetsGeometry.all(5)),
          ],
        );
      case 'voice':
        return Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  OrganizationPresenter().currentDisplayedChannel['name'] ?? '',
                ),
              ),
            ),
            // Voice/video content goes here
          ],
        );
      default:
        return Column(children: [
          ],
        );
    }
  }

  void _organizationScrollListener() {
    if (_organizationScrollController.offset >=
            _organizationScrollController.position.maxScrollExtent &&
        !_organizationScrollController.position.outOfRange) {
      // Load more messages when scrolled to the top
      OrganizationPresenter().getMessageHistory(_currentOrganizationIndex);
    }
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
                              children: _buildChannelList(),
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
              return _buildChannelContent();
            },
          ),
        ),
      ],
    );
  }
}
