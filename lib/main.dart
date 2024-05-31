import 'dart:convert';
import 'dart:io'; // Import this package

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shorts_composer/models/scene.dart';

import 'menus/scenes_screen.dart';
import 'menus/voiceovers_screen.dart';
import 'menus/transcribe_screen.dart';
import 'menus/watermarks_screen.dart';
import 'menus/upload_screen.dart';

void main() {
  runApp(App());
}

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  int _selectedIndex = 0;
  List<Scene> _scenes = [];
  String _videoTitle = '';
  String _videoDescription = '';

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onDescriptionChanged(int index, String newDescription) {
    setState(() {
      _scenes[index].updateDescription(newDescription);
    });
  }

  Future<void> _onGenerateImage(int index) async {
    final scene = _scenes[index];
    final imageUrl = await _fetchImageUrl(scene.description);
    setState(() {
      _scenes[index].updateImageUrl(imageUrl, isLocal: false);
    });
  }

  Future<String> _fetchImageUrl(String description) async {
    // Replace with your actual API call to fetch the image URL
    final response = await http.get(
        Uri.parse('https://example.com/api/getImage?description=$description'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['imageUrl'];
    } else {
      throw Exception('Failed to load image');
    }
  }

  Future<void> _uploadJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        if (result.files.single.bytes != null) {
          String jsonString = String.fromCharCodes(result.files.single.bytes!);
          if (jsonString.isNotEmpty) {
            Map<String, dynamic> jsonMap = jsonDecode(jsonString);
            _processJson(jsonMap);
          } else {
            _showError('File content is empty.');
          }
        } else if (result.files.single.path != null) {
          File file = File(result.files.single.path!);
          String jsonString = await file.readAsString();
          if (jsonString.isNotEmpty) {
            Map<String, dynamic> jsonMap = jsonDecode(jsonString);
            _processJson(jsonMap);
          } else {
            _showError('File content is empty.');
          }
        } else {
          _showError('No valid file content.');
        }
      } else {
        _showError('No file selected.');
      }
    } catch (e) {
      _showError('An error occurred while uploading the JSON file.');
      print(e);
    }
  }

  void _processJson(Map<String, dynamic> jsonMap) {
    List<Scene> scenes = (jsonMap['Scenes'] as List)
        .map((scene) => Scene.fromJson(scene))
        .toList();

    setState(() {
      _scenes = scenes;
      _videoTitle = jsonMap['Title'];
      _videoDescription = jsonMap['Description'];
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _onImageSelected(int index, String imagePath, bool isLocal) {
    setState(() {
      _scenes[index].updateImageUrl(imagePath,
          isLocal:
              isLocal); // Assuming you can use a file path directly, otherwise, upload the image and get the URL
    });
  }

  Widget _getScreenWidget(int index) {
    switch (index) {
      case 0:
        return ScenesScreen(
          scenes: _scenes,
          onDescriptionChanged: _onDescriptionChanged,
          onGenerateImage: _onGenerateImage,
          onImageSelected: _onImageSelected,
        );
      case 1:
        return const VoiceoversScreen();
      case 2:
        return const TranscribeScreen();
      case 3:
        return const WatermarksScreen();
      case 4:
        return UploadScreen(
          initialTitle: _videoTitle,
          initialDescription: _videoDescription,
        );
      default:
        return Text("$index screen");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Compose"),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Icon(Icons.image),
                label: 'Scenes',
                tooltip: 'Add scenes'),
            BottomNavigationBarItem(
                icon: Icon(Icons.voice_chat),
                label: 'Voiceovers',
                tooltip: 'Add voiceovers'),
            BottomNavigationBarItem(
                icon: Icon(Icons.transcribe),
                label: 'Transcribe',
                tooltip: 'Generate transcriptions'),
            BottomNavigationBarItem(
                icon: Icon(Icons.branding_watermark),
                label: 'Watermarks',
                tooltip: 'Add watermarks'),
            BottomNavigationBarItem(
                icon: Icon(Icons.upload),
                label: 'Upload',
                tooltip: 'Upload to YouTube'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.amber[800],
          unselectedItemColor: Colors.black,
          onTap: _onItemTapped,
        ),
        body: _getScreenWidget(_selectedIndex),
        floatingActionButton: FloatingActionButton(
          onPressed: _uploadJson,
          child: Icon(Icons.upload_file),
        ),
      ),
    );
  }
}
