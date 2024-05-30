import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shorts_composer/oauth2/youtube_uploader.dart';

class UploadScreen extends StatefulWidget {
  final String initialTitle;
  final String initialDescription;

  UploadScreen({
    required this.initialTitle,
    required this.initialDescription,
  });

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _videoFile;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final YouTubeUploader _uploader = YouTubeUploader(
    clientId:
        '18038789658-mifrqrpenap8vred4cfulc1pmgkco5e8.apps.googleusercontent.com',
  );

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _videoFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile != null) {
      try {
        final client = await _uploader.authenticate();
        if (client == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Authentication failed. Please try again.'),
          ));
          return;
        }
        final videoId = await _uploader.uploadVideo(
          client,
          _videoFile!.path,
          _titleController.text,
          _descriptionController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Upload successful: https://www.youtube.com/watch?v=$videoId'),
        ));
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a video file to upload.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Video'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            SizedBox(height: 20),
            _videoFile != null
                ? Text('Selected file: ${_videoFile!.path}')
                : Text('No video selected'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickVideo,
              child: Text('Select Video'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadVideo,
              child: Text('Upload Video'),
            ),
          ],
        ),
      ),
    );
  }
}
