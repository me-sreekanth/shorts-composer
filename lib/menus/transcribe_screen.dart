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
      if (jsonString.isNotEmpty) {
        Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        String assFilePath = await _createAssFileFromJson(jsonMap);
        setState(() {
          _assFileName = p.basename(assFilePath);
          widget.onAssFileSelected(assFilePath);
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

    // Customizable variables
    final String fontName = "Verdana";
    final int fontSize = 16;
    final String primaryColor = "&H00FFFFFF"; // White text
    final String backColor = "&H0000FFFF"; // Semi-transparent yellow background
    final String outlineColor = "&H00000000"; // Black outline
    final int outlineThickness = 2; // Thin outline to simulate border
    final int shadowThickness = 2; // Shadow to simulate curved edges
    final int alignment = 2; // Bottom-center
    final int bold = -1; // -1 means bold text
    final int verticalMargin =
        100; // Adjust this to position slightly below the center

    // Write [Script Info] section
    sink.writeln('[Script Info]');
    sink.writeln('Title: Transcription');
    sink.writeln('ScriptType: v4.00+');
    sink.writeln('Collisions: Normal');
    sink.writeln('PlayDepth: 0');
    sink.writeln('Timer: 100.0000');

    // Write [V4+ Styles] section using customizable variables with `BorderStyle` 3 to create a background box
    sink.writeln('[V4+ Styles]');
    sink.writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');

    sink.writeln(
        'Style: Default,$fontName,$fontSize,$primaryColor,$primaryColor,$outlineColor,$backColor,$bold,0,0,0,100,100,0,0,3,$outlineThickness,$shadowThickness,$alignment,10,10,$verticalMargin,1');
    // - `Alignment=2` ensures the text is horizontally centered below the centerline.
    // - `MarginV=$verticalMargin` controls the vertical distance from the middle of the screen.

    // Write [Events] section
    sink.writeln('[Events]');
    sink.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    // Write each word as a dialogue with center alignment just below the center
    for (var word in jsonMap['words']) {
      String start = _formatTime(word['start']);
      String end = _formatTime(word['end']);

      // Convert each word to uppercase
      String text = word['word'].replaceAll('\n', ' ').toUpperCase();

      // Add \an2 to center the text horizontally, below the centerline
      sink.writeln(
          'Dialogue: 0,${start},${end},Default,,0,0,$verticalMargin,,{\an2}${text}');
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
