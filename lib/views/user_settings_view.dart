import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';
import 'package:image/image.dart' as img;
import 'package:libre_organization_client/credentials.dart';
import 'package:libre_organization_client/socket_client.dart';
import 'package:libre_organization_client/presenters/organization_presenter.dart';

class UserSettingsView extends StatefulWidget {
  const UserSettingsView({Key? key}) : super(key: key);

  @override
  State<UserSettingsView> createState() => _UserSettingsViewState();
}

class _UserSettingsViewState extends State<UserSettingsView> {
  late TextEditingController _usernameController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final OrganizationPresenter _presenter = OrganizationPresenter();
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: _presenter.currentUser?['default_name'] ?? '',
    );
    _presenter.addListener(_onPresenterUpdate);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _onPresenterUpdate() {
    if (mounted) {
      _usernameController.text = _presenter.currentUser?['default_name'] ?? '';
      // When the presenter updates (e.g., after a profile update),
      // stop the loading indicator and rebuild the UI.
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUsername() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      SocketClient().sendToMain('updateUser', {
        'user_id': Credentials().userId,
        'default_name': _usernameController.text.trim(),
      });

      // You might want to listen for a confirmation event from the server
      // For now, we'll just show a snackbar and stop loading.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Username update sent!')));

      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result?.files.single.path != null) {
      final imageBytes = await File(result!.files.single.path!).readAsBytes();

      // Navigate to a new screen for cropping
      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => _CropScreen(imageBytes: imageBytes),
          fullscreenDialog: true,
        ),
      );

      if (croppedBytes != null) {
        setState(() {
          _isLoading = true;
          _imageBytes = croppedBytes;
        });
        final fileContent = base64Encode(croppedBytes);

        SocketClient().sendToMain('updateUserProfileImage', {
          'user_id': Credentials().userId,
          'image_content': fileContent,
        });

        // The presenter will receive an update and notify listeners
        // which will rebuild the UI and stop the loading indicator
        // in _onPresenterUpdate.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pfpPath = _presenter.currentUser?['pfp_path'];
    return Scaffold(
      appBar: AppBar(title: Text('User Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Edit Profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Text(
                'Profile Picture',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_imageBytes != null)
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: MemoryImage(_imageBytes!),
                    )
                  else if (pfpPath != null)
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(
                        'http://localhost:3000/user_files${pfpPath}',
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _pickAndUploadImage,
                    child: Text('Upload Image'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Username', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Enter new username',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateUsername,
                child: _isLoading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : Text('Save Username'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const _CropScreen({required this.imageBytes});

  @override
  State<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<_CropScreen> {
  late final CropController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CropController(
      aspectRatio: 1,
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
  }

  Future<void> _cropAndFinish() async {
    try {
      // The `_controller.croppedImage()` method is causing a persistent and
      // unusual type conflict. To work around this, we will perform the crop
      // manually using the 'image' package, which is more reliable.

      // 1. Decode the original image bytes.
      final originalImage = img.decodeImage(widget.imageBytes);
      if (originalImage == null) {
        throw Exception('Could not decode image.');
      }

      // 2. Get the crop rectangle from the controller (values are 0.0 to 1.0).
      final cropRect = _controller.crop;

      // 3. Convert the relative crop rectangle to absolute pixel values.
      final cropX = (cropRect.left * originalImage.width).round();
      final cropY = (cropRect.top * originalImage.height).round();
      final cropWidth = (cropRect.width * originalImage.width).round();
      final cropHeight = (cropRect.height * originalImage.height).round();

      // 4. Perform the crop using the 'image' package.
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // 5. Encode the newly cropped image to PNG bytes.
      final croppedBytes = Uint8List.fromList(img.encodePng(croppedImage));

      // 6. Return the cropped bytes.
      Navigator.pop(context, croppedBytes);
    } catch (e) {
      print('Error during manual crop: $e');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        actions: [
          IconButton(onPressed: _cropAndFinish, icon: const Icon(Icons.check)),
        ],
      ),
      body: Center(
        child: CropImage(
          controller: _controller,
          image: Image.memory(widget.imageBytes),
        ),
      ),
    );
  }
}
