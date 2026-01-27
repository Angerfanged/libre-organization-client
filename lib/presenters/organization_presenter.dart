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
        print(organizations);
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
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.tag),
                Text(
                  currentChannel['name'] ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Padding(padding: EdgeInsetsGeometry.all(12)),
                TextButton(
                  child: Text(
                    'Posts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  onPressed: () {},
                ),
                Padding(padding: EdgeInsetsGeometry.all(12)),
                TextButton(
                  child: Text(
                    'Files',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  onPressed: () {},
                ),
                Padding(padding: EdgeInsetsGeometry.all(12)),
                TextButton(
                  child: Text(
                    'People',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
            Divider(),
            // Chat content goes here
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
        return Column(
          children: [
            Expanded(
              child: Center(
                child: Text('Select a channel to view it\'s content'),
              ),
            ),
          ],
        );
    }
  }
}
