import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class TranscribeScreen extends StatefulWidget {
  final Function(String) onMusicSelected;
  final Function(String) onAssFileSelected;
  final String? backgroundMusicFileName;
  final String? assFileName;

  const TranscribeScreen({
    required this.onMusicSelected,
    required this.onAssFileSelected,
    this.backgroundMusicFileName,
    this.assFileName,
    Key? key,
  }) : super(key: key);

  @override
  _TranscribeScreenState createState() => _TranscribeScreenState();
}

class _TranscribeScreenState extends State<TranscribeScreen> {
  String? _backgroundMusicFileName;
  String? _assFileName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _backgroundMusicFileName = widget.backgroundMusicFileName;
    _assFileName = widget.assFileName;
  }

  void _pickBackgroundMusic() async {
    setState(() {
      _isLoading = true;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _backgroundMusicFileName = p.basename(result.files.single.path!);
        widget.onMusicSelected(result.files.single.path!);
      });
    }

    setState(() {
      _isLoading = false;
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

    if (result != null && result.files.single.path != null) {
      setState(() {
        _assFileName = p.basename(result.files.single.path!);
        widget.onAssFileSelected(result.files.single.path!);
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _generateAssFile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String jsonString =
          await rootBundle.loadString('lib/assets/response_transcription.json');

      // Ensure JSON is loaded
      if (jsonString.isEmpty) {
        _showError('Error: Transcription JSON file is empty');
        return;
      }

      print('Transcription JSON file loaded successfully.');

      // Parse JSON
      Map<String, dynamic> jsonMap;
      try {
        jsonMap = jsonDecode(jsonString);
        print("Transcription JSON parsed successfully.");
      } catch (e) {
        _showError('Error parsing transcription JSON: $e');
        return;
      }

      // Check for valid words data
      if (!jsonMap.containsKey('words') || jsonMap['words'].isEmpty) {
        _showError("Error: 'words' data is missing or empty in the JSON.");
        return;
      }

      print("Words data exists and is valid.");

      // Create and write to ASS file
      String assFilePath = await _createAssFileFromJson(jsonMap);
      setState(() {
        _assFileName = p.basename(assFilePath);
        widget.onAssFileSelected(assFilePath);
      });
    } catch (e) {
      _showError('An error occurred while generating the ASS file: $e');
      print(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _createAssFileFromJson(Map<String, dynamic> jsonMap) async {
    Directory? directory;

    // Android specific: Use external storage
    if (Platform.isAndroid) {
      directory =
          await getExternalStorageDirectory(); // External storage directory
    } else if (Platform.isIOS) {
      directory =
          await getApplicationDocumentsDirectory(); // iOS Documents directory
    }

    final String folderName = "ShortsComposer";
    final Directory appDir = Directory('${directory!.path}/$folderName');

    // Create directory if it doesn't exist
    if (!(await appDir.exists())) {
      await appDir.create(recursive: true);
    }

    final String assFilePath = '${appDir.path}/generated_subtitles.ass';
    final File assFile = File(assFilePath);
    IOSink sink = assFile.openWrite();

    // Customizable variables
    final String fontName = "Verdana";
    final int fontSize = 16;
    final String primaryColor = "&H00FFFFFF"; // White text
    final String backColor = "&H0000FFFF"; // Semi-transparent yellow background
    final String outlineColor = "&H00000000"; // Black outline
    final int outlineThickness = 20; // Thin outline to simulate border
    final int shadowThickness = 20; // Shadow to simulate curved edges
    final int alignment = 2; // Bottom-center
    final int bold = -1;
    final int verticalMargin = 100;

    // Write [Script Info] section
    sink.writeln('[Script Info]');
    sink.writeln('Title: Transcription');
    sink.writeln('ScriptType: v4.00+');
    sink.writeln('Collisions: Normal');
    sink.writeln('PlayDepth: 0');
    sink.writeln('Timer: 100.0000');

    // Write [V4+ Styles] section
    sink.writeln('[V4+ Styles]');
    sink.writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    sink.writeln(
        'Style: Default,$fontName,$fontSize,$primaryColor,$primaryColor,$outlineColor,$backColor,$bold,0,0,0,100,100,0,0,3,$outlineThickness,$shadowThickness,$alignment,10,10,$verticalMargin,1');

    // Write [Events] section
    sink.writeln('[Events]');
    sink.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    // Write each word as a dialogue
    for (var word in jsonMap['words']) {
      String start = _formatTime(word['start']);
      String end = _formatTime(word['end']);
      String text = word['word'].replaceAll('\n', ' ').toUpperCase();

      print('Writing subtitle: Start: $start, End: $end, Text: $text');
      sink.writeln(
          'Dialogue: 0,${start},${end},Default,,0,0,$verticalMargin,,{\an2}${text}');
    }

    await sink.close();
    print(
        'ASS file created. Path: $assFilePath, Size: ${assFile.lengthSync()} bytes');
    return assFilePath;
  }

  String _formatTime(double time) {
    int hours = time ~/ 3600;
    int minutes = (time % 3600) ~/ 60;
    int seconds = (time % 60).toInt();
    int milliseconds = ((time % 1) * 100).toInt();
    return '${hours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
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
            if (_backgroundMusicFileName != null)
              Text('Selected background music: $_backgroundMusicFileName'),
            if (_assFileName != null) Text('Selected ASS file: $_assFileName'),
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
