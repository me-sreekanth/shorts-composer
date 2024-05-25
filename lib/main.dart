import 'dart:convert';
import 'dart:io';

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
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  int _selectedIndex = 0;
  List<Scene> _scenes = [];

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
      _scenes[index].updateImageUrl(imageUrl);
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
          print('JSON Content (bytes): $jsonString');
          if (jsonString.isNotEmpty) {
            Map<String, dynamic> jsonMap = jsonDecode(jsonString);
            _processJson(jsonMap);
          } else {
            _showError('File content is empty.');
          }
        } else if (result.files.single.path != null) {
          File file = File(result.files.single.path!);
          String jsonString = await file.readAsString();
          print('JSON Content (file): $jsonString');
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
    });
  }

  void _showError(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _getScreenWidget(int index) {
    switch (index) {
      case 0:
        return ScenesScreen(
          scenes: _scenes,
          onDescriptionChanged: _onDescriptionChanged,
          onGenerateImage: _onGenerateImage,
        );
      case 1:
        return const VoiceoversScreen();
      case 2:
        return const TranscribeScreen();
      case 3:
        return const WatermarksScreen();
      case 4:
        return const UploadScreen();
      default:
        return Text("$index screen");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
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
