import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sprintf/sprintf.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VideoPlayerController? _videoPlayerController;
  String? _outputVideoPath;

  Future<void> requestPermissions() async {
    if (await Permission.storage.request().isGranted) {
      // Permissions are granted, continue with the operation
    } else {
      // Permissions are denied, handle appropriately
    }
  }

  Future<String?> pickVideoFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null) {
      return result.files.single.path;
    } else {
      // User canceled the picker
      return null;
    }
  }

  Future<String> convertVideoToAudio(String videoPath) async {
    String audioPath = videoPath.replaceAll(
        '.mp4', '.m4a'); // Adjust the file extension as needed
    await FFmpegKit.execute('-i $videoPath -vn -acodec aac $audioPath');
    return audioPath;
  }

  Future<void> createAssFile(
      dynamic transcriptionData, String audioPath) async {
    String assFilePath = audioPath.replaceAll('.m4a', '.ass');
    File assFile = File(assFilePath);
    IOSink sink = assFile.openWrite();

    sink.writeln('[Script Info]');
    sink.writeln('Title: Transcription');
    sink.writeln('ScriptType: v4.00+');
    sink.writeln('Collisions: Normal');
    sink.writeln('PlayDepth: 0');
    sink.writeln('Timer: 100.0000');

    sink.writeln('[V4+ Styles]');
    sink.writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    sink.writeln(
        'Style: Default,Arial,20,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,1,0,2,10,10,10,1');

    sink.writeln('[Events]');
    sink.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    for (var word in transcriptionData['words']) {
      String start = formatTime(word['start']);
      String end = formatTime(word['end']);
      String text = word['word'].replaceAll('\n', ' ');

      sink.writeln('Dialogue: 0,${start},${end},Default,,0,0,0,,${text}');
    }

    await sink.close();
    print('ASS file created: $assFilePath');
  }

  String formatTime(double time) {
    int hours = time ~/ 3600;
    int minutes = (time % 3600) ~/ 60;
    int seconds = (time % 60).toInt();
    int milliseconds = ((time % 1) * 100).toInt();

    return sprintf(
        '%01d:%02d:%02d.%02d', [hours, minutes, seconds, milliseconds]);
  }

  Future<void> convertAndTranscribe(String videoPath) async {
    try {
      // Convert video to audio
      String audioPath = await convertVideoToAudio(videoPath);

      // Load the transcription data from the JSON file
      String jsonContent =
          await rootBundle.loadString('lib/assets/response_transcription.json');
      dynamic transcriptionData = jsonDecode(jsonContent);

      // Create ASS file using the transcription data
      await createAssFile(transcriptionData, audioPath);

      // Apply ASS file to the video
      String outputVideoPath = videoPath.replaceAll('.mp4', '_with_subs.mp4');
      String assFilePath = audioPath.replaceAll('.m4a', '.ass');
      await FFmpegKit.execute(
          '-i $videoPath -vf "ass=$assFilePath" $outputVideoPath');

      setState(() {
        _outputVideoPath = outputVideoPath;
        _videoPlayerController =
            VideoPlayerController.file(File(_outputVideoPath!))
              ..initialize().then((_) {
                setState(() {});
                _videoPlayerController?.play();
              });
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video to Audio Transcription'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await requestPermissions();
                  String? videoPath = await pickVideoFile();
                  if (videoPath != null) {
                    await convertAndTranscribe(videoPath);
                  }
                },
                child: Text('Pick Video and Transcribe'),
              ),
              if (_videoPlayerController != null &&
                  _videoPlayerController!.value.isInitialized)
                AspectRatio(
                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(_videoPlayerController!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}




// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:shorts_composer/models/scene.dart';
// import 'package:shorts_composer/services/api_service.dart';
// import 'package:shorts_composer/services/video_service.dart';
// import 'package:shorts_composer/menus/preview_screen.dart';
// import 'package:shorts_composer/menus/scenes_screen.dart';
// import 'package:shorts_composer/menus/voiceovers_screen.dart';
// import 'package:shorts_composer/menus/transcribe_screen.dart';
// import 'package:shorts_composer/menus/watermarks_screen.dart';
// import 'package:shorts_composer/menus/upload_screen.dart';

// void main() {
//   runApp(App());
// }

// class App extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: ScaffoldMessenger(
//         child: Scaffold(
//           body: AppBody(),
//         ),
//       ),
//     );
//   }
// }

// class AppBody extends StatefulWidget {
//   @override
//   _AppBodyState createState() => _AppBodyState();
// }

// class _AppBodyState extends State<AppBody> {
//   final ApiService _apiService = ApiService();
//   final VideoService _videoService = VideoService();

//   int _selectedIndex = 0;
//   List<Scene> _scenes = [];
//   String _videoTitle = '';
//   String _videoDescription = '';
//   bool _isLoading = false;
//   String _loadingText = 'Generating video...';

//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }

//   void _onDescriptionChanged(int index, String newDescription) {
//     setState(() {
//       _scenes[index].updateDescription(newDescription);
//     });
//   }

//   void _onImageSelected(int index, String imagePath, {bool isLocal = false}) {
//     setState(() {
//       _scenes[index].updateImageUrl(imagePath, isLocal: isLocal);
//     });
//   }

//   void _onVoiceoverSelected(int index, String voiceoverUrl,
//       {bool isLocal = false}) {
//     setState(() {
//       _scenes[index].updateVoiceoverUrl(voiceoverUrl, isLocal: isLocal);
//     });
//   }

//   Future<void> _onGenerateImage(int index) async {
//     final scene = _scenes[index];
//     final processId =
//         await _apiService.generateImage(scene.description, scene.sceneNumber);
//     if (processId != null) {
//       final imageUrl = await _apiService.fetchStatus(processId);
//       if (imageUrl != null) {
//         final localImagePath =
//             await _apiService.downloadImage(imageUrl, scene.sceneNumber);
//         _onImageSelected(index, localImagePath, isLocal: true);
//       }
//     }
//   }

//   Future<void> _uploadJson() async {
//     try {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['json'],
//       );

//       if (result != null) {
//         if (result.files.single.bytes != null) {
//           String jsonString = String.fromCharCodes(result.files.single.bytes!);
//           if (jsonString.isNotEmpty) {
//             Map<String, dynamic> jsonMap = jsonDecode(jsonString);
//             _processJson(jsonMap);
//           } else {
//             _showError('File content is empty.');
//           }
//         } else if (result.files.single.path != null) {
//           File file = File(result.files.single.path!);
//           String jsonString = await file.readAsString();
//           if (jsonString.isNotEmpty) {
//             Map<String, dynamic> jsonMap = jsonDecode(jsonString);
//             _processJson(jsonMap);
//           } else {
//             _showError('File content is empty.');
//           }
//         } else {
//           _showError('No valid file content.');
//         }
//       } else {
//         _showError('No file selected.');
//       }
//     } catch (e) {
//       _showError('An error occurred while uploading the JSON file.');
//       print(e);
//     }
//   }

//   void _processJson(Map<String, dynamic> jsonMap) {
//     List<Scene> scenes = (jsonMap['Scenes'] as List)
//         .map((scene) => Scene.fromJson(scene))
//         .toList();

//     setState(() {
//       _scenes = scenes;
//       _videoTitle = jsonMap['Title'];
//       _videoDescription = jsonMap['Description'];
//     });
//   }

//   void _showError(String message) {
//     final snackBar = SnackBar(content: Text(message));
//     ScaffoldMessenger.of(context).showSnackBar(snackBar);
//   }

//   Future<void> _createAndSaveVideo() async {
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final outputPath = await _videoService.createVideo(_scenes);
//       if (outputPath != null) {
//         Navigator.of(context).pop(); // Close the dialog
//         setState(() {
//           _isLoading = false;
//         });
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => PreviewScreen(videoPath: outputPath),
//           ),
//         );
//       } else {
//         _showError('Failed to create video.');
//         Navigator.of(context).pop(); // Close the dialog
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       _showError('Error creating video: $e');
//       Navigator.of(context).pop(); // Close the dialog
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   void _showLoadingDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.all(Radius.circular(10.0)),
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
//                 strokeWidth: 6.0,
//               ),
//               SizedBox(height: 20),
//               Text(
//                 _loadingText,
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               SizedBox(height: 10),
//               Text(
//                 'Please wait while we process your video.',
//                 style: TextStyle(
//                   fontSize: 16,
//                 ),
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   setState(() {
//                     _isLoading = false;
//                   });
//                 },
//                 child: Text('Cancel'),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _getScreenWidget(int index) {
//     switch (index) {
//       case 0:
//         return ScenesScreen(
//           scenes: _scenes,
//           onDescriptionChanged: _onDescriptionChanged,
//           onImageSelected: (index, path, {isLocal = false}) =>
//               _onImageSelected(index, path, isLocal: isLocal),
//           onGenerateImage: _onGenerateImage,
//         );
//       case 1:
//         return VoiceoversScreen(
//           scenes: _scenes,
//           apiService: _apiService,
//           onVoiceoverSelected: _onVoiceoverSelected,
//         );
//       case 2:
//         return TranscribeScreen(onMusicSelected: _onMusicSelected);
//       case 3:
//         return const WatermarksScreen();
//       case 4:
//         return UploadScreen(
//           initialTitle: _videoTitle,
//           initialDescription: _videoDescription,
//         );
//       default:
//         return Text("$index screen");
//     }
//   }

//   void _onMusicSelected(String path) {
//     setState(() {
//       _videoService.backgroundMusicPath = path;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Compose"),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.video_library),
//             onPressed: () {
//               _showLoadingDialog();
//               _createAndSaveVideo();
//             },
//           ),
//         ],
//       ),
//       body: _getScreenWidget(_selectedIndex),
//       bottomNavigationBar: BottomNavigationBar(
//         items: const <BottomNavigationBarItem>[
//           BottomNavigationBarItem(
//               icon: Icon(Icons.image), label: 'Scenes', tooltip: 'Add scenes'),
//           BottomNavigationBarItem(
//               icon: Icon(Icons.voice_chat),
//               label: 'Voiceovers',
//               tooltip: 'Add voiceovers'),
//           BottomNavigationBarItem(
//               icon: Icon(Icons.transcribe),
//               label: 'Transcribe',
//               tooltip: 'Generate transcriptions'),
//           BottomNavigationBarItem(
//               icon: Icon(Icons.branding_watermark),
//               label: 'Watermarks',
//               tooltip: 'Add watermarks'),
//           BottomNavigationBarItem(
//               icon: Icon(Icons.upload),
//               label: 'Upload',
//               tooltip: 'Upload to YouTube'),
//         ],
//         currentIndex: _selectedIndex,
//         selectedItemColor: Colors.amber[800],
//         unselectedItemColor: Colors.black,
//         onTap: _onItemTapped,
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _uploadJson,
//         child: Icon(Icons.upload_file),
//       ),
//     );
//   }
// }