import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:libre_organization_client/credentials.dart';
import 'package:libre_organization_client/socket_client.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';

import 'package:libre_organization_client/presenters/organization_presenter.dart';
import 'package:libre_organization_client/presenters/file_presenter.dart';

class OrganizationView extends StatefulWidget {
  const OrganizationView({Key? key}) : super(key: key);

  @override
  State<OrganizationView> createState() => _OrganizationViewState();
}

class _OrganizationViewState extends State<OrganizationView> {
  int _currentOrganizationIndex = -1;
  bool _showAddButton = true;

  int _channelWindowIndex =
      0; // 0 for chat, 1 for files, 2 for people, 3 for settings

  final TextEditingController _messageController = TextEditingController();
  FocusNode _focusNode = FocusNode();
  final ScrollController _organizationScrollController = ScrollController();
  final GlobalKey<PopupMenuButtonState> _popupAddItemMenuKey = GlobalKey();

  bool _isLoadingMessages = false;

  // File watching state
  final Map<int, FileSystemEntity> _watchedFiles = {};
  final Map<int, DateTime?> _lastModifiedTimes = {};
  bool _showFilesInMessages = false;
  List<File> _filesToAttach = [];

  @override
  void initState() {
    super.initState();
    _organizationScrollController.addListener(_organizationScrollListener);
    _focusNode = FocusNode(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _sendMessage(); // Call the send message function
          // Prevent the default behavior of adding a new line
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _organizationScrollController.dispose();
    // Clean up watched files
    for (var file in _watchedFiles.values) {
      try {
        if (file is File && file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        print('Error deleting temp file: $e');
      }
    }
    _watchedFiles.clear();
    _lastModifiedTimes.clear();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty && _filesToAttach.isEmpty) {
      return;
    }
    // Send message to server
    OrganizationPresenter().sendMessage(
      _currentOrganizationIndex,
      _messageController.text.trim(),
      filesToAttach: _filesToAttach,
    );
    _messageController.clear();
    setState(() {
      _filesToAttach = [];
    });
    _focusNode.requestFocus(); // Keep focus on the text field after sending
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
              OrganizationPresenter().currentOrganizationIndex = i;
              OrganizationPresenter().getOrganizationsChannels(i);
              OrganizationPresenter().getOrganizationMembers(i);
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
              'http://localhost:3000/organizations/${organization['path_name']}/icon.png',
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
    for (int i = 0; i < organization['channels'].length; i++) {
      var channel = organization['channels'][i];
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
                setState(() {
                  _channelWindowIndex = 0;
                });

                OrganizationPresenter().changeChannel(
                  _currentOrganizationIndex,
                  channel,
                );
                OrganizationPresenter().getMessageHistory(
                  _currentOrganizationIndex,
                );

                _loadChannelFiles();
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
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: (Row(
                          children: [
                            Padding(padding: EdgeInsetsGeometry.all(5)),
                            Icon(
                              Icons.tag,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            Text(
                              OrganizationPresenter()
                                      .currentDisplayedChannel['name'] ??
                                  '',
                              style: Theme.of(context).textTheme.titleLarge!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                        onPressed: () {
                          setState(() {
                            _channelWindowIndex = 0;
                          });
                        },
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
                        onPressed: () {
                          setState(() {
                            _channelWindowIndex = 1;
                            // When switching to the files tab, load the default view
                            if (_showFilesInMessages) {
                              _loadChannelMessageFiles();
                            } else {
                              _loadChannelFiles();
                            }
                          });
                        },
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
                        onPressed: () {
                          setState(() {
                            _channelWindowIndex = 2;
                          });
                        },
                      ),
                    ],
                  ),
                  Padding(padding: EdgeInsetsGeometry.all(2.5)),
                ],
              ),
            ),
            // Channel content goes here
            Expanded(child: _buildChannelWindowContent()),
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

  Widget _buildChannelWindowContent() {
    switch (_channelWindowIndex) {
      case 0:
        return Column(
          children: [
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification is ScrollEndNotification &&
                      scrollNotification.metrics.extentAfter == 0) {
                    _organizationScrollListener();
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _organizationScrollController,
                  reverse: true, // This keeps the scroll at the bottom
                  itemCount:
                      OrganizationPresenter().currentChannelsMessages.length,
                  itemBuilder: (context, index) {
                    // Index 0 is now the newest message because of our .insert(0, ...) change
                    final message =
                        OrganizationPresenter().currentChannelsMessages[index];
                    final author = message['author'] as Map<String, dynamic>?;
                    final authorName =
                        author?['default_name'] ?? 'Unknown User';
                    final authorInitials = authorName.isNotEmpty
                        ? authorName.substring(0, 1).toUpperCase()
                        : '?';

                    final pfpPath = author?['pfp_path'];

                    return ListTile(
                      leading: pfpPath != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(
                                'http://localhost:3000/user_files$pfpPath',
                              ),
                            )
                          : CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: Text(
                                authorInitials,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                              ),
                            ),
                      title: Text(authorName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message['content'] != null &&
                              message['content'].toString().isNotEmpty)
                            SelectableText(
                              message['content'].toString(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          if (message['attachments'] != null &&
                              (message['attachments'] as List).isNotEmpty)
                            _buildMessageAttachments(
                              message['attachments'] as List,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_filesToAttach.isNotEmpty) _buildAttachmentsPreview(),
            Row(
              children: [
                IconButton(
                  onPressed: _pickFilesToAttach,
                  icon: Icon(Icons.add),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
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
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _sendMessage();
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
      case 1:
        return Consumer<FilePresenter>(
          builder: (context, filePresenter, child) =>
              _buildFilesView(filePresenter),
        );
      case 2:
        return Column(
          children: [
            Consumer<OrganizationPresenter>(
              builder: (context, presenter, child) {
                return Expanded(
                  child: ListView.builder(
                    itemCount: presenter.currentOrganizationMembers.length,
                    itemBuilder: (context, index) {
                      final memberData =
                          presenter.currentOrganizationMembers[index];
                      final author =
                          memberData['author'] as Map<String, dynamic>?;
                      final memberName =
                          author?['default_name'] ?? 'Unknown User';
                      final memberTag = author?['user_tag'] ?? '';
                      final memberInitials = memberName.isNotEmpty
                          ? memberName.substring(0, 1).toUpperCase()
                          : '?';
                      final pfpPath = author?['pfp_path'];
                      return ListTile(
                        leading: pfpPath != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(
                                  'http://localhost:3000/user_files$pfpPath',
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: Text(
                                  memberInitials,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                ),
                              ),
                        title: Text(memberName),
                        subtitle: Text('@$memberTag'),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      default:
        return Column(children: []);
    }
  }

  Widget _buildMessageAttachments(List attachments) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: attachments.map<Widget>((attachment) {
          final attach = attachment as Map<String, dynamic>;
          return _buildAttachmentContent(attach);
        }).toList(),
      ),
    );
  }

  Widget _buildAttachmentContent(Map<String, dynamic> attachment) {
    final fileType = (attachment['file_type'] as String?)?.toLowerCase() ?? '';
    final fileContent = attachment['file_content'] as String?;
    final fileName = attachment['file_name'] as String? ?? 'file';

    // If the file is missing on the server, show the generic attachment view.
    if (attachment['missing'] == true) {
      return _buildGenericAttachment(fileName, isMissing: true);
    }

    final imageTypes = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];

    Widget content;

    if (imageTypes.contains(fileType) && fileContent != null) {
      try {
        final bytes = base64Decode(fileContent);
        content = ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            // Optional: Add constraints to prevent overly large images
            width: 300,
            height: 200,
          ),
        );
      } catch (e) {
        content = _buildGenericAttachment(fileName);
      }
    } else {
      content = _buildGenericAttachment(fileName);
    }

    return InkWell(
      onTap: () {
        if (!imageTypes.contains(fileType)) {
          final filePresenter = Provider.of<FilePresenter>(
            context,
            listen: false,
          );
          _openAndWatchFile(filePresenter, attachment);
        } else {
          // Optional: implement a full-screen image viewer on tap
          print('Tapped on image attachment: $fileName');
        }
      },
      child: content,
    );
  }

  Widget _buildImageAttachment(Map<String, dynamic> attachment) {
    final bytes = base64Decode(attachment['file_content']);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Image.memory(bytes, fit: BoxFit.cover, width: 300, height: 200),
    );
  }

  Widget _buildGenericAttachment(String fileName, {bool isMissing = false}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMissing ? Icons.link_off : Icons.insert_drive_file_outlined,
              size: 20,
              color: isMissing ? Colors.red : null,
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName,
                overflow: TextOverflow.ellipsis,
                style: isMissing
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.red.shade300,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsPreview() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filesToAttach.length,
        itemBuilder: (context, index) {
          final file = _filesToAttach[index];
          final fileName = file.path.split(Platform.pathSeparator).last;
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.insert_drive_file, size: 32),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, size: 20),
                  onPressed: () {
                    setState(() => _filesToAttach.removeAt(index));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _organizationScrollListener() {
    final presenter = OrganizationPresenter();

    // Check if we are at the top of the list (since it's reversed)
    // and not already fetching.
    if (_organizationScrollController.position.atEdge &&
        _organizationScrollController.position.pixels != 0) {
      if (!presenter.fetchingOldPosts &&
          presenter.currentChannelsMessages.isNotEmpty) {
        // Use the presenter's flag to prevent multiple concurrent fetches.
        // This fetches the next batch of older messages.
        presenter.getMessageHistory(_currentOrganizationIndex);
      }
    }
  }

  void _loadChannelFiles() {
    final channel = OrganizationPresenter().currentDisplayedChannel;
    FilePresenter().getFolderContents(
      organizationId: OrganizationPresenter()
          .organizations[_currentOrganizationIndex]['id'],
      channelId: channel['id'],
    );
  }

  void _loadChannelMessageFiles() {
    final channel = OrganizationPresenter().currentDisplayedChannel;
    final orgId =
        OrganizationPresenter().organizations[_currentOrganizationIndex]['id'];
    SocketClient().sendToMain('getChannelMessageFiles', {
      'organization_id': orgId,
      'channel_id': channel['id'],
    });
  }

  Future<void> _pickFilesToAttach() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _filesToAttach.addAll(result.paths.map((path) => File(path!)).toList());
      });
    }
  }

  Future<void> _uploadFilePickerFiles(FilePresenter filePresenter) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final channel = OrganizationPresenter().currentDisplayedChannel;

        // Upload each selected file
        for (var file in result.files) {
          if (file.path == null) continue;

          final filePath = file.path!;
          final fileName = file.name;
          final fileExtension = fileName.split('.').last;
          // Remove extension from fileName since fileType is stored separately
          final fileNameWithoutExt = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;
          print(
            'Selected file: $filePath, name: $fileNameWithoutExt, extension: $fileExtension',
          );

          // Read file as bytes and encode as base64 for safe transmission
          final fileBytes = await File(filePath).readAsBytes();
          final fileContent = base64Encode(fileBytes);

          await filePresenter.uploadFile(
            organizationId: OrganizationPresenter()
                .organizations[_currentOrganizationIndex]['id'],
            authorId: Credentials().userId,
            channelId: channel['id'],
            fileAssociation: 'channel',
            fileName: fileNameWithoutExt,
            fileType: fileExtension,
            fileContent: fileContent,
            parentFolderId: filePresenter.currentFolderId,
          );
        }

        _loadChannelFiles();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading files: $e')));
    }
  }

  Future<void> _uploadFolder(FilePresenter filePresenter) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        final channel = OrganizationPresenter().currentDisplayedChannel;
        final folderDir = Directory(selectedDirectory);
        final folderName = folderDir.path.split(Platform.pathSeparator).last;

        // Create the root folder first
        final folderId = await filePresenter.createFolderAndGetId(
          organizationId: OrganizationPresenter()
              .organizations[_currentOrganizationIndex]['id'],
          authorId: Credentials().userId,
          channelId: channel['id'],
          folderName: folderName,
          parentFolderId: filePresenter.currentFolderId,
        );

        // Recursively upload all files in the folder
        await _uploadFolderContentsRecursive(
          filePresenter,
          folderDir,
          folderId,
          OrganizationPresenter()
              .organizations[_currentOrganizationIndex]['id'],
          channel['id'],
        );

        _loadChannelFiles();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading folder: $e')));
    }
  }

  Future<void> _uploadFolderContentsRecursive(
    FilePresenter filePresenter,
    Directory directory,
    int parentFolderId,
    int organizationId,
    int channelId,
  ) async {
    try {
      final entities = directory.listSync();

      for (var entity in entities) {
        if (entity is File) {
          // Upload the file
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final fileExtension = fileName.split('.').last;
          // Remove extension from fileName since fileType is stored separately
          final fileNameWithoutExt = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;

          final fileBytes = await entity.readAsBytes();
          final fileContent = base64Encode(fileBytes);

          await filePresenter.uploadFile(
            organizationId: organizationId,
            authorId: Credentials().userId,
            channelId: channelId,
            fileAssociation: 'channel',
            fileName: fileNameWithoutExt,
            fileType: fileExtension,
            fileContent: fileContent,
            parentFolderId: parentFolderId,
          );
        } else if (entity is Directory) {
          // Create a subfolder and recursively upload its contents
          final subfolderName = entity.path.split(Platform.pathSeparator).last;

          print('Creating subfolder: $subfolderName');

          final subFolderId = await filePresenter.createFolderAndGetId(
            organizationId: organizationId,
            authorId: Credentials().userId,
            channelId: channelId,
            folderName: subfolderName,
            parentFolderId: parentFolderId,
          );

          // Recursively upload contents of subfolder
          await _uploadFolderContentsRecursive(
            filePresenter,
            entity,
            subFolderId,
            organizationId,
            channelId,
          );
        }
      }
    } catch (e) {
      print('Error uploading folder contents: $e');
      rethrow;
    }
  }

  Future<void> _openAndWatchFile(
    FilePresenter filePresenter,
    Map<String, dynamic> file,
  ) async {
    try {
      // Fetch the file content from server
      await filePresenter.openFile(
        organizationId: OrganizationPresenter()
            .organizations[_currentOrganizationIndex]['id'],
        fileId: file['id'],
      );

      // Get the file content
      final openFileData = filePresenter.openFiles[file['id']];
      if (openFileData == null) {
        throw Exception('Failed to load file');
      }

      // Decode base64 file content to bytes
      final fileBytes = base64Decode(openFileData['file_content'] ?? '');

      // Create temporary file with proper extension
      final tempDir = await Future.value(
        Directory.systemTemp.createTempSync('libre_org_'),
      );
      final fileName = file['file_name'] ?? 'file';
      final fileType = file['file_type'] ?? '';
      // Only append extension if fileName doesn't already have it
      final fullFileName =
          fileName.endsWith('.$fileType') || fileName.contains('.')
          ? fileName
          : (fileType.isNotEmpty ? '$fileName.$fileType' : fileName);
      final filePath = '${tempDir.path}/$fullFileName';
      final localFile = File(filePath);

      // Write bytes to local file
      await localFile.writeAsBytes(fileBytes);

      // Store watched file
      _watchedFiles[file['id']] = localFile;
      _lastModifiedTimes[file['id']] = localFile.lastModifiedSync();

      // Open with default program (cross-platform)
      await OpenFilex.open(filePath);

      // Start watching for changes
      _watchFileForChanges(filePresenter, file['id'], filePath);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
    }
  }

  void _watchFileForChanges(
    FilePresenter filePresenter,
    int fileId,
    String filePath,
  ) {
    // Check for file changes every 2 seconds
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 2));

      if (!mounted || !_watchedFiles.containsKey(fileId)) {
        return false; // Stop watching
      }

      try {
        final file = File(filePath);
        final lastModified = file.lastModifiedSync();
        final previousModified = _lastModifiedTimes[fileId];

        if (previousModified == null ||
            lastModified.isAfter(previousModified)) {
          // File has been modified
          _lastModifiedTimes[fileId] = lastModified;
          final fileBytes = await file.readAsBytes();
          final newContent = base64Encode(fileBytes);

          // Update in presenter
          if (filePresenter.openFiles.containsKey(fileId)) {
            filePresenter.openFiles[fileId]!['file_content'] = newContent;
          }

          // Upload changes to server
          final channel = OrganizationPresenter().currentDisplayedChannel;
          await filePresenter.writeToFile(
            organizationId: OrganizationPresenter()
                .organizations[_currentOrganizationIndex]['id'],
            fileId: fileId,
            channelId: channel['id'],
            fileContent: newContent,
          );
        }
      } catch (e) {
        print('Error watching file: $e');
      }

      return true; // Continue watching
    });
  }

  Widget _buildFilesView(FilePresenter filePresenter) {
    if (filePresenter.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (filePresenter.errorMessage != null && filePresenter.files.isEmpty) {
      return Center(child: Text('Error: ${filePresenter.errorMessage}'));
    }

    final channel = OrganizationPresenter().currentDisplayedChannel;

    final allFiles = filePresenter.files;
    final List<Map<String, dynamic>> files;

    if (_showFilesInMessages) {
      files = allFiles;
    } else {
      // Filter out files that are message attachments, but always keep folders.
      files = allFiles.where((file) {
        final isFolder = file['is_folder'] != 0;
        final isMessageAttachment =
            file['file_association'] == 'message_attachment';
        return isFolder || !isMessageAttachment;
      }).toList();
    }

    return Column(
      children: [
        // Consolidated Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              PopupMenuButton(
                key: _popupAddItemMenuKey,
                tooltip: 'Add File or Folder',
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.upload_file),
                      title: Text('Upload File'),
                    ),
                    onTap: () => _uploadFilePickerFiles(filePresenter),
                  ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.folder),
                      title: Text('Upload Folder'),
                    ),
                    onTap: () => _uploadFolder(filePresenter),
                  ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.create_new_folder),
                      title: Text('New Folder'),
                    ),
                    onTap: () => _showCreateFolderDialog(
                      filePresenter,
                      filePresenter.currentFolderId,
                      channel['id'],
                    ),
                  ),
                ],
                child: ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  onPressed: () =>
                      _popupAddItemMenuKey.currentState?.showButtonMenu(),
                ),
              ),
              const SizedBox(width: 16),
              // Breadcrumb navigation is only shown when not viewing message files and not in root
              if (!_showFilesInMessages &&
                  filePresenter.currentFolderId != null)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Root drag target
                        DragTarget<Map<String, dynamic>>(
                          onWillAccept: (data) => true,
                          onAccept: (draggedItem) {
                            filePresenter.moveFile(
                              organizationId: OrganizationPresenter()
                                  .organizations[_currentOrganizationIndex]['id'],
                              fileId: draggedItem['id'],
                              channelId: channel['id'],
                              newParentId: null,
                            );
                            _loadChannelFiles();
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isDraggingOver = candidateData.isNotEmpty;
                            return TextButton(
                              onPressed: () {
                                filePresenter.getFolderContents(
                                  organizationId: OrganizationPresenter()
                                      .organizations[_currentOrganizationIndex]['id'],
                                  channelId: channel['id'],
                                  parentFolderId: null,
                                );
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: isDraggingOver
                                    ? Colors.amber.shade300.withOpacity(0.2)
                                    : Colors.transparent,
                              ),
                              child: Text('Root'),
                            );
                          },
                        ),
                        ...filePresenter.folderPath.map((folder) {
                          return Row(
                            children: [
                              Icon(Icons.chevron_right, size: 16),
                              DragTarget<Map<String, dynamic>>(
                                onWillAccept: (data) => true,
                                onAccept: (draggedItem) {
                                  filePresenter.moveFile(
                                    organizationId: OrganizationPresenter()
                                        .organizations[_currentOrganizationIndex]['id'],
                                    fileId: draggedItem['id'],
                                    channelId: channel['id'],
                                    newParentId: folder['id'],
                                  );
                                  _loadChannelFiles();
                                },
                                builder: (context, candidateData, rejectedData) {
                                  final isDraggingOver =
                                      candidateData.isNotEmpty;
                                  return TextButton(
                                    onPressed: () {
                                      filePresenter.getFolderContents(
                                        organizationId: OrganizationPresenter()
                                            .organizations[_currentOrganizationIndex]['id'],
                                        channelId: channel['id'],
                                        parentFolderId: folder['id'],
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: isDraggingOver
                                          ? Colors.amber.shade300.withOpacity(
                                              0.2,
                                            )
                                          : Colors.transparent,
                                    ),
                                    child: Text(folder['name']),
                                  );
                                },
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(), // Use a spacer to push the controls to the right
              if (filePresenter.uploadProgress > 0 &&
                  filePresenter.uploadProgress < 1)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: filePresenter.uploadProgress,
                    ),
                  ),
                ),
              Text('Message Files'),
              Switch(
                value: _showFilesInMessages,
                onChanged: (bool value) {
                  setState(() {
                    _showFilesInMessages = value;
                  });
                  if (value) {
                    _loadChannelMessageFiles();
                  } else {
                    _loadChannelFiles();
                  }
                },
              ),
            ],
          ),
        ),
        // File/folder list
        if (files.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  SizedBox(height: 16),
                  Text('No files to display'),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final item = files[index];
                final isFolder = item['is_folder'] != 0;
                if (isFolder) {
                  return _buildFolderItem(filePresenter, item, channel);
                } else {
                  return _buildFileItem(filePresenter, item, channel);
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFolderItem(
    FilePresenter filePresenter,
    Map<String, dynamic> item,
    Map<String, dynamic> channel,
  ) {
    final author = item['author'] as Map<String, dynamic>?;
    final authorName = author?['default_name'] ?? 'Unknown';

    return Draggable<Map<String, dynamic>>(
      data: item,
      feedback: Material(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder, color: Colors.amber.shade300),
                SizedBox(width: 8),
                Text(item['file_name'] ?? 'Unnamed'),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Card(
          color: Theme.of(context).scaffoldBackgroundColor,
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(Icons.folder, color: Colors.amber.shade300),
            title: Text(item['file_name'] ?? 'Unnamed'),
          ),
        ),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAccept: (data) => true,
        onAccept: (draggedItem) {
          // Move the dragged file/folder into this folder
          filePresenter.moveFile(
            organizationId: OrganizationPresenter()
                .organizations[_currentOrganizationIndex]['id'],
            fileId: draggedItem['id'],
            channelId: channel['id'],
            newParentId: item['id'],
          );
          _loadChannelFiles();
        },
        builder: (context, candidateData, rejectedData) {
          final isDraggingOver = candidateData.isNotEmpty;
          return Card(
            color: isDraggingOver
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Theme.of(context).scaffoldBackgroundColor,
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Icon(
                Icons.folder,
                color: isDraggingOver
                    ? Colors.amber.shade300.withOpacity(0.7)
                    : Colors.amber.shade300,
              ),
              title: Text(item['file_name'] ?? 'Unnamed'),
              subtitle: isDraggingOver
                  ? Text(
                      'Drop to move file here',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
              onTap: () {
                filePresenter.getFolderContents(
                  organizationId: OrganizationPresenter()
                      .organizations[_currentOrganizationIndex]['id'],
                  channelId: channel['id'],
                  parentFolderId: item['id'],
                );
              },
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.create_new_folder),
                        SizedBox(width: 8),
                        Text('New Folder'),
                      ],
                    ),
                    onTap: () => _showCreateFolderDialog(
                      filePresenter,
                      item['id'],
                      channel['id'],
                    ),
                  ),
                  PopupMenuItem(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download),
                        SizedBox(width: 8),
                        Text('Download'),
                      ],
                    ),
                    onTap: () async {
                      try {
                        final path = await filePresenter.downloadFolder(
                          organizationId: OrganizationPresenter()
                              .organizations[_currentOrganizationIndex]['id'],
                          channelId: channel['id'],
                          folderId: item['id'],
                          folderName: item['file_name'],
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloaded to: $path')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Download failed: $e')),
                        );
                      }
                    },
                  ),
                  PopupMenuItem(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                    onTap: () async {
                      await filePresenter.deleteFolder(
                        organizationId: OrganizationPresenter()
                            .organizations[_currentOrganizationIndex]['id'],
                        folderId: item['id'],
                        channelId: channel['id'],
                      );
                      _loadChannelFiles();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileItem(
    FilePresenter filePresenter,
    Map<String, dynamic> item,
    Map<String, dynamic> channel,
  ) {
    final author = item['author'] as Map<String, dynamic>?;
    final authorName = author?['default_name'] ?? 'Unknown';

    return Draggable<Map<String, dynamic>>(
      data: item,
      feedback: Material(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8),
                Text(item['file_name'] ?? 'Unnamed'),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Card(
          color: Theme.of(context).scaffoldBackgroundColor,
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(
              Icons.description,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(item['file_name'] ?? 'Unnamed'),
            subtitle: Text(
              '${item['file_type'] ?? 'unknown'} • Author: $authorName',
            ),
          ),
        ),
      ),
      child: Card(
        color: Theme.of(context).scaffoldBackgroundColor,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: Icon(
            Icons.description,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(item['file_name'] ?? 'Unnamed'),
          subtitle: Text(
            '${item['file_type'] ?? 'unknown'} • Author: $authorName',
          ),
          onTap: () => _openAndWatchFile(filePresenter, item),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new),
                    SizedBox(width: 8),
                    Text('Open'),
                  ],
                ),
                onTap: () => _openAndWatchFile(filePresenter, item),
              ),
              PopupMenuItem(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Download'),
                  ],
                ),
                onTap: () async {
                  try {
                    final path = await filePresenter.downloadFile(
                      organizationId: OrganizationPresenter()
                          .organizations[_currentOrganizationIndex]['id'],
                      fileId: item['id'],
                      fileName: item['file_name'],
                      fileType: item['file_type'] ?? '',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloaded to: $path')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download failed: $e')),
                    );
                  }
                },
              ),
              PopupMenuItem(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
                onTap: () async {
                  await filePresenter.deleteFile(
                    organizationId: OrganizationPresenter()
                        .organizations[_currentOrganizationIndex]['id'],
                    fileId: item['id'],
                    channelId: channel['id'],
                  );
                  _loadChannelFiles();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFolderDialog(
    FilePresenter filePresenter,
    int? parentFolderId,
    int channelId,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController folderNameController =
            TextEditingController();

        return AlertDialog(
          title: Text('Create New Folder'),
          content: TextField(
            autofocus: true,
            controller: folderNameController,
            decoration: InputDecoration(
              labelText: 'Folder Name',
              hintText: 'Enter folder name',
            ),
            onSubmitted: (value) {
              if (folderNameController.text.trim().isNotEmpty) {
                filePresenter.createFolder(
                  organizationId: OrganizationPresenter()
                      .organizations[_currentOrganizationIndex]['id'],
                  authorId: Credentials().userId,
                  channelId: channelId,
                  folderName: folderNameController.text.trim(),
                  parentFolderId: parentFolderId,
                );
                Navigator.pop(context);
                _loadChannelFiles();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (folderNameController.text.trim().isNotEmpty) {
                  filePresenter.createFolder(
                    organizationId: OrganizationPresenter()
                        .organizations[_currentOrganizationIndex]['id'],
                    authorId: Credentials().userId,
                    channelId: channelId,
                    folderName: folderNameController.text.trim(),
                    parentFolderId: parentFolderId,
                  );
                  Navigator.pop(context);
                  _loadChannelFiles();
                }
              },
              child: Text(
                'Create',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
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
                                      OrganizationPresenter()
                                              .currentOrganizationIndex =
                                          -1;
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
