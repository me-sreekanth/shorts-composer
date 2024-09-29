import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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
  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Request permissions when the app starts
  }

  Future<void> _requestPermissions() async {
    // Request storage and camera permissions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    status = await Permission.photos.status;
    if (!status.isGranted) {
      await Permission.photos.request();
    }

    status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  final ApiService _apiService = ApiService();
  final VideoService _videoService = VideoService();

  int _selectedIndex = 0;
  List<Scene> _scenes = [];
  String? _assFilePath;
  String? _backgroundMusicPath;
  String? _watermarkFilePath;
  String _videoTitle = '';
  String _videoDescription = '';
  bool _isLoading = false;
  bool _isCanceled = false; // Track if the video generation is canceled

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onMusicSelected(String path) {
    setState(() {
      _backgroundMusicPath = path;
    });
    print('Background music selected: $_backgroundMusicPath'); // Debugging
  }

  Future<void> _createAndSaveVideo() async {
    setState(() {
      _isLoading = true;
      _isCanceled = false; // Reset the cancellation flag
    });

    _showLoadingDialog(); // Show the loading dialog

    try {
      print('Starting video generation...');
      _videoService.backgroundMusicPath = _backgroundMusicPath;
      _videoService.subtitlesPath = _assFilePath; // Set the subtitles path

      // Pass the scenes and _isCanceled flag to the createVideo method
      final outputPath = await _videoService.createVideo(_scenes, _isCanceled);
      print(
          'Output path generated: $outputPath'); // This should log the path to `final_video_with_subs.mp4`

      if (_isCanceled) {
        _showError('Video generation canceled.');
        return;
      }
      if (outputPath != null) {
        Navigator.pop(
            context); // Dismiss the AlertDialog when video generation is complete
        setState(() {
          _isLoading = false;
        });
        // Pass the correct videoPath (which should now be the path to the video with subtitles)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
                videoPath: outputPath,
                assFilePath: null), // No need to pass assFilePath
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

  void _cancelVideoGeneration() {
    setState(() {
      _isCanceled = true;
      Navigator.pop(
          context); // Dismiss the loading dialog when cancel is pressed
    });
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
          actions: [
            TextButton(
              onPressed: _cancelVideoGeneration,
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Widget _getScreenWidget(int index) {
    switch (index) {
      case 0:
        return ScenesScreen(
          scenes: _scenes,
          onDescriptionChanged: (index, newDescription) {
            setState(() {
              _scenes[index].updateDescription(newDescription);
            });
          },
          onImageSelected: (index, imagePath, {isLocal = false}) {
            setState(() {
              _scenes[index].updateImageUrl(imagePath, isLocal: isLocal);
            });
          },
          onGenerateImage: (index) async {
            final scene = _scenes[index];
            final processId = await _apiService.generateImage(
                scene.description, scene.sceneNumber);
            if (processId != null) {
              final imageUrl = await _apiService.fetchStatus(processId);
              if (imageUrl != null) {
                final localImagePath = await _apiService.downloadImage(
                    imageUrl, scene.sceneNumber);
                setState(() {
                  _scenes[index].updateImageUrl(localImagePath, isLocal: true);
                });
              }
            }
          },
        );
      case 1:
        return VoiceoversScreen(
          scenes: _scenes,
          apiService: _apiService,

          // Handle the generated .ass file and update _assFilePath
          onAssFileGenerated: (String assFilePath) {
            setState(() {
              _assFilePath = assFilePath;
            });
            print('ASS File Generated: $assFilePath');
          },

          // Handle voiceover selection
          onVoiceoverSelected: (index, voiceoverUrl, {isLocal = false}) {
            setState(() {
              _scenes[index].updateVoiceoverUrl(voiceoverUrl, isLocal: isLocal);
            });
            print('Voiceover selected for scene $index: $voiceoverUrl');
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
          watermarkFileName: _watermarkFilePath != null
              ? p.basename(_watermarkFilePath!)
              : null,
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
}
