import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:libre_organization_client/socket_client.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

class FilePresenter extends ChangeNotifier {
  // Store files with structure: {id, author_id, channel_id, file_association, file_name, file_type, file_path, parent_id, is_folder}
  List<Map<String, dynamic>> files = [];

  // Currently open files in editor
  Map<int, Map<String, dynamic>> openFiles = {};

  // Track unsaved files that need to be uploaded: {clientId: {metadata}}
  Map<String, Map<String, dynamic>> unsavedFiles = {};

  // Folder navigation state
  int? _currentFolderId; // null = root level
  List<Map<String, dynamic>> _folderPath = []; // Breadcrumb path

  // Loading and error states
  bool isLoading = false;
  String? errorMessage;

  // Completer for tracking upload completion
  Completer<void>? _uploadCompleter;

  // Completers for tracking file uploads that need to return an ID: {tempKey: Completer}
  final Map<String, Completer<int>> _fileUploadCompleters = {};

  // Completers for tracking file open requests: {fileId: Completer}
  Map<int, Completer<void>> _fileOpenCompleters = {};

  // Completers for tracking folder creation: {tempKey: {completer, folderId}}
  Map<String, Map<String, dynamic>> _folderCreateCompleters = {};

  // Completers for fetching folder contents without UI updates: {tempKey: {completer, contents}}
  Map<String, Map<String, dynamic>> _folderContentCompleters = {};

  // Upload progress tracking: 0.0 to 1.0
  double uploadProgress = 0.0;

  // Socket Event Constants
  static const _sendFilesEvent = 'sendFiles';
  static const _sendFileDataEvent = 'sendFileData';
  static const _uploadErrorEvent = 'uploadError';
  static const _deleteErrorEvent = 'deleteError';
  static const _writeErrorEvent = 'writeError';
  static const _chunkAckEvent = 'chunkAck';
  static const _uploadCompleteEvent = 'uploadComplete';
  static const _fileUploadedEvent = 'fileUploaded';
  static const _folderErrorEvent = 'folderError';
  static const _sendFolderPathEvent = 'sendFolderPath';
  static const _folderCreatedEvent = 'folderCreated';
  static const _privateFolderContentsEvent = 'privateFolderContents';

  // Helper for parsing JSON data that might be a string or a map
  dynamic _parseJson(dynamic data) {
    return data is String ? jsonDecode(data) : data;
  }

  // Centralized error handler for socket events
  void _handleError(String message, [dynamic e]) {
    errorMessage = '$message${e != null ? ': $e' : ''}';
    isLoading = false;
    print(errorMessage);
    notifyListeners();
  }

  static final FilePresenter _singleton = FilePresenter._internal();
  factory FilePresenter() => _singleton;

  FilePresenter._internal() {
    _initializeSocketListeners();
  }

