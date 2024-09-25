import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart'; // For loading assets
import 'package:open_filex/open_filex.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FFmpeg Subtitle Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: VideoSubtitleTestScreen(),
    );
  }
}

class VideoSubtitleTestScreen extends StatefulWidget {
  @override
  _VideoSubtitleTestScreenState createState() =>
      _VideoSubtitleTestScreenState();
}

class _VideoSubtitleTestScreenState extends State<VideoSubtitleTestScreen> {
  String? videoFilePath;
  String? subtitleFilePath;
  String? outputVideoPath;
  bool isProcessing = false;
  bool isAssSubtitle = false; // Flag to check if the subtitle is .ass or .srt

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );
    if (result != null) {
      setState(() {
        videoFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _pickSubtitle() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['ass', 'srt'],
      type: FileType.custom,
    );
    if (result != null) {
      setState(() {
        subtitleFilePath = result.files.single.path;
        isAssSubtitle =
            subtitleFilePath!.endsWith('.ass'); // Check the extension
      });
    }
  }

  Future<void> _testVideoWithSubtitles() async {
    if (videoFilePath == null || subtitleFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select both video and subtitle files'),
        ),
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      // Use getExternalStorageDirectory() safely
      final Directory? externalDirectory = await getExternalStorageDirectory();

      if (externalDirectory == null) {
        throw Exception('Unable to access external storage.');
      }

      final String outputFilePath =
          '${externalDirectory.path}/output_video_with_subtitles.mp4';

      // Load the font from the assets if using .ass subtitle
      String? fontDir;
      if (isAssSubtitle) {
        final fontData = await rootBundle.load('lib/assets/Verdana.ttf');
        final fontPath = '${(await getTemporaryDirectory()).path}/Verdana.ttf';
        final fontFile = File(fontPath);
        await fontFile.writeAsBytes(fontData.buffer.asUint8List());
        fontDir = fontFile.parent.path; // Get the font directory path
      }

      // Prepare subtitle path and FFmpeg command based on subtitle type (.srt or .ass)
      String subtitleCommand;
      if (isAssSubtitle) {
        subtitleCommand =
            'ass=$subtitleFilePath:fontsdir=$fontDir'; // For .ass with the font directory
      } else {
        subtitleCommand = 'subtitles=$subtitleFilePath'; // For .srt subtitle
      }

      // FFmpeg command to overlay subtitles onto the video
      final ffmpegCommand = [
        '-y',
        '-i',
        videoFilePath!,
        '-vf',
        subtitleCommand, // Use 'ass=' if using .ass or 'subtitles=' for .srt
        '-c:v',
        'libx264',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        outputFilePath,
      ];

      print('Executing FFmpeg command: $ffmpegCommand');
      _logFFmpegCommand(ffmpegCommand); // Print full FFmpeg command

      // Execute the FFmpeg command
      var session = await FFmpegKit.execute(ffmpegCommand.join(' '));
      var returnCode = await session.getReturnCode();

      // Fetch FFmpeg logs
      var log = await session.getLogs();
      log.forEach((element) {
        print('FFmpeg log: ${element.getMessage()}');
      });

      if (ReturnCode.isSuccess(returnCode)) {
        print('FFmpeg command succeeded.');
        setState(() {
          outputVideoPath = outputFilePath;
        });
        _openGeneratedVideo(outputFilePath); // Open the video after generation
      } else {
        print('FFmpeg command failed.');
        var failLog = await session.getAllLogsAsString();
        print('FFmpeg failure log: $failLog');
      }
    } catch (e) {
      print('Error during video generation: $e');
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  // Open the generated video in the system's video player using open_filex
  Future<void> _openGeneratedVideo(String filePath) async {
    OpenFilex.open(filePath);
  }

  // Print the full FFmpeg command for logging/debugging
  void _logFFmpegCommand(List<String> command) {
    print('Full FFmpeg command: ${command.join(' ')}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subtitle Test with Assets'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickVideo,
              child: Text(videoFilePath == null
                  ? 'Pick Video File'
                  : 'Video: ${videoFilePath!.split('/').last}'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickSubtitle,
              child: Text(subtitleFilePath == null
                  ? 'Pick Subtitle File (.ass or .srt)'
                  : 'Subtitle: ${subtitleFilePath!.split('/').last}'),
            ),
            SizedBox(height: 32),
            isProcessing
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _testVideoWithSubtitles,
                    child: Text('Generate Video with Subtitles'),
                  ),
            SizedBox(height: 32),
            outputVideoPath != null
                ? Text('Output video saved at:\n$outputVideoPath')
                : Text('No output video yet.'),
          ],
        ),
      ),
    );
  }
}
