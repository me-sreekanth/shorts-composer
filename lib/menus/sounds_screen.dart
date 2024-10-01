import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SoundsScreen extends StatefulWidget {
  final Function(String) onMusicSelected;
  final String? backgroundMusicFileName;

  const SoundsScreen({
    required this.onMusicSelected,
    this.backgroundMusicFileName,
    Key? key,
  }) : super(key: key);

  @override
  _SoundsScreenState createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  String? _backgroundMusicFileName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _backgroundMusicFileName = widget.backgroundMusicFileName;
  }

  // Store background music in the "ShortsComposer" folder
  Future<void> _pickBackgroundMusic() async {
    setState(() {
      _isLoading = true;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );

    if (result != null && result.files.single.path != null) {
      String pickedFilePath = result.files.single.path!;
      Directory? directory = await _getStorageDirectory();

      if (directory != null) {
        String folderName = "ShortsComposer";
        Directory appDir = Directory('${directory.path}/$folderName');
        if (!(await appDir.exists())) {
          await appDir.create(recursive: true);
        }

        String newFilePath = '${appDir.path}/${p.basename(pickedFilePath)}';
        File file = File(pickedFilePath);
        await file.copy(newFilePath);

        setState(() {
          _backgroundMusicFileName = p.basename(newFilePath);
          widget.onMusicSelected(newFilePath);
        });

        print('Stored background music at: $newFilePath');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Get appropriate storage directory based on platform
  Future<Directory?> _getStorageDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sounds Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_backgroundMusicFileName != null)
              Text('Selected background music: $_backgroundMusicFileName'),
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