  // Initialize socket event listeners for file operations
  void _initializeSocketListeners() {
    SocketClient().onMainEvent(_sendFilesEvent, (data) {
      try {
        final List<dynamic> fileList = _parseJson(data);
        files = fileList
            .map((file) => Map<String, dynamic>.from(file))
            .toList();
        errorMessage = null;
        isLoading = false;
        notifyListeners();

        // Signal that upload is complete if we're waiting for it
        if (_uploadCompleter != null && !_uploadCompleter!.isCompleted) {
          _uploadCompleter!.complete();
        }
      } catch (e) {
        _handleError('Error parsing files', e);
        // Signal error if we're waiting
        if (_uploadCompleter != null && !_uploadCompleter!.isCompleted) {
          _uploadCompleter!.completeError(e);
        }
      }
    });

    SocketClient().onMainEvent(_sendFileDataEvent, (data) {
      try {
        final fileData = _parseJson(data);
        if (fileData != null) {
          final fileId = fileData['id'] as int?;
          openFiles[fileData['id']] = fileData;
          errorMessage = null;
          isLoading = false;
          notifyListeners();

          // Complete the open file completer if one exists for this file
          if (fileId != null && _fileOpenCompleters.containsKey(fileId)) {
            _fileOpenCompleters[fileId]!.complete();
            _fileOpenCompleters.remove(fileId);
          }
        }
      } catch (e) {
        _handleError('Error parsing file data', e);
      }
    });

    // Handle upload errors from server
    SocketClient().onMainEvent(_uploadErrorEvent, (data) {
      try {
        final errorData = _parseJson(data);
        _handleError(errorData['message'] ?? 'Upload failed');
        if (_uploadCompleter != null && !_uploadCompleter!.isCompleted) {
          _uploadCompleter!.completeError(Exception(errorMessage));
        }
      } catch (e) {
        _handleError('An upload error occurred', e);
      }
    });

    // Handle delete errors from server
    SocketClient().onMainEvent(_deleteErrorEvent, (data) {
      try {
        final errorData = _parseJson(data);
        _handleError(errorData['message'] ?? 'Delete failed');
      } catch (e) {
        _handleError('A delete error occurred', e);
      }
    });

    // Handle write errors from server
    SocketClient().onMainEvent(_writeErrorEvent, (data) {
      try {
        final errorData = _parseJson(data);
        _handleError(errorData['message'] ?? 'Write failed');
        if (_uploadCompleter != null && !_uploadCompleter!.isCompleted) {
          _uploadCompleter!.completeError(Exception(errorMessage));
        }
      } catch (e) {
        _handleError('A write error occurred', e);
      }
    });

    // Handle file chunk acknowledgment from server
    SocketClient().onMainEvent(_chunkAckEvent, (data) {
      try {
        final ackData = _parseJson(data);
        final chunksReceived =
            (ackData['chunks_received'] as num?)?.toInt() ?? 0;
        final totalChunks = (ackData['total_chunks'] as num?)?.toInt() ?? 1;
        final isCompleted = (ackData['completed'] as bool?) ?? false;

        uploadProgress = totalChunks > 0 ? chunksReceived / totalChunks : 0.0;
        isLoading = false;
        notifyListeners();

        if (isCompleted) {
          uploadProgress = 1.0;
          notifyListeners();

          if (_uploadCompleter != null && !_uploadCompleter!.isCompleted) {
            _uploadCompleter!.complete();
          }
        }
      } catch (e) {
        _handleError('Error handling chunk acknowledgment', e);
      }
    });

    // Handle upload complete confirmation
    SocketClient().onMainEvent(_uploadCompleteEvent, (data) {
      try {
        // data might be a plain object or JSON string
        uploadProgress = 1.0;
        notifyListeners();

        if (_uploadCompleter != null && !_uploadCompleter!.isCompleted) {
          _uploadCompleter!.complete();
        }
      } catch (e) {
        _handleError('Error handling upload complete', e);
      }
    });

    // Handle file creation response with file ID (for uploads expecting an ID back)
    SocketClient().onMainEvent(_fileUploadedEvent, (data) {
      try {
        final fileData = _parseJson(data);
        final tempKey = fileData['temp_key'] as String?;
        final fileId = fileData['file_id'] as int?;

        if (tempKey != null && fileId != null) {
          if (_fileUploadCompleters.containsKey(tempKey)) {
            _fileUploadCompleters[tempKey]!.complete(fileId);
            _fileUploadCompleters.remove(tempKey);
          }
        }
      } catch (e) {
        _handleError('Error parsing file upload response', e);
      }
    });

    // Handle folder-related errors
    SocketClient().onMainEvent(_folderErrorEvent, (data) {
      try {
        final errorData = _parseJson(data);
        _handleError(errorData['message'] ?? 'Folder operation failed');
      } catch (e) {
        _handleError('A folder operation error occurred', e);
      }
    });

    // Handle folder path response
    SocketClient().onMainEvent(_sendFolderPathEvent, (data) {
      try {
        final pathData = _parseJson(data);
        _folderPath = List<Map<String, dynamic>>.from(
          (pathData as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        notifyListeners();
      } catch (e) {
        _handleError('Error parsing folder path', e);
      }
    });

    // Handle folder creation response with folder ID
    SocketClient().onMainEvent(_folderCreatedEvent, (data) {
      try {
        final folderData = _parseJson(data);
        final tempKey = folderData['temp_key'] as String?;
        final folderId = folderData['folder_id'] as int?;

        if (tempKey != null && folderId != null) {
          if (_folderCreateCompleters.containsKey(tempKey)) {
            final completer =
                _folderCreateCompleters[tempKey]!['completer']
                    as Completer<int>;
            _folderCreateCompleters[tempKey]!['folderId'] = folderId;
            completer.complete(folderId);
            _folderCreateCompleters.remove(tempKey);
          }
        }
      } catch (e) {
        _handleError('Error parsing folder creation response', e);
      }
    });

    // Handle private folder contents (used internally by downloads without UI updates)
    SocketClient().onMainEvent(_privateFolderContentsEvent, (data) {
      try {
        final contentsData = _parseJson(data);
        final tempKey = contentsData['temp_key'] as String?;
        final contents = contentsData['contents'] as List<dynamic>? ?? [];

        if (tempKey != null && _folderContentCompleters.containsKey(tempKey)) {
          final completer =
              _folderContentCompleters[tempKey]!['completer']
                  as Completer<List<Map<String, dynamic>>>;
          final contentsList = contents
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          completer.complete(contentsList);
          _folderContentCompleters.remove(tempKey);
        }
      } catch (e) {
        _handleError('Error parsing private folder contents', e);
      }
    });
  }

  /// Fetch all files in a channel
  Future<void> fetchChannelFiles({
    required int organizationId,
    required int channelId,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      SocketClient().sendToMain('getFiles', {
        'organization_id': organizationId,
        'channel_id': channelId,
      });
    } catch (e) {
      errorMessage = 'Error fetching files: $e';
      isLoading = false;
      notifyListeners();
    }
  }

  /// Upload a new file to a channel with chunking for large files
  Future<void> uploadFile({
    required int organizationId,
    required int authorId,
    required int channelId,
    required String fileAssociation,
    required String fileName,
    required String fileType,
    required String fileContent,
    int? parentFolderId,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      uploadProgress = 0.0;
      notifyListeners();

      // Create a completer to wait for the server response
      _uploadCompleter = Completer<void>();

      final tempKey =
          '${organizationId}-${channelId}-${fileName}-${DateTime.now().millisecondsSinceEpoch}';

      // Split large files into chunks (1MB chunks)
      const chunkSize = 1024 * 1024; // 1MB
      final totalChunks = (fileContent.length / chunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize < fileContent.length)
            ? start + chunkSize
            : fileContent.length;
        final chunk = fileContent.substring(start, end);

        // Send this chunk
        SocketClient().sendToMain('uploadFileChunk', {
          'organization_id': organizationId,
          'author_id': authorId,
          'channel_id': channelId,
          'file_association': fileAssociation,
          'file_name': fileName,
          'file_type': fileType,
          'chunk_index': i,
          'total_chunks': totalChunks,
          'chunk_data': chunk,
          'parent_id': parentFolderId,
          'temp_key': tempKey, // Add temp key for session tracking
        });

        // Wait briefly to allow server to process
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Wait for the server to finish processing and emit uploadComplete
      if (_uploadCompleter != null) {
        await _uploadCompleter!.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('File upload timed out after 60 seconds');
          },
        );
      }
    } catch (e) {
      errorMessage = 'Error uploading file: $e';
      isLoading = false;
      uploadProgress = 0.0;
      _uploadCompleter = null;
      notifyListeners();
      print('Upload error: $e');
    }
  }

