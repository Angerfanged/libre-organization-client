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

  bool _fetchingOldPosts = false;

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
      organizations = jsonList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
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
          final List<dynamic> jsonList = jsonDecode(data);
          final List<Map<String, dynamic>> channels = jsonList
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          org['channels'] = channels;
          notifyListeners();
        },
      );
    } else {
      SocketClient().sendToMain('getChannels', {
        'user_id': Credentials().userId,
        'organization_id': org['id'],
      });
      SocketClient().onMainEvent('sendChannels', (data) {
        final List<dynamic> jsonList = jsonDecode(data);
        final List<Map<String, dynamic>> channels = jsonList
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
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
                'organization_id': org['id'],
                'channel_id': currentTextChannel['id'],
              },
            );
          }
          // Join new room
          SocketClient().sendToUserServer(
            '${org['host']}:${org['port']}',
            'joinTextRoom',
            {'organization_id': org['id'], 'channel_id': channel['id']},
          );
        } else {
          // Leave current room if there is one
          if (currentTextChannel['id'] != '') {
            SocketClient().sendToMain('leaveTextRoom', {
              'organization_id': org['id'],
              'channel_id': currentTextChannel['id'],
            });
          }
          // Join new room
          SocketClient().sendToMain('joinTextRoom', {
            'organization_id': org['id'],
            'channel_id': channel['id'],
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
        messageListener(organizationIndex);
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
                'organization_id': org['id'],
                'channel_id': currentVoiceChannel['id'],
              },
            );
          }
          // Join new room
          SocketClient().sendToUserServer(
            '${org['host']}:${org['port']}',
            'joinVoiceRoom',
            {'organization_id': org['id'], 'channel_id': channel['id']},
          );
        } else {
          // Leave current room if there is one
          if (currentVoiceChannel['id'] != '') {
            SocketClient().sendToMain('leaveVoiceRoom', {
              'organization_id': org['id'],
              'channel_id': currentVoiceChannel['id'],
            });
          }
          // Join new room
          SocketClient().sendToMain('joinVoiceRoom', {
            'organization_id': org['id'],
            'channel_id': channel['id'],
          });
        }
        OrganizationPresenter().currentVoiceChannel = {
          'id': channel['id'],
          'name': channel['name'],
          'type': channel['type'],
        };
        OrganizationPresenter().currentDisplayedChannel =
            OrganizationPresenter().currentVoiceChannel;
        messageListener(organizationIndex);
        notifyListeners();
        break;
      default:
        break;
    }
    _fetchingOldPosts = false;
  }

  void sendMessage(int organizationIndex, String message) {
    var org = organizations[organizationIndex];
    if (currentTextChannel['id'] == '') {
      return;
    }
    if (org['host'] != null && org['port'] != null) {
      SocketClient()
          .sendToUserServer('${org['host']}:${org['port']}', 'sendMessage', {
            'organization_id': org['id'],
            'channel_id': currentTextChannel['id'],
            'content': message,
            'author_id': Credentials().userId,
          });
    } else {
      SocketClient().sendToMain('sendMessage', {
        'organization_id': org['id'],
        'channel_id': currentTextChannel['id'],
        'content': message,
        'author_id': Credentials().userId,
      });
    }
  }

  void getMessageHistory(int organizationIndex) {
    var org = organizations[organizationIndex];
    if (currentTextChannel['id'] == '') {
      return;
    }
    // Prevent multiple simultaneous fetches of posts history
    if (_fetchingOldPosts) {
      return;
    }
    _fetchingOldPosts = true;
    if (org['host'] != null && org['port'] != null) {
      SocketClient().sendToUserServer(
        '${org['host']}:${org['port']}',
        'getHistory',
        {
          'organization_id': org['id'],
          'channel_id': currentTextChannel['id'],
          'last_post_id':
              currentChannelsMessages[0]['id'], // Send the id of the oldest post we have to fetch posts before it
        },
      );
    } else {
      if (currentChannelsMessages.isEmpty) {
        SocketClient().sendToMain('getHistory', {
          'organization_id': org['id'],
          'channel_id': currentTextChannel['id'],
          'last_post_id':
              null, // If there are no messages, fetch the latest messages
        });
      } else {
        SocketClient().sendToMain('getHistory', {
          'organization_id': org['id'],
          'channel_id': currentTextChannel['id'],
          'last_post_id':
              currentChannelsMessages[0]['id'], // Send the id of the oldest post we have to fetch posts before it
        });
      }
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
          final Map<String, dynamic> message = Map<String, dynamic>.from(
            data as Map,
          );
          currentChannelsMessages.add(message);
          notifyListeners();
        },
      );
      SocketClient().onUserEvent(
        '${org['host']}:${org['port']}',
        'sendHistory',
        (data) {
          final List<dynamic> jsonList = data is String
              ? jsonDecode(data)
              : data;
          final List<Map<String, dynamic>> posts = jsonList
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          currentChannelsMessages.insertAll(0, posts);
          notifyListeners();
          _fetchingOldPosts = false;
        },
      );
    } else {
      // Reset listeners to prevent duplicates
      SocketClient().offMainEvent('newMessage');
      SocketClient().offMainEvent('sendHistory');
      // Set up listeners for new messages and message history
      SocketClient().onMainEvent('newMessage', (data) {
        final Map<String, dynamic> message = Map<String, dynamic>.from(
          data as Map,
        );
        currentChannelsMessages.add(message);
        notifyListeners();
      });
      SocketClient().onMainEvent('sendHistory', (data) {
        final List<dynamic> jsonList = data is String ? jsonDecode(data) : data;
        final List<Map<String, dynamic>> posts = jsonList
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        currentChannelsMessages.insertAll(0, posts);
        notifyListeners();
        _fetchingOldPosts = false;
      });
    }
  }
}
