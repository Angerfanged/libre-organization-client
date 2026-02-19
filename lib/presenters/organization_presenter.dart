import 'package:flutter/material.dart';
import 'package:libre_organization_client/socket_client.dart';

class OrganizationPresenter extends ChangeNotifier {
  List<Map<String, dynamic>> organizations = [];
  Map<String, String> currentChannel = {'name': '', 'type': ''};

  static final OrganizationPresenter _singleton =
      OrganizationPresenter._internal();

  factory OrganizationPresenter() => _singleton;

  OrganizationPresenter._internal();

  Map<String, dynamic> findOrganization(String key, dynamic value) {
    for (var org in organizations) {
      if (org[key] == value) {
        return org;
      }
    }
    return Map();
  }

  List<Map<String, dynamic>> getOrganizations() {
    return organizations;
  }

  void updateOrganizations(Map<String, dynamic> newOrganizationData) {
    print(organizations);
    for (var org in organizations) {
      if (org['serverUrl'] == newOrganizationData['serverUrl']) {
        org = newOrganizationData;
        notifyListeners();
        return;
      }
    }
    organizations.add(newOrganizationData);
    print(organizations);
    notifyListeners();
  }

  void getOrganizationsChannels(String serverUrl) {
    SocketClient().sendToUserServer(serverUrl, 'getChannels', {});
    SocketClient().onUserEvent(serverUrl, 'sendChannels', (data) {
      // Process the received channel data as needed
      if (data is List) {
        Map org = findOrganization('serverUrl', serverUrl);
        if (org.isEmpty) {
          return;
        }
        List<Map<String, dynamic>> channels = [];
        for (var channel in data) {
          channels.add(channel);
        }
        org['channels'] = channels;
        notifyListeners();
      }
    });
  }

  List<Widget> buildOrganizationChannels(Map org, BuildContext context) {
    List<Widget> orgChannels = [];
    if (org['channels'].length == 0) {
      return [Center(child: Text('Could not get organization data'))];
    }
    for (var channel in org['channels']) {
      switch (channel['type']) {
        case 'text':
          orgChannels.add(
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
                OrganizationPresenter().currentChannel = {
                  'name': channel['name'],
                  'type': channel['type'],
                };
                ;
                notifyListeners();
              },
            ),
          );
          break;
        case 'voice':
          orgChannels.add(
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
                OrganizationPresenter().currentChannel = {
                  'name': channel['name'],
                  'type': channel['type'],
                };
                notifyListeners();
              },
            ),
          );
          break;
        case 'divider':
          orgChannels.add(
            Row(
              children: [
                Expanded(child: Divider()),
                Text(
                  ' ' + channel['name'] + ' ',
                  style: TextStyle(color: Theme.of(context).dividerColor),
                ),
                Expanded(child: Divider()),
              ],
            ),
          );
          break;
        default:
          continue;
      }
    }
    return orgChannels;
  }

  Widget buildChannelContent(BuildContext context) {
    switch (currentChannel['type']) {
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
                              currentChannel['name'] ?? '',
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
              child: Column(
                verticalDirection: VerticalDirection.up,
                children: [Text('Test')],
              ),
            ),
            Row(
              children: [
                IconButton(onPressed: () {}, icon: Icon(Icons.add)),
                Expanded(
                  child: TextField(
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
                    onSubmitted: (value) {},
                  ),
                ),
                IconButton(
                  onPressed: () {},
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
            Expanded(child: Center(child: Text(currentChannel['name'] ?? ''))),
            // Voice/video content goes here
          ],
        );
      default:
        return Column(children: [
          ],
        );
    }
  }
}
