import 'package:flutter/material.dart';
import 'package:libre_organization_client/credentials.dart';
import 'package:libre_organization_client/presenters/file_presenter.dart';
import 'package:libre_organization_client/socket_client.dart';
import 'dart:io';
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
  List<Map<String, dynamic>> currentOrganizationMembers = [];
  Map<String, dynamic>? currentUser;
  int currentOrganizationIndex = -1;

  bool fetchingOldPosts = false;
  bool isSendingMessage = false;

  static final OrganizationPresenter _singleton =
      OrganizationPresenter._internal();

  factory OrganizationPresenter() => _singleton;

  OrganizationPresenter._internal() {
    _fetchCurrentUser();
    _listenForUserUpdates();
  }

  void _fetchCurrentUser() {
    final userId = Credentials().userId;
    if (userId == null) return;

    SocketClient().sendToMain('getUserData', {'user_id': userId});
    SocketClient().onMainEvent('sendUserData', (data) {
      currentUser = Map<String, dynamic>.from(data as Map);
      notifyListeners();
    });
  }

  void _listenForUserUpdates() {
    SocketClient().onMainEvent('userUpdated', (data) {
      if (data['success'] == true && currentUser != null) {
        // Refetch the current user's data to update the top-bar avatar.
        _fetchCurrentUser();

        // If an organization is active, refetch its members to update the People tab.
        if (currentOrganizationIndex != -1) {
          getOrganizationMembers(currentOrganizationIndex);
        }
      }
    });
  }

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

  // Helper to get the correct socket client (main or user server)
  dynamic _getServerSocket(Map org) {
    if (org['host'] != null && org['port'] != null) {
      return SocketClient().userSockets['${org['host']}:${org['port']}'];
    }
    return SocketClient().mainSocket;
  }

  void getOrganizationsChannels(int organizationIndex) {
    Map org = organizations[organizationIndex];
    final socket = _getServerSocket(org);

    socket.emit('getChannels', {
      'user_id': Credentials().userId,
      'organization_id': org['id'],
    });

    socket.on('sendChannels', (data) {
      final List<dynamic> jsonList = data is String ? jsonDecode(data) : data;
      final List<Map<String, dynamic>> channels = jsonList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      org['channels'] = channels;
      notifyListeners();
    });
  }

  void getOrganizationMembers(int organizationIndex) {
    if (organizationIndex < 0 || organizationIndex >= organizations.length) {
      return;
    }
    Map org = organizations[organizationIndex];
    final socket = _getServerSocket(org);

    // Prevent duplicate listeners
    socket.off('sendOrganizationMembers');

    socket.emit('getOrganizationMembers', {'organization_id': org['id']});

    socket.on('sendOrganizationMembers', (data) {
      final List<dynamic> jsonList = data is String ? jsonDecode(data) : data;
      currentOrganizationMembers = jsonList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      notifyListeners();
    });
  }

  void changeChannel(int organizationIndex, Map<String, dynamic> channel) {
    var org = organizations[organizationIndex];
    final socket = _getServerSocket(org);

    void joinRoom(
      String roomType,
      String eventName,
      Map<String, dynamic> currentChannel,
    ) {
      if (currentChannel['id'] != '') {
        socket.emit('leave${roomType}Room', {
          'organization_id': org['id'],
          'channel_id': currentChannel['id'],
        });
      }
      socket.emit('join${roomType}Room', {
        'organization_id': org['id'],
        'channel_id': channel['id'],
      });
    }

    switch (channel['type']) {
      case 'text':
        joinRoom('Text', 'joinTextRoom', currentTextChannel);
        currentTextChannel = {
          'id': channel['id'],
          'name': channel['name'],
          'type': channel['type'],
        };
        currentDisplayedChannel = currentTextChannel;
        currentChannelsMessages = [];
        break;
      case 'voice':
        joinRoom('Voice', 'joinVoiceRoom', currentVoiceChannel);
        currentVoiceChannel = {
          'id': channel['id'],
          'name': channel['name'],
          'type': channel['type'],
        };
        currentDisplayedChannel = currentVoiceChannel;
        break;
      default:
        break;
    }
    messageListener(organizationIndex);
    fetchingOldPosts = false;
    notifyListeners();
  }

  Future<void> sendMessage(
    int organizationIndex,
    String message, {
    List<File>? filesToAttach,
  }) async {
    var org = organizations[organizationIndex];
    final socket = _getServerSocket(org);

    if (currentTextChannel['id'] == '' ||
        (message.trim().isEmpty &&
            (filesToAttach == null || filesToAttach.isEmpty))) {
      return;
    }

    List<Map<String, dynamic>> attachments = [];

    try {
      isSendingMessage = true;
      notifyListeners();

      if (filesToAttach != null && filesToAttach.isNotEmpty) {
        // 1. Upload each file and get its ID
        for (var file in filesToAttach) {
          final fileName = file.path.split('/').last;
          final fileType = fileName.split('.').last;
          final bytes = await file.readAsBytes();
          final fileContent = base64Encode(bytes);

          final fileId = await FilePresenter().uploadFileAndGetId(
            organizationId: org['id'],
            authorId: Credentials().userId,
            channelId: currentTextChannel['id'],
            fileAssociation: 'message_attachment',
            fileName: fileName,
            fileType: fileType,
            fileContent: fileContent,
          );

          attachments.add({
            'id': fileId,
            'file_name': fileName,
            'file_type': fileType,
          });
        }
      }

      // 2. Send the message with attachments
      socket.emit('sendMessage', {
        'organization_id': org['id'],
        'channel_id': currentTextChannel['id'],
        'content': message,
        'author_id': Credentials().userId,
        'attachments': attachments, // Send attachment metadata
      });
    } catch (e) {
      // Handle potential file reading or upload errors
      print('Error sending message with attachments: $e');
      // Optionally, notify the user of the failure
    } finally {
      isSendingMessage = false;
      notifyListeners();
    }
  }

  void getMessageHistory(int organizationIndex) {
    if (organizationIndex < 0 || organizationIndex >= organizations.length) {
      print('Invalid organization index');
      return;
    }
    if (currentTextChannel['id'] == '') {
      print('No channel selected');
      return;
    }
    // Prevent multiple simultaneous fetches of posts history
    if (fetchingOldPosts) return;
    fetchingOldPosts = true;

    Map org = organizations[organizationIndex];
    final socket = _getServerSocket(org);
    String? lastPostId;

    if (currentChannelsMessages.isNotEmpty) {
      // FIX: The oldest message is now at the END of the list
      lastPostId = currentChannelsMessages.last['id'].toString();
    }

    final payload = {
      'organization_id': org['id'],
      'channel_id': currentDisplayedChannel['id'],
      'last_post_id': lastPostId,
    };

    socket.emit('getHistory', payload);
  }

  void messageListener(int organizationIndex) {
    var org = organizations[organizationIndex];
    final socket = _getServerSocket(org);
    final isMainServer = socket == SocketClient().mainSocket;

    // Reset listeners to prevent duplicates
    socket.off('newMessage');
    socket.off('sendHistory');

    // NEW MESSAGE
    socket.on('newMessage', (data) {
      final Map<String, dynamic> message = Map<String, dynamic>.from(
        data as Map,
      );
      if (isMainServer) {
        // Insert at the beginning so it shows at the bottom of the reversed list
        currentChannelsMessages.insert(0, message);
      } else {
        // Assumes user server sends in order to be added at the end
        currentChannelsMessages.add(message);
      }
      notifyListeners();
    });

    // HISTORY
    socket.on('sendHistory', (data) {
      final List<dynamic> jsonList = data is String ? jsonDecode(data) : data;
      final List<Map<String, dynamic>> posts = jsonList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (isMainServer) {
        currentChannelsMessages.addAll(posts); // Append older posts to the end
      } else {
        currentChannelsMessages.insertAll(0, posts); // Prepend older posts
      }
      fetchingOldPosts = false;
      notifyListeners();
    });
  }
}
