import 'package:flutter/material.dart';
import 'package:libre_organization_client/socket_client.dart';
import 'package:provider/provider.dart';

import 'package:libre_organization_client/presenters/chat_presenter.dart';

class ChatView extends StatefulWidget {
  const ChatView({Key? key}) : super(key: key);

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  @override
  Widget build(BuildContext context) {
    if (!SocketClient().isMainConnected()) {
      return Center(
        child: Text(
          "Connect to the internet to view contacts",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Row(
      children: <Widget>[
        // Sidebar with organizations and their channels
        SizedBox(
          width: 250,
          child: Consumer<ChatPresenter>(
            builder: (context, value, child) {
              return ListView.builder(
                itemCount: value.contacts.length,
                itemBuilder: (context, index) {
                  if (value.contacts.length == 0) {
                    return const ListTile(title: Text('No Contacts Available'));
                  }
                  return ExpansionTile(
                    title: Text(value.contacts[index]['name']),
                    children: <Widget>[Text('Contact Channel')],
                  );
                },
              );
            },
          ),
        ),
        const VerticalDivider(),
        // Main content area
        Center(
          child: Text(
            'Chat Window',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    );
  }
}
