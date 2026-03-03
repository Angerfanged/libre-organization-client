import 'package:libre_organization_client/credentials.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:libre_organization_client/main.dart';
import 'dart:async';

class SocketClient {
  // Singleton instance
  static final SocketClient _instance = SocketClient._internal();
  factory SocketClient() => _instance;
  SocketClient._internal();

  // Main server connection
  late IO.Socket mainSocket;

  // Map to store user-added server connections
  final Map<String, IO.Socket> userSockets = {};

  // Initialize main server connection
  void initMainConnection() {
    mainSocket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    mainSocket.onConnect((_) {
      print('Connected to main server: $serverUrl');
    });

    mainSocket.onDisconnect((_) {
      print('Disconnected from main server');
    });
  }

  bool isMainConnected() {
    return mainSocket.connected;
  }

  // Connect to a user-added server
  void connectToUserServer(String serverUrl) {
    if (userSockets.containsKey(serverUrl)) return;

    final socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      print('Connected to user server: $serverUrl');
    });

    socket.onDisconnect((_) {
      print('Disconnected from user server: $serverUrl');
      userSockets.remove(serverUrl);
    });

    userSockets[serverUrl] = socket;
  }

  // Disconnect from a user server
  void disconnectFromUserServer(String serverUrl) {
    final socket = userSockets[serverUrl];
    if (socket != null) {
      socket.disconnect();
      userSockets.remove(serverUrl);
    }
  }

  // Wait for socket connection to complete
  Future<void> waitForConnection(
    IO.Socket socket, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final completer = Completer<void>();

    void onConnected(_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
      socket.off('connect', onConnected);
    }

    if (socket.connected) {
      return Future.value();
    }

    socket.on('connect', onConnected);
    return completer.future.timeout(timeout);
  }

  // Send message via main socket
  void sendToMain(String event, dynamic data) {
    mainSocket.emit(event, data);
  }

  // Send message to a specific user server
  void sendToUserServer(String serverUrl, String event, dynamic data) {
    userSockets[serverUrl]?.emit(event, data);
  }

  // Listen to events from main server
  void onMainEvent(String event, Function(dynamic) callback) {
    mainSocket.on(event, callback);
  }

  // Listen to events from a user server
  void onUserEvent(String serverUrl, String event, Function(dynamic) callback) {
    userSockets[serverUrl]?.on(event, callback);
  }

  // Close main listener
  void offMainEvent(String event) {
    mainSocket.off(event);
  }

  // Close user server listener
  void offUserEvent(String serverUrl, String event) {
    userSockets[serverUrl]?.off(event);
  }

  // Disconnect all sockets
  void dispose() {
    mainSocket.disconnect();
    while (userSockets.length > 0) {
      String key = userSockets.keys.toList()[0];
      disconnectFromUserServer(key);
    }
  }
}
