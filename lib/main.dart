import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shorts_composer/menus/sounds_watermark_screen.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/api_service.dart';
import 'package:shorts_composer/services/config_service.dart';
import 'package:shorts_composer/services/video_service.dart';
import 'package:shorts_composer/menus/preview_screen.dart';
import 'package:shorts_composer/menus/scenes_screen.dart';
import 'package:shorts_composer/menus/voiceovers_screen.dart';
import 'package:shorts_composer/menus/upload_screen.dart';
import 'package:path/path.dart' as p;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lottie/lottie.dart'; // Import Lottie package

void main() async {
  try {
    await ConfigService.loadConfig();
    runApp(App());
  } catch (e) {
    print('Failed to load configuration: $e');
    runApp(ErrorApp(e.toString())); // Render a fallback UI
  }
  enableDebugLogging();
}

void enableDebugLogging() {
  FFmpegKitConfig.enableLogCallback((log) {
    print("FFmpeg Log: ${log.getMessage()}");
  });

  FFmpegKitConfig.enableStatisticsCallback((statistics) {
    print("FFmpeg Statistics: ${statistics.toString()}");
  });
}

class ErrorApp extends StatelessWidget {
  final String errorMessage;

  const ErrorApp(this.errorMessage, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Error: $errorMessage'),
        ),
      ),
    );
  }
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: ConfigService.loadConfig(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Failed to load configuration: ${snapshot.error}'),
              ),
            );
          }
          return AppBody(); // Proceed with the main app UI
        },
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
    scopes: [
      'email',
      'https://www.googleapis.com/auth/youtube.upload',
      'https://www.googleapis.com/auth/youtube.readonly',
    ],
  );

  GoogleSignInAccount? _currentUser;
  bool _isAuthorized = false;

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
  }

  @override
  void dispose() {
    // Dispose the controllers and audio player when the widget is disposed
    _titleController.dispose();
    _descriptionController.dispose();
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
      _isCanceled = false;
    });

    _showProgressDialog(); // Show progress dialog

    try {
      _videoService.backgroundMusicPath = _backgroundMusicPath;
      _videoService.subtitlesPath = _assFilePath;

      final outputPath = await _videoService.createVideo(_scenes, _isCanceled);

      if (_isCanceled) {
        _showError('Video generation canceled.');
        Navigator.pop(context); // Close the dialog if canceled
        return;
      }

      if (outputPath != null) {
        Navigator.pop(context); // Close the progress dialog

        setState(() {
          _isLoading = false;
          _videoFilePath = outputPath;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              videoPath: outputPath,
              assFilePath: null,
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
      Navigator.pop(context); // Ensure the dialog is dismissed on error
      _showError('Error creating video: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ValueListenableBuilder<String>(
          valueListenable: _videoService.progressNotifier,
          builder: (context, progress, child) {
            return AlertDialog(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              content: Container(
                width: 300, // Set width and height equal for a square dialog
                height: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Generating Video',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // SizedBox(height: 20),
                    // Lottie animation centered
                    Lottie.asset(
                      'lib/assets/animations/progress_animation.json', // Replace with your Lottie animation file path
                      width: 160,
                      height: 160,
                    ),
                    // SizedBox(height: 20), // Space below the animation

                    // Status text below the Lottie animation
                    Text(
                      progress,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center, // Center align the text
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _cancelVideoGeneration,
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _cancelVideoGeneration() {
    setState(() {
      _isCanceled = true;
      Navigator.pop(
          context); // Dismiss the loading dialog when cancel is pressed
    });
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

      // case 0:
      //   return TextToSpeechScreen();
      case 1:
        return VoiceoversScreen(
          scenes: _scenes,
          apiService: ApiService(),
          onVoiceoverSelected: (int index, String voiceoverUrl,
              {bool isLocal = false}) {
            setState(() {
              _scenes[index].updateVoiceoverUrl(voiceoverUrl, isLocal: isLocal);
            });
          },
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
        return _isAuthorized
            ? UploadScreen(
                generatedVideoPath: _videoFilePath ?? '',
                currentUser: _currentUser,
                isAuthenticated: _isAuthorized,
                onSignIn: _handleSignIn,
                onSignOut: _handleSignOut,
                titleController: _titleController,
                descriptionController: _descriptionController,
              )
            : Center(
                child: ElevatedButton(
                  onPressed: _handleSignIn,
                  child: Text('Sign In with Google'),
                ),
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
              'Preview',
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
