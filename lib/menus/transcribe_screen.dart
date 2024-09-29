import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

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
  String? _audioFilePath;
  String? _assFileName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _backgroundMusicFileName = widget.backgroundMusicFileName;
    _assFileName = widget.assFileName;
  }

  // Store background music in the "ShortsComposer" folder
  Future<void> _pickBackgroundMusic() async {
    setState(() {
      _isLoading = true;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );

    if (result != null && result.files.single.path != null) {
      String pickedFilePath = result.files.single.path!;
      Directory? directory = await _getStorageDirectory();

      if (directory != null) {
        String folderName = "ShortsComposer";
        Directory appDir = Directory('${directory.path}/$folderName');
        if (!(await appDir.exists())) {
          await appDir.create(recursive: true);
        }

        String newFilePath = '${appDir.path}/${p.basename(pickedFilePath)}';
        File file = File(pickedFilePath);
        await file.copy(newFilePath);

        setState(() {
          _backgroundMusicFileName = p.basename(newFilePath);
          widget.onMusicSelected(newFilePath);
        });

        print('Stored background music at: $newFilePath');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Pick audio file for transcription
  Future<void> _pickAudioFile() async {
    setState(() {
      _isLoading = true;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioFilePath = result.files.single.path;
        print('Selected audio file path: $_audioFilePath');
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Send file to Deepgram and generate .ASS file
  Future<void> _transcribeAudio() async {
    if (_audioFilePath == null) {
      print('No audio file selected');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String contentType;
      if (_audioFilePath!.endsWith('.mp3')) {
        contentType = 'audio/mpeg';
      } else if (_audioFilePath!.endsWith('.wav')) {
        contentType = 'audio/wav';
      } else {
        print('Unsupported file type');
        return;
      }

      File file = File(_audioFilePath!);
      List<int> fileBytes = await file.readAsBytes();

      Uri url = Uri.parse(
          'https://api.deepgram.com/v1/listen?smart_format=true&model=nova-2&language=en-IN');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token 93428f9f5eebe66f5cbf598a51e8549793d76eb3',
          'Content-Type': contentType,
        },
        body: fileBytes,
      );

      print('Response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = jsonDecode(response.body);
        List<dynamic> words =
            responseBody['results']['channels'][0]['alternatives'][0]['words'];
        String assFilePath = await _createAssFileFromApi(words);
        setState(() {
          _assFileName = p.basename(assFilePath);
          widget.onAssFileSelected(assFilePath);
        });
      } else {
        print('Error: ${response.body}');
        _showError('Error: ${response.body}');
      }
    } catch (e) {
      _showError('An error occurred: $e');
      print('Exception: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Store .ASS file in the "ShortsComposer" folder
  Future<String> _createAssFileFromApi(List<dynamic> words) async {
    Directory? directory = await _getStorageDirectory();

    final String folderName = "ShortsComposer";
    final Directory appDir = Directory('${directory!.path}/$folderName');

    if (!(await appDir.exists())) {
      await appDir.create(recursive: true);
    }

    final String assFilePath = '${appDir.path}/generated_subtitles.ass';
    final File assFile = File(assFilePath);
    IOSink sink = assFile.openWrite();

    final String fontName = "impact";
    final int fontSize = 20;
    final String primaryColor = "&H00FFFFFF";
    final String backColor = "&H0000FFFF";
    final String outlineColor = "&H00000000";
    final int outlineThickness = 20;
    final int shadowThickness = 20;
    final int alignment = 2;
    final int bold = -1;
    final int verticalMargin = 100;

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
        'Style: Default,$fontName,$fontSize,$primaryColor,$primaryColor,$outlineColor,$backColor,$bold,0,0,0,100,100,0,0,3,$outlineThickness,$shadowThickness,$alignment,10,10,$verticalMargin,1');

    sink.writeln('[Events]');
    sink.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    for (var word in words) {
      String start = _formatTime(word['start']);
      String end = _formatTime(word['end']);
      String text = word['punctuated_word'].replaceAll('\n', ' ').toUpperCase();

      print('Writing subtitle: Start: $start, End: $end, Text: $text');
      sink.writeln(
          'Dialogue: 0,${start},${end},Default,,0,0,$verticalMargin,,{\an2}${text}');
    }

    await sink.close();
    print(
        'ASS file created. Path: $assFilePath, Size: ${assFile.lengthSync()} bytes');
    return assFilePath;
  }

  Future<Directory?> _getStorageDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
    return null;
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
            if (_audioFilePath != null)
              Text('Selected audio file: ${p.basename(_audioFilePath!)}'),
            if (_assFileName != null) Text('Generated ASS file: $_assFileName'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickBackgroundMusic,
              child: Text('Pick Background Music'),
            ),
            ElevatedButton(
              onPressed: _pickAudioFile,
              child: Text('Pick Audio File (MP3/WAV)'),
            ),
            ElevatedButton(
              onPressed: _transcribeAudio,
              child: Text('Generate ASS from Deepgram'),
            ),
            if (_isLoading) CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
