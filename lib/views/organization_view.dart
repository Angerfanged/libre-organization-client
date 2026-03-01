import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:libre_organization_client/credentials.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

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
  final FocusNode _focusNode = FocusNode();
  final ScrollController _organizationScrollController = ScrollController();

  // File watching state
  final Map<int, FileSystemEntity> _watchedFiles = {};
  final Map<int, DateTime?> _lastModifiedTimes = {};

  @override
  void initState() {
    super.initState();
    _organizationScrollController.addListener(_organizationScrollListener);
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
                // Load files for this channel
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
                        onPressed: () {
                          setState(() {
                            _channelWindowIndex = 3;
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
        OrganizationPresenter().getMessageHistory(_currentOrganizationIndex);
        return Column(
          children: [
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
                    onSubmitted: (value) {
                      if (value.trim().isEmpty) return;
                      // Send message to server
                      OrganizationPresenter().sendMessage(
                        _currentOrganizationIndex,
                        value.trim(),
                      );
                      _messageController.clear();
                      _focusNode
                          .requestFocus(); // Keep focus on the text field after sending
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
      case 1:
        return Consumer<FilePresenter>(
          builder: (context, filePresenter, child) {
            return Column(
              children: [
                Expanded(child: _buildFilesView(filePresenter)),
                Container(
                  padding: EdgeInsets.all(10),
                  /*decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),*/
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.upload_file),
                        label: Text('Upload File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          textStyle: TextStyle(fontSize: 20),
                          iconSize: 20,
                        ),
                        onPressed: () => _uploadFile(filePresenter),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(Icons.create_new_folder),
                        label: Text('New Folder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          textStyle: TextStyle(fontSize: 20),
                          iconSize: 20,
                        ),
                        onPressed: filePresenter.isLoading
                            ? null
                            : () {
                                final channel = OrganizationPresenter()
                                    .currentDisplayedChannel;
                                _showCreateFolderDialog(
                                  filePresenter,
                                  filePresenter.currentFolderId,
                                  channel['id'],
                                );
                              },
                      ),
                      if (filePresenter.uploadProgress > 0 &&
                          filePresenter.uploadProgress < 1)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: filePresenter.uploadProgress,
                          ),
                        ),
                      if (filePresenter.errorMessage != null)
                        Text(
                          filePresenter.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      Spacer(),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      case 2:
        return Column(
          children: [
            Expanded(child: Center(child: Text('People content goes here'))),
          ],
        );
      case 3:
        return Column(
          children: [
            Expanded(child: Center(child: Text('Settings content goes here'))),
          ],
        );
      default:
        return Column(children: []);
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

  void _loadChannelFiles() {
    final channel = OrganizationPresenter().currentDisplayedChannel;
    FilePresenter().getFolderContents(
      organizationId: OrganizationPresenter()
          .organizations[_currentOrganizationIndex]['id'],
      channelId: channel['id'],
    );
  }

  Future<void> _uploadFile(FilePresenter filePresenter) async {
    try {
      // Show a dialog to choose between file and folder upload
      final uploadType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Upload'),
          content: Text('What would you like to upload?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'file'),
              child: Text('File(s)'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'folder'),
              child: Text('Folder'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      );

      if (uploadType == null) return;

      if (uploadType == 'folder') {
        await _uploadFolder(filePresenter);
      } else {
        await _uploadFilePickerFiles(filePresenter);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading: $e')));
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

    final files = filePresenter.files;

    return Column(
      children: [
        // Breadcrumb navigation with drag targets for parent directories
        if (filePresenter.currentFolderId != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.transparent,
                        ),
                        child: Text('Root'),
                      );
                    },
                  ),
                  ...filePresenter.folderPath.map((folder) {
                    // Find the parent folder ID for this breadcrumb item
                    final folderIndex = filePresenter.folderPath.indexOf(
                      folder,
                    );
                    final parentFolderId = folderIndex > 0
                        ? filePresenter.folderPath[folderIndex - 1]['id']
                        : null;

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
                            final isDraggingOver = candidateData.isNotEmpty;
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
                                    ? Colors.amber.withOpacity(0.2)
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
                  Text('No files in this folder'),
                  SizedBox(height: 8),
                  Text(
                    'Click "Upload File" or "New Folder" to add content',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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

                // Folders are draggable (can be moved) and also accept drops (can have items moved into them)
                if (isFolder) {
                  return Draggable<Map<String, dynamic>>(
                    data: item,
                    feedback: Material(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder, color: Colors.amber),
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
                        margin: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Icon(Icons.folder, color: Colors.amber),
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
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1)
                              : Theme.of(context).scaffoldBackgroundColor,
                          margin: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.folder,
                              color: isDraggingOver
                                  ? Colors.amber.withOpacity(0.7)
                                  : Colors.amber,
                            ),
                            title: Text(item['file_name'] ?? 'Unnamed'),
                            subtitle: isDraggingOver
                                ? Text(
                                    'Drop to move file here',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Downloaded to: $path'),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Download failed: $e'),
                                        ),
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
                } else {
                  // Files are draggable
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
                        margin: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.description,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(item['file_name'] ?? 'Unnamed'),
                          subtitle: Text(
                            '${item['file_type'] ?? 'unknown'} • Author: ${item['author_id']}',
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
                          '${item['file_type'] ?? 'unknown'} • Author: ${item['author_id']}',
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
                              onTap: () =>
                                  _openAndWatchFile(filePresenter, item),
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
                                    SnackBar(
                                      content: Text('Downloaded to: $path'),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Download failed: $e'),
                                    ),
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
              },
            ),
          ),
      ],
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
            controller: folderNameController,
            decoration: InputDecoration(
              labelText: 'Folder Name',
              hintText: 'Enter folder name',
            ),
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
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showMoveFileDialog(
    FilePresenter filePresenter,
    Map<String, dynamic> fileItem,
    int channelId,
  ) {
    int? selectedFolderId;
    int? currentDialogFolderId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Move: ${fileItem['file_name']}'),
              content: SizedBox(
                width: 400,
                height: 300,
                child: Column(
                  children: [
                    // Breadcrumb navigation for folder selection
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  currentDialogFolderId = null;
                                  selectedFolderId = null;
                                });
                              },
                              child: Text(
                                'Root',
                                style: TextStyle(
                                  fontWeight: currentDialogFolderId == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (filePresenter.folderPath.isNotEmpty)
                              ...filePresenter.folderPath.map(
                                (folder) => Row(
                                  children: [
                                    Icon(Icons.chevron_right, size: 16),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          currentDialogFolderId = folder['id'];
                                          selectedFolderId = folder['id'];
                                        });
                                      },
                                      child: Text(
                                        folder['name'],
                                        style: TextStyle(
                                          fontWeight:
                                              currentDialogFolderId ==
                                                  folder['id']
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Divider(),
                    // List of folders in current location
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            leading: Icon(Icons.folder),
                            title: Text('Move to current location'),
                            onTap: () {
                              setState(() {
                                selectedFolderId = currentDialogFolderId;
                              });
                            },
                            selected: selectedFolderId == currentDialogFolderId,
                          ),
                          ...filePresenter.files
                              .where((item) => item['is_folder'] != 0)
                              .map(
                                (folder) => ListTile(
                                  leading: Icon(Icons.folder),
                                  title: Text(folder['file_name'] ?? 'Unnamed'),
                                  onTap: () {
                                    setState(() {
                                      selectedFolderId = folder['id'];
                                      currentDialogFolderId = folder['id'];
                                    });
                                  },
                                  selected: selectedFolderId == folder['id'],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedFolderId != fileItem['parent_id']
                      ? () {
                          filePresenter.moveFile(
                            organizationId: OrganizationPresenter()
                                .organizations[_currentOrganizationIndex]['id'],
                            fileId: fileItem['id'],
                            channelId: channelId,
                            newParentId: selectedFolderId,
                          );
                          _loadChannelFiles();
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text('Move'),
                ),
              ],
            );
          },
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
