import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/api_service.dart';
import 'package:shorts_composer/services/video_service.dart';
import 'package:shorts_composer/menus/preview_screen.dart';
import 'package:shorts_composer/menus/scenes_screen.dart';
import 'package:shorts_composer/menus/voiceovers_screen.dart';
import 'package:shorts_composer/menus/transcribe_screen.dart';
import 'package:shorts_composer/menus/watermarks_screen.dart';
import 'package:shorts_composer/menus/upload_screen.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ScaffoldMessenger(
        child: Scaffold(
          body: AppBody(),
        ),
      ),
    );
  }
}

class AppBody extends StatefulWidget {
  @override
  _AppBodyState createState() => _AppBodyState();
}

class _AppBodyState extends State<AppBody> {
  final ApiService _apiService = ApiService();
  final VideoService _videoService = VideoService();

  int _selectedIndex = 0;
  List<Scene> _scenes = [];
  String? _assFilePath;
  String? _backgroundMusicPath;
  String _videoTitle = ''; // Add video title
  String _videoDescription = ''; // Add video description
  bool _isLoading = false;

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

  void _onImageSelected(int index, String imagePath, {bool isLocal = false}) {
    setState(() {
      _scenes[index].updateImageUrl(imagePath, isLocal: isLocal);
    });
  }

  Future<void> _onGenerateImage(int index) async {
    final scene = _scenes[index];
    final processId =
        await _apiService.generateImage(scene.description, scene.sceneNumber);
    if (processId != null) {
      final imageUrl = await _apiService.fetchStatus(processId);
      if (imageUrl != null) {
        final localImagePath =
            await _apiService.downloadImage(imageUrl, scene.sceneNumber);
        _onImageSelected(index, localImagePath, isLocal: true);
      }
    }
  }

  void _onMusicSelected(String path) {
    setState(() {
      _backgroundMusicPath = path;
    });
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
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _createAndSaveVideo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final outputPath = await _videoService.createVideo(_scenes);
      if (outputPath != null) {
        setState(() {
          _isLoading = false;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PreviewScreen(videoPath: outputPath, assFilePath: _assFilePath),
          ),
        );
      } else {
        _showError('Failed to create video.');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError('Error creating video: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Generating video... Please wait.'),
            ],
          ),
        );
      },
    );
  }

  Widget _getScreenWidget(int index) {
    switch (index) {
      case 0:
        return ScenesScreen(
          scenes: _scenes,
          onDescriptionChanged: _onDescriptionChanged,
          onImageSelected: _onImageSelected,
          onGenerateImage: _onGenerateImage,
        );
      case 1:
        return VoiceoversScreen(
          scenes: _scenes,
          apiService: _apiService,
          onVoiceoverSelected: (index, voiceoverUrl, {isLocal = false}) {
            setState(() {
              _scenes[index].updateVoiceoverUrl(voiceoverUrl, isLocal: isLocal);
            });
          },
        );
      case 2:
        return TranscribeScreen(
          onMusicSelected: _onMusicSelected,
          onAssFileSelected: (path) {
            setState(() {
              _assFilePath = path;
            });
          },
          backgroundMusicFileName: _backgroundMusicPath != null
              ? p.basename(_backgroundMusicPath!)
              : null,
          assFileName: _assFilePath != null ? p.basename(_assFilePath!) : null,
        );
      case 3:
        return WatermarksScreen(
          videoService: _videoService,
        );
      case 4:
        return UploadScreen(
          initialTitle: _videoTitle,
          initialDescription: _videoDescription,
        );
      default:
        return Center(child: Text("Invalid selection."));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compose"),
        actions: [
          IconButton(
            icon: Icon(Icons.video_library),
            onPressed: () {
              _showLoadingDialog();
              _createAndSaveVideo();
            },
          ),
        ],
      ),
      body: _getScreenWidget(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.image), label: 'Scenes', tooltip: 'Add scenes'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadJson,
        child: Icon(Icons.upload_file),
      ),
    );
  }
}
