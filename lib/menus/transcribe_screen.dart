import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:sprintf/sprintf.dart';
import 'package:flutter/services.dart' show rootBundle;

class TranscribeScreen extends StatefulWidget {
  final Function(String) onMusicSelected;
  final Function(String) onAssFileSelected;

  const TranscribeScreen({
    required this.onMusicSelected,
    required this.onAssFileSelected,
    Key? key,
  }) : super(key: key);

  @override
  _TranscribeScreenState createState() => _TranscribeScreenState();
}

class _TranscribeScreenState extends State<TranscribeScreen> {
  String? _backgroundMusicPath;
  String? _assFilePath;
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

  void _pickAssFile() async {
    setState(() {
      _isLoading = true;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ass'],
    );

    setState(() {
      _isLoading = false;
      if (result != null && result.files.single.path != null) {
        _assFilePath = result.files.single.path;
        widget.onAssFileSelected(_assFilePath!);
      }
    });
  }

  Future<void> _generateAssFile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String jsonString =
          await rootBundle.loadString('lib/assets/response_transcription.json');
      if (jsonString.isNotEmpty) {
        Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        String assFilePath = await _createAssFileFromJson(jsonMap);
        setState(() {
          _assFilePath = assFilePath;
          widget.onAssFileSelected(_assFilePath!);
        });
      } else {
        _showError('Transcription JSON content is empty.');
      }
    } catch (e) {
      _showError('An error occurred while generating the ASS file.');
      print(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _createAssFileFromJson(Map<String, dynamic> jsonMap) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String tempDir = directory.path;
    final String assFilePath = '$tempDir/generated_subtitles.ass';
    final File assFile = File(assFilePath);
    IOSink sink = assFile.openWrite();

    // Write [Script Info] section
    sink.writeln('[Script Info]');
    sink.writeln('Title: Transcription');
    sink.writeln('ScriptType: v4.00+');
    sink.writeln('Collisions: Normal');
    sink.writeln('PlayDepth: 0');
    sink.writeln('Timer: 100.0000');

    // Write [V4+ Styles] section with red background, curved border, and centered text
    sink.writeln('[V4+ Styles]');
    sink.writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');

    // Updated Style to create red background and capitalized words
    sink.writeln(
        'Style: Default,Arial,24,&H00FFFFFF,&H00FFFFFF,&H00000000,&HFF0000FF,0,0,0,0,100,100,0,0,3,3,2,5,10,10,10,1');
    // Style attributes:
    // - `Fontsize`: 24 for a larger subtitle size
    // - `PrimaryColour`: White text (`&H00FFFFFF`)
    // - `OutlineColour`: Black outline (`&H00000000`)
    // - `BackColour`: Red background (`&HFF0000FF`)
    // - `BorderStyle`: 3 (creates a box around the text)
    // - `Outline`: 3 (thick enough to be visible and act as a border)
    // - `Shadow`: 2 (optional shadow for effect)
    // - `Alignment`: 5 (centered both horizontally and vertically)

    // Write [Events] section
    sink.writeln('[Events]');
    sink.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    // Write each word as a dialogue with center alignment (\an5)
    for (var word in jsonMap['words']) {
      String start = _formatTime(word['start']);
      String end = _formatTime(word['end']);

      // Convert each word to uppercase
      String text = word['word'].replaceAll('\n', ' ').toUpperCase();

      // Add \an5 to center the text on the screen
      sink.writeln('Dialogue: 0,${start},${end},Default,,0,0,0,,{\an5}${text}');
    }

    await sink.close();
    print('ASS file created: $assFilePath');
    return assFilePath;
  }

  String _formatTime(double time) {
    int hours = time ~/ 3600;
    int minutes = (time % 3600) ~/ 60;
    int seconds = (time % 60).toInt();
    int milliseconds = ((time % 1) * 100).toInt();

    return sprintf(
        '%01d:%02d:%02d.%02d', [hours, minutes, seconds, milliseconds]);
  }

  void _showError(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
            if (_assFilePath != null) Text('Selected ASS file: $_assFilePath'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickBackgroundMusic,
              child: Text('Pick Background Music'),
            ),
            ElevatedButton(
              onPressed: _pickAssFile,
              child: Text('Pick ASS File'),
            ),
            ElevatedButton(
              onPressed: _generateAssFile,
              child: Text('Generate ASS File'),
            ),
            if (_isLoading) CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