  /// Upload a file and get its ID back from the server.
  /// Used for message attachments where the ID is needed immediately.
  Future<int> uploadFileAndGetId({
    required int organizationId,
    required int authorId,
    required int channelId,
    required String fileAssociation,
    required String fileName,
    required String fileType,
    required String fileContent,
    int? parentFolderId,
  }) async {
    final tempKey =
        '${organizationId}-${channelId}-${fileName}-${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<int>();
    _fileUploadCompleters[tempKey] = completer;

    try {
      // Split large files into chunks (1MB chunks)
      const chunkSize = 1024 * 1024; // 1MB
      final totalChunks = (fileContent.length / chunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize < fileContent.length)
            ? start + chunkSize
            : fileContent.length;
        final chunk = fileContent.substring(start, end);

        // Send this chunk
        SocketClient().sendToMain('uploadFileChunk', {
          'organization_id': organizationId,
          'author_id': authorId,
          'channel_id': channelId,
          'file_association': fileAssociation,
          'file_name': fileName,
          'file_type': fileType,
          'chunk_index': i,
          'total_chunks': totalChunks,
          'chunk_data': chunk,
          'parent_id': parentFolderId,
          'temp_key': tempKey, // Pass temp key for server to send back
        });

        // A small delay can help prevent network congestion on rapid chunk sending
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Wait for the server to send back the fileUploaded event with the ID
      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          _fileUploadCompleters.remove(tempKey);
          throw TimeoutException('File upload timed out after 60 seconds');
        },
      );
    } catch (e) {
      _fileUploadCompleters.remove(tempKey);
      rethrow;
    }
  }

  /// Delete a file from a channel
  Future<void> deleteFile({
    required int organizationId,
    required int fileId,
    required int channelId,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      SocketClient().sendToMain('deleteFile', {
        'organization_id': organizationId,
        'file_id': fileId,
        'channel_id': channelId,
      });

      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error deleting file: $e';
      isLoading = false;
      notifyListeners();
    }
  }

  /// Open and fetch a specific file's content
  Future<void> openFile({
    required int organizationId,
    required int fileId,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // Create a completer to wait for the file data to arrive
      final completer = Completer<void>();
      _fileOpenCompleters[fileId] = completer;

      SocketClient().sendToMain('openFile', {
        'organization_id': organizationId,
        'file_id': fileId,
      });

      // Wait for the server to send the file data
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _fileOpenCompleters.remove(fileId);
          throw Exception('File open request timed out after 30 seconds');
        },
      );
    } catch (e) {
      errorMessage = 'Error opening file: $e';
      isLoading = false;
      _fileOpenCompleters.remove(fileId);
      notifyListeners();
      rethrow;
    }
  }

  /// Write/update content to an open file
  Future<void> writeToFile({
    required int organizationId,
    required int fileId,
    required int channelId,
    required String fileContent,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      SocketClient().sendToMain('writeFile', {
        'organization_id': organizationId,
        'file_id': fileId,
        'channel_id': channelId,
        'file_content': fileContent,
      });

      if (openFiles.containsKey(fileId)) {
        openFiles[fileId]!['file_content'] = fileContent;
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error writing to file: $e';
      isLoading = false;
      notifyListeners();
    }
  }

  /// Export a file to local storage and open it
  Future<void> exportAndOpenFile(int fileId) async {
    try {
      if (!openFiles.containsKey(fileId)) {
        errorMessage = 'File not found in open files';
        notifyListeners();
        return;
      }

      final fileData = openFiles[fileId]!;
      final tempDir = await getTemporaryDirectory();
      final fileName = fileData['file_name'] ?? 'file';
      final fileType = fileData['file_type'] ?? '';
      // Only append extension if fileName doesn't already have it
      final fullFileName =
          fileName.endsWith('.$fileType') || fileName.contains('.')
          ? fileName
          : (fileType.isNotEmpty ? '$fileName.$fileType' : fileName);
      final filePath = '${tempDir.path}/$fullFileName';
      final file = File(filePath);

      await file.writeAsString(fileData['file_content'] ?? '');
      await OpenFilex.open(file.path);
    } catch (e) {
      errorMessage = 'Error exporting file: $e';
      notifyListeners();
    }
  }

  /// Save a new file and automatically upload it to the server
  Future<void> saveNewFile({
    required int organizationId,
    required int authorId,
    required int channelId,
    required String fileAssociation,
    required String fileName,
    required String fileType,
    required String fileContent,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // Upload the file to the server and wait for completion
      await uploadFile(
        organizationId: organizationId,
        authorId: authorId,
        channelId: channelId,
        fileAssociation: fileAssociation,
        fileName: fileName,
        fileType: fileType,
        fileContent: fileContent,
      );

      // Mark as successfully uploaded
      errorMessage = null;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error saving file: $e';
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Register a listener for file save events and automatically upload
  /// Call this when a file editor is initialized
  void onFileSaveListener({
    required int organizationId,
    required int authorId,
    required int channelId,
    required String fileAssociation,
    required String fileName,
    required String fileType,
    required Function(String content) onContentChanged,
  }) {
    // Store metadata for tracking this file's save events
    final fileKey = '$organizationId-$channelId-$fileName';
    unsavedFiles[fileKey] = {
      'organizationId': organizationId,
      'authorId': authorId,
      'channelId': channelId,
      'fileAssociation': fileAssociation,
      'fileName': fileName,
      'fileType': fileType,
      'isDirty': false,
    };
    notifyListeners();
  }

  /// Mark a file as dirty (modified) when content changes
  void markFileAsDirty(String fileName, int channelId) {
    // Find the file in unsavedFiles and mark it as dirty
    unsavedFiles.forEach((key, value) {
      if (value['fileName'] == fileName && value['channelId'] == channelId) {
        value['isDirty'] = true;
      }
    });
    notifyListeners();
  }

  /// Save a modified file and upload it to the server
  Future<void> saveModifiedFile({
    required int organizationId,
    required String fileName,
    required int channelId,
    required String fileContent,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final fileKey = '$organizationId-$channelId-$fileName';

      if (!unsavedFiles.containsKey(fileKey)) {
        errorMessage = 'File not found in tracked files';
        isLoading = false;
        notifyListeners();
        return;
      }

      final fileMetadata = unsavedFiles[fileKey]!;

      // Upload the modified file and wait for completion
      await uploadFile(
        organizationId: organizationId,
        authorId: fileMetadata['authorId'],
        channelId: fileMetadata['channelId'],
        fileAssociation: fileMetadata['fileAssociation'],
        fileName: fileMetadata['fileName'],
        fileType: fileMetadata['fileType'],
        fileContent: fileContent,
      );

      // Mark as clean (saved)
      fileMetadata['isDirty'] = false;
      errorMessage = null;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error saving file: $e';
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Clear all files and open files
  Future<void> clear() async {
    files.clear();
    openFiles.clear();
    unsavedFiles.clear();
    errorMessage = null;
    notifyListeners();
  }

  /// Get a specific file by ID
  Map<String, dynamic>? getFileById(int fileId) {
    try {
      return files.firstWhere((file) => file['id'] == fileId);
    } catch (e) {
      return null;
    }
  }

  /// Get all files for a specific channel
  List<Map<String, dynamic>> getChannelFiles(int channelId) {
    return files.where((file) => file['channel_id'] == channelId).toList();
  }

  /// Get all unsaved files
  List<Map<String, dynamic>> getUnsavedFiles() {
    return unsavedFiles.values
        .where((file) => file['isDirty'] == true)
        .toList();
  }

  /// Check if a file is unsaved/dirty
  bool isFileDirty(String fileName, int channelId) {
    return unsavedFiles.values.any(
      (file) =>
          file['fileName'] == fileName &&
          file['channelId'] == channelId &&
          file['isDirty'] == true,
    );
  }

  /// Setup an automatic listener for file data changes that uploads when detected
  /// This method monitors the content of an open file and automatically uploads changes
  /// Call this after opening a file to enable auto-sync
  void setupFileDataListener({
    required int fileId,
    required int organizationId,
    required int channelId,
    Duration debounceDelay = const Duration(milliseconds: 1000),
  }) {
    if (!openFiles.containsKey(fileId)) {
      errorMessage = 'File not found in open files';
      notifyListeners();
      return;
    }

    String? lastUploadedContent = openFiles[fileId]!['file_content'];

    void checkAndUploadChanges() {
      if (!openFiles.containsKey(fileId)) return;

      final currentContent = openFiles[fileId]!['file_content'];

      // Only upload if content has actually changed since last upload
      if (currentContent != lastUploadedContent) {
        lastUploadedContent = currentContent;
        writeToFile(
          organizationId: organizationId,
          fileId: fileId,
          channelId: channelId,
          fileContent: currentContent,
        );
      }
    }

    // Store the listener function for this file so it can be called when content changes
    // This is typically called from the UI when the editor detects changes
    _fileDataListeners[fileId] = checkAndUploadChanges;
  }

  /// Getters for folder navigation
  int? get currentFolderId => _currentFolderId;
  List<Map<String, dynamic>> get folderPath => _folderPath;

  /// Get folder contents
  Future<void> getFolderContents({
    required int organizationId,
    required int channelId,
    int? parentFolderId,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      _currentFolderId = parentFolderId;
      notifyListeners();

      SocketClient().sendToMain('getFolderContents', {
        'organization_id': organizationId,
        'channel_id': channelId,
        'parent_id': parentFolderId,
      });

      // Also fetch the path for breadcrumbs
      if (parentFolderId != null) {
        SocketClient().sendToMain('getFolderPath', {
          'organization_id': organizationId,
          'folder_id': parentFolderId,
          'channel_id': channelId,
        });
      } else {
        _folderPath = [];
      }
    } catch (e) {
      errorMessage = 'Error loading folder contents: $e';
      isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new folder
  Future<void> createFolder({
    required int organizationId,
    required int authorId,
    required int channelId,
    required String folderName,
    int? parentFolderId,
  }) async {
    try {
      SocketClient().sendToMain('createFolder', {
        'organization_id': organizationId,
        'author_id': authorId,
        'channel_id': channelId,
        'folder_name': folderName,
        'parent_id': parentFolderId,
      });
    } catch (e) {
      errorMessage = 'Error creating folder: $e';
      notifyListeners();
    }
  }

  /// Create a folder and wait for its ID (for recursive folder uploads)
  Future<int> createFolderAndGetId({
    required int organizationId,
    required int authorId,
    required int channelId,
    required String folderName,
    int? parentFolderId,
  }) async {
    final tempKey =
        '${organizationId}-${channelId}-${folderName}-${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<int>();

    _folderCreateCompleters[tempKey] = {
      'completer': completer,
      'folderId': null,
    };

    try {
      SocketClient().sendToMain('createFolder', {
        'organization_id': organizationId,
        'author_id': authorId,
        'channel_id': channelId,
        'folder_name': folderName,
        'parent_id': parentFolderId,
        'temp_key': tempKey,
      });

      // Wait for folder creation with 30 second timeout
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _folderCreateCompleters.remove(tempKey);
          throw TimeoutException(
            'Folder creation timed out',
            const Duration(seconds: 30),
          );
        },
      );
    } catch (e) {
      _folderCreateCompleters.remove(tempKey);
      errorMessage = 'Error creating folder: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Move a file or folder to a different location
  Future<void> moveFile({
    required int organizationId,
    required int fileId,
    required int channelId,
    int? newParentId,
  }) async {
    try {
      SocketClient().sendToMain('moveFile', {
        'organization_id': organizationId,
        'file_id': fileId,
        'channel_id': channelId,
        'new_parent_id': newParentId,
      });
    } catch (e) {
      errorMessage = 'Error moving file: $e';
      notifyListeners();
    }
  }

  /// Delete a folder and all its contents
  Future<void> deleteFolder({
    required int organizationId,
    required int folderId,
    required int channelId,
  }) async {
    try {
      SocketClient().sendToMain('deleteFolder', {
        'organization_id': organizationId,
        'folder_id': folderId,
        'channel_id': channelId,
      });
    } catch (e) {
      errorMessage = 'Error deleting folder: $e';
      notifyListeners();
    }
  }

  // Map to store active file data listeners
  final Map<int, Function()> _fileDataListeners = {};

  /// Call this method from the UI when file content changes in the editor
  /// This triggers the auto-upload listener if one is set up for this file
  void notifyFileContentChanged(int fileId) {
    if (_fileDataListeners.containsKey(fileId)) {
      _fileDataListeners[fileId]!();
    }
  }

  /// Remove the listener for a specific file
  void removeFileDataListener(int fileId) {
    _fileDataListeners.remove(fileId);
  }

  /// Download a single file to the downloads directory
  Future<String> downloadFile({
    required int organizationId,
    required int fileId,
    required String fileName,
    required String fileType,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // Get the downloads directory
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Downloads directory not available');
      }

      // Request file content from server
      final completer = Completer<void>();
      _fileOpenCompleters[fileId] = completer;

      SocketClient().sendToMain('openFile', {
        'organization_id': organizationId,
        'file_id': fileId,
      });

      // Wait for file data
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _fileOpenCompleters.remove(fileId);
          throw Exception('File download timed out');
        },
      );

      // Get the file content from openFiles
      if (openFiles.containsKey(fileId)) {
        final fileData = openFiles[fileId]!;
        final fileContent = fileData['file_content'] as String? ?? '';

        // Decode base64 content
        final decodedBytes = base64Decode(fileContent);

        // Create the file in downloads
        // Only append extension if fileName doesn't already have it
        final fullFileName =
            fileName.endsWith('.$fileType') || fileName.contains('.')
            ? fileName
            : (fileType.isNotEmpty ? '$fileName.$fileType' : fileName);
        final downloadFile = File('${downloadsDir.path}/$fullFileName');
        await downloadFile.writeAsBytes(decodedBytes);

        isLoading = false;
        errorMessage = null;
        notifyListeners();

        return downloadFile.path;
      } else {
        throw Exception('Failed to retrieve file content');
      }
    } catch (e) {
      errorMessage = 'Error downloading file: $e';
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Fetch folder contents without modifying UI state (for downloads)
  Future<List<Map<String, dynamic>>> _getPrivateFolderContents({
    required int organizationId,
    required int channelId,
    required int parentFolderId,
  }) async {
    final tempKey =
        'private-$organizationId-$channelId-$parentFolderId-${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<List<Map<String, dynamic>>>();

    _folderContentCompleters[tempKey] = {
      'completer': completer,
      'contents': [],
    };

    SocketClient().sendToMain('getPrivateFolderContents', {
      'organization_id': organizationId,
      'channel_id': channelId,
      'parent_id': parentFolderId,
      'temp_key': tempKey,
    });

    try {
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _folderContentCompleters.remove(tempKey);
          throw TimeoutException('Folder contents request timed out');
        },
      );
    } catch (e) {
      _folderContentCompleters.remove(tempKey);
      rethrow;
    }
  }

  /// Download a folder and all its contents recursively
  Future<String> downloadFolder({
    required int organizationId,
    required int channelId,
    required int folderId,
    required String folderName,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // Get the downloads directory
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Downloads directory not available');
      }

      // Create the folder structure
      final folderPath = '${downloadsDir.path}/$folderName';
      final folder = Directory(folderPath);
      await folder.create(recursive: true);

      // Recursively download all contents
      await _downloadFolderContentsRecursive(
        organizationId: organizationId,
        channelId: channelId,
        parentFolderId: folderId,
        localPath: folderPath,
      );

      isLoading = false;
      errorMessage = null;
      notifyListeners();

      return folderPath;
    } catch (e) {
      errorMessage = 'Error downloading folder: $e';
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Helper method to recursively download folder contents
  Future<void> _downloadFolderContentsRecursive({
    required int organizationId,
    required int channelId,
    required int parentFolderId,
    required String localPath,
  }) async {
    try {
      // Get folder contents without modifying UI state
      final folderContents = await _getPrivateFolderContents(
        organizationId: organizationId,
        channelId: channelId,
        parentFolderId: parentFolderId,
      );

      // Process each item in the folder
      for (var item in folderContents) {
        final isFolder = item['is_folder'] != 0;
        final itemName = item['file_name'] as String? ?? 'unnamed';

        if (isFolder) {
          // Create subfolder and recurse
          final subfolderPath = '$localPath/$itemName';
          final subfolder = Directory(subfolderPath);
          await subfolder.create(recursive: true);

          await _downloadFolderContentsRecursive(
            organizationId: organizationId,
            channelId: channelId,
            parentFolderId: item['id'] as int,
            localPath: subfolderPath,
          );
        } else {
          // Download file
          final fileType = item['file_type'] as String? ?? '';
          // Only append extension if itemName doesn't already have it
          final fullFileName =
              itemName.endsWith('.$fileType') || itemName.contains('.')
              ? itemName
              : (fileType.isNotEmpty ? '$itemName.$fileType' : itemName);
          final filePath = '$localPath/$fullFileName';

          // Request file content
          final completer = Completer<void>();
          final fileId = item['id'] as int;
          _fileOpenCompleters[fileId] = completer;

          SocketClient().sendToMain('openFile', {
            'organization_id': organizationId,
            'file_id': fileId,
          });

          // Wait for file data with timeout
          try {
            await completer.future.timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                _fileOpenCompleters.remove(fileId);
                throw Exception('File download timed out: $itemName');
              },
            );

            // Save the file
            if (openFiles.containsKey(fileId)) {
              final fileData = openFiles[fileId]!;
              final fileContent = fileData['file_content'] as String? ?? '';
              final decodedBytes = base64Decode(fileContent);
              final file = File(filePath);
              await file.writeAsBytes(decodedBytes);
            }
          } catch (e) {
            print('Warning: Failed to download $itemName: $e');
            // Continue with next file instead of failing entirely
          }
        }
      }
    } catch (e) {
      print('Error downloading folder contents: $e');
      rethrow;
    }
  }
}
