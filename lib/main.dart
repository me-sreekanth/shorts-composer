import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shorts_composer/menus/sounds_watermark_screen.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/api_service.dart';
import 'package:shorts_composer/services/video_service.dart';
import 'package:shorts_composer/menus/preview_screen.dart';
import 'package:shorts_composer/menus/scenes_screen.dart';
import 'package:shorts_composer/menus/voiceovers_screen.dart';
import 'package:shorts_composer/menus/upload_screen.dart';
import 'package:path/path.dart' as p;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:just_audio/just_audio.dart'; // Import for audio player

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/youtube.upload',
    ],
  );

  GoogleSignInAccount? _currentUser; // Google Sign-In state
  bool _isAuthorized = false; // Track if the user is signed in

  int _selectedIndex = 0;
  List<Scene> _scenes = [];
  String? _assFilePath;
  String? _backgroundMusicPath;
  String? _watermarkFilePath;
  String? _videoFilePath; // Store the generated video path
  bool _isLoading = false;
  bool _isCanceled = false; // Track if the video generation is canceled

  // Add TextEditingControllers for title and description
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // State for combined player and transcription data
  AudioPlayer _combinedAudioPlayer = AudioPlayer();
  bool _isCombinedPlaying = false;
  String? _combinedAudioPath;
  List<Map<String, String>> _fullTranscription = [];

  // Method to check if the "Preview" button should be enabled
  bool _isPreviewEnabled() {
    // Check if all scenes have an image and a voiceover selected
    bool allScenesHaveImagesAndVoiceovers = _scenes
        .every((scene) => scene.imageUrl != null && scene.voiceoverUrl != null);

    // Check if background music and watermark are selected
    bool backgroundMusicSelected = _backgroundMusicPath != null;
    bool watermarkSelected = _watermarkFilePath != null;

    // Debugging - Add print statements to verify conditions
    print(
        'Scenes with images and voiceovers: $allScenesHaveImagesAndVoiceovers');
    print('Background music selected: $backgroundMusicSelected');
    print('Watermark selected: $watermarkSelected');

    return allScenesHaveImagesAndVoiceovers &&
        backgroundMusicSelected &&
        watermarkSelected;
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Request permissions when the app starts

    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
        _isAuthorized = account != null;
      });
    });
    _googleSignIn.signInSilently();

    // Initialize audio player
    _combinedAudioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    // Dispose the controllers and audio player when the widget is disposed
    _titleController.dispose();
    _descriptionController.dispose();
    _combinedAudioPlayer.dispose();
    super.dispose();
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

  // Google Sign-In methods
  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print('Error signing in: $error');
    }
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.disconnect();
    setState(() {
      _currentUser = null;
      _isAuthorized = false;
    });
  }

  // Navigation between different menu items
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onMusicSelected(String path) {
    setState(() {
      _backgroundMusicPath = path;
    });
    print('Background music selected: $_backgroundMusicPath');
  }

  // Handle watermark selection
  void _onWatermarkSelected(String path) {
    setState(() {
      _watermarkFilePath = path;
    });
    print('Watermark selected: $_watermarkFilePath');
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
      print('Output path generated: $outputPath');

      if (_isCanceled) {
        _showError('Video generation canceled.');
        return;
      }
      if (outputPath != null) {
        Navigator.pop(
            context); // Dismiss the AlertDialog when video generation is complete
        setState(() {
          _isLoading = false;
          _videoFilePath = outputPath; // Store the generated video path
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              videoPath: outputPath,
              assFilePath: null, // No need to pass assFilePath
            ),
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

  // Method to update the scene text in the list
  void _updateSceneText(int index, String newText) {
    setState(() {
      _scenes[index].text = newText; // Update the text of the specific scene
    });
  }

  void _onCombinedPlayerUpdate(
    AudioPlayer player,
    bool isPlaying,
    String? audioPath,
    List<Map<String, String>> transcription,
  ) {
    setState(() {
      _combinedAudioPlayer = player;
      _isCombinedPlaying = isPlaying;
      _combinedAudioPath = audioPath;
      _fullTranscription = transcription; // Update transcription data
    });
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
          apiService: ApiService(),
          combinedAudioPlayer: _combinedAudioPlayer,
          isCombinedPlaying: _isCombinedPlaying,
          combinedAudioPath: _combinedAudioPath,
          fullTranscription: _fullTranscription, // Pass the transcription data
          onAssFileGenerated: (String assFilePath) {
            setState(() {
              _assFilePath = assFilePath;
            });
          },
          onVoiceoverSelected: (int index, String voiceoverUrl,
              {bool isLocal = false}) {
            setState(() {
              _scenes[index].updateVoiceoverUrl(voiceoverUrl, isLocal: isLocal);
            });
          },
          onCombinedPlayerUpdate: _onCombinedPlayerUpdate,
          onSceneTextUpdated: _updateSceneText,
        );
      case 2:
        return SoundsWatermarkScreen(
          onMusicSelected: (String path) {
            setState(() {
              _backgroundMusicPath = path;
            });
          },
          onWatermarkSelected: (String path) {
            _onWatermarkSelected(path);
          },
          videoService: _videoService,
          backgroundMusicFileName: _backgroundMusicPath != null
              ? p.basename(_backgroundMusicPath!)
              : null,
          watermarkFileName: _watermarkFilePath != null
              ? p.basename(_watermarkFilePath!)
              : null,
        );
      case 3:
        return UploadScreen(
          generatedVideoPath: _videoFilePath ?? '',
          currentUser: _currentUser,
          isAuthenticated: _isAuthorized,
          onSignIn: _handleSignIn,
          onSignOut: _handleSignOut,
          titleController: _titleController,
          descriptionController: _descriptionController,
        );
      default:
        return Center(child: Text("Invalid selection."));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compose video"),
        actions: [
          // Add a TextButton for "Preview"
          TextButton.icon(
            onPressed: _isPreviewEnabled()
                ? () {
                    _createAndSaveVideo();
                  }
                : null, // Disable the button if conditions aren't met
            icon: Icon(Icons.visibility,
                color: _isPreviewEnabled() ? Colors.blueAccent : Colors.grey),
            label: Text(
              'Preview video',
              style: TextStyle(
                fontSize: 20,
                color: _isPreviewEnabled() ? Colors.blueAccent : Colors.grey,
              ),
            ),
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
              icon: Icon(Icons.library_music_outlined),
              label: 'Music & Watermarks',
              tooltip: 'Add background music and watermarks'),
          BottomNavigationBarItem(
              icon: Icon(Icons.upload),
              label: 'Upload',
              tooltip: 'Upload to YouTube'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.black,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
