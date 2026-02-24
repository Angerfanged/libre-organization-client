import 'package:flutter/material.dart';
import 'package:libre_organization_client/credentials.dart';
import 'package:libre_organization_client/socket_client.dart';
import 'dart:convert';

class OrganizationPresenter extends ChangeNotifier {
  List<Map<String, dynamic>> organizations = [];
  Map<String, dynamic> currentTextChannel = {'id': '', 'name': '', 'type': ''};
  Map<String, dynamic> currentVoiceChannel = {'id': '', 'name': '', 'type': ''};
  Map<String, dynamic> currentDisplayedChannel = {
    'id': '',
    'name': '',
    'type': '',
  };

  List<Map<String, dynamic>> currentChannelsMessages = [];

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

  void getOrganizations() {
    SocketClient().sendToMain('getOrganizations', {
      'user_id': Credentials().userId,
    });
    SocketClient().onMainEvent('sendOrganizations', (data) {
      final List<dynamic> jsonList = jsonDecode(data);
      organizations = jsonList.cast<Map<String, dynamic>>();
      notifyListeners();
    });
  }

  void getOrganizationsChannels(int organizationIndex) {
    Map org = organizations[organizationIndex];
    // Check if the organization is self hosted
    // If it is, get the channels from the user server. Otherwise, get the channels from the main server
    if (org['host'] != null && org['port'] != null) {
      SocketClient().sendToUserServer(
        '${org['host']}:${org['port']}',
        'getChannels',
        {'user_id': Credentials().userId},
      );
      SocketClient().onUserEvent(
        '${org['host']}:${org['port']}',
        'sendChannels',
        (data) {
          if (data is List) {
            List<Map<String, dynamic>> channels = [];
            for (var channel in data) {
              channels.add(channel);
            }
            org['channels'] = channels;
            notifyListeners();
          }
        },
      );
    } else {
      SocketClient().sendToMain('getChannels', {
        'user_id': Credentials().userId,
        'organization_id': org['id'],
      });
      SocketClient().onMainEvent('sendChannels', (data) {
        final List<dynamic> jsonList = jsonDecode(data);
        List<Map<String, dynamic>> channels = [];
        for (var channel in jsonList) {
          channels.add(channel);
        }
        org['channels'] = channels;
        notifyListeners();
      });
    }
  }

  void changeChannel(int organizationIndex, Map<String, dynamic> channel) {
    var org = organizations[organizationIndex];
    switch (channel['type']) {
      case 'text':
        // If the organization is self hosted, we need to send the join room event to the user server. Otherwise, we send it to the main server
        if (org['host'] != null && org['port'] != null) {
          // Leave current room if there is one
          if (currentTextChannel['id'] != '') {
            SocketClient().sendToUserServer(
              '${org['host']}:${org['port']}',
              'leaveTextRoom',
              {
                'room_path':
                    '${org['id']}-${currentTextChannel['id']}', // Room path should be organization id followed by channel id
              },
            );
          }
          // Join new room
          SocketClient().sendToUserServer(
            '${org['host']}:${org['port']}',
            'joinTextRoom',
            {
              'room_path':
                  '${org['id']}-${channel['id']}', // Room path should be organization id followed by channel id
            },
          );
        } else {
          // Leave current room if there is one
          if (currentTextChannel['id'] != '') {
            SocketClient().sendToMain('leaveTextRoom', {
              'room_path':
                  '${org['id']}-${currentTextChannel['id']}', // Room path should be organization id followed by channel id
            });
          }
          // Join new room
          SocketClient().sendToMain('joinTextRoom', {
            'room_path': '${org['id']}-${channel['id']}',
          });
        }
        // Update current channel
        OrganizationPresenter().currentTextChannel = {
          'id': channel['id'],
          'name': channel['name'],
          'type': channel['type'],
        };
        OrganizationPresenter().currentDisplayedChannel =
            OrganizationPresenter().currentTextChannel;
        OrganizationPresenter().currentChannelsMessages = [];
        notifyListeners();
        break;
      case 'voice':
        // If the organization is self hosted, we need to send the join room event to the user server. Otherwise, we send it to the main server
        if (org['host'] != null && org['port'] != null) {
          // Leave current room if there is one
          if (currentVoiceChannel['id'] != '') {
            SocketClient().sendToUserServer(
              '${org['host']}:${org['port']}',
              'leaveVoiceRoom',
              {
                'room_path':
                    '${org['id']}-${currentVoiceChannel['id']}', // Room path should be organization id followed by channel id
              },
            );
          }
          // Join new room
          SocketClient().sendToUserServer(
            '${org['host']}:${org['port']}',
            'joinVoiceRoom',
            {
              'room_path':
                  '${org['id']}-${channel['id']}', // Room path should be organization id followed by channel id
            },
          );
        } else {
          // Leave current room if there is one
          if (currentVoiceChannel['id'] != '') {
            SocketClient().sendToMain('leaveVoiceRoom', {
              'room_path':
                  '${org['id']}-${currentVoiceChannel['id']}', // Room path should be organization id followed by channel id
            });
          }
          // Join new room
          SocketClient().sendToMain('joinVoiceRoom', {
            'room_path': '${org['id']}-${channel['id']}',
          });
        }
        OrganizationPresenter().currentVoiceChannel = {
          'id': channel['id'],
          'name': channel['name'],
          'type': channel['type'],
        };
        OrganizationPresenter().currentDisplayedChannel =
            OrganizationPresenter().currentVoiceChannel;
        notifyListeners();
        break;
      default:
        return;
    }
  }

  void sendMessage(int organizationIndex, String message) {
    var org = organizations[organizationIndex];
    if (currentTextChannel['id'] == '') {
      return;
    }
    if (org['host'] != null && org['port'] != null) {
      SocketClient().sendToUserServer(
        '${org['host']}:${org['port']}',
        'sendMessage',
        {
          'room_path':
              '${org['id']}-${currentTextChannel['id']}', // Room path should be organization id followed by channel id
          'message': message,
          'sender_id': Credentials().userId,
        },
      );
    } else {
      SocketClient().sendToMain('sendMessage', {
        'room_path':
            '${org['id']}-${currentTextChannel['id']}', // Room path should be organization id followed by channel id
        'message': message,
        'sender_id': Credentials().userId,
      });
    }
  }

  void messageListener(int organizationIndex) {
    var org = organizations[organizationIndex];
    if (org['host'] != null && org['port'] != null) {
      // Reset listeners to prevent duplicates
      SocketClient().offUserEvent(
        '${org['host']}:${org['port']}',
        'newMessage',
      );
      SocketClient().offUserEvent(
        '${org['host']}:${org['port']}',
        'sendHistory',
      );
      // Set up listeners for new messages and message history
      SocketClient().onUserEvent(
        '${org['host']}:${org['port']}',
        'newMessage',
        (data) {
          currentChannelsMessages.add(data);
          notifyListeners();
        },
      );
      SocketClient().onUserEvent(
        '${org['host']}:${org['port']}',
        'sendHistory',
        (data) {
          currentChannelsMessages.insertAll(0, data);
          notifyListeners();
        },
      );
    } else {
      // Reset listeners to prevent duplicates
      SocketClient().offMainEvent('newMessage');
      SocketClient().offMainEvent('sendHistory');
      // Set up listeners for new messages and message history
      SocketClient().onMainEvent('newMessage', (data) {
        currentChannelsMessages.add(data);
        notifyListeners();
      });
      SocketClient().onMainEvent('sendHistory', (data) {
        currentChannelsMessages.insertAll(0, data);
        notifyListeners();
      });
    }
  }
}
