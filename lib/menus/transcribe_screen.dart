import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class TranscribeScreen extends StatefulWidget {
  final Function(String) onMusicSelected;

  const TranscribeScreen({required this.onMusicSelected, Key? key})
      : super(key: key);

  @override
  _TranscribeScreenState createState() => _TranscribeScreenState();
}

class _TranscribeScreenState extends State<TranscribeScreen> {
  String? _backgroundMusicPath;
  bool _isPlaying = false;
  bool _isLoading = false;

  void _pickBackgroundMusic() async {
    setState(() {
      _isLoading = true;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );

    setState(() {
      _isLoading = false;
      if (result != null && result.files.single.path != null) {
        _backgroundMusicPath = result.files.single.path;
        widget.onMusicSelected(_backgroundMusicPath!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transcribe Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_backgroundMusicPath != null)
              Text('Selected background music: $_backgroundMusicPath'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickBackgroundMusic,
              child: Text('Pick Background Music'),
            ),
            if (_isLoading) CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
