import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shorts_composer/config.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/api_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class VoiceoversScreen extends StatefulWidget {
  final List<Scene> scenes;
  final ApiService apiService;
  final Function(int, String, {bool isLocal}) onVoiceoverSelected;
  final Function(String) onAssFileGenerated;

  VoiceoversScreen({
    required this.scenes,
    required this.apiService,
    required this.onVoiceoverSelected,
    required this.onAssFileGenerated,
  });

  @override
  _VoiceoversScreenState createState() => _VoiceoversScreenState();
}

class _VoiceoversScreenState extends State<VoiceoversScreen> {
  bool _isLoading = false;
  int _loadingIndex = -1;
  String? _assFileName;
  final List<AudioPlayer> _audioPlayers = [];
  final List<bool> _isPlaying = [];

  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }

  void _initializePlayers() {
    _audioPlayers.clear();
    _isPlaying.clear();

    for (var i = 0; i < widget.scenes.length; i++) {
      _audioPlayers.add(AudioPlayer());
      _isPlaying.add(false);
    }
  }

  @override
  void didUpdateWidget(covariant VoiceoversScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scenes.length != widget.scenes.length) {
      _initializePlayers();
    }
  }

  @override
  void dispose() {
    for (var player in _audioPlayers) {
      player.dispose();
    }
    super.dispose();
  }

  // Method to pick an MP3 file using File Picker
  void _pickVoiceover(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (result != null && result.files.single.path != null) {
      widget.onVoiceoverSelected(index, result.files.single.path!,
          isLocal: true);
      await _audioPlayers[index].setFilePath(result.files.single.path!);
    }
  }

  // Method to generate the voiceover, save the file, and play it
  Future<void> _generateVoiceover(int index) async {
    setState(() {
      _isLoading = true;
      _loadingIndex = index;
    });

    try {
      final scene = widget.scenes[index];
      // Generate voiceover and get the file URL or path
      final voiceoverFilePath = await widget.apiService
          .generateVoiceover(scene.text, scene.sceneNumber);

      if (voiceoverFilePath != null) {
        widget.onVoiceoverSelected(index, voiceoverFilePath, isLocal: true);
        await _audioPlayers[index]
            .setFilePath(voiceoverFilePath); // Set the voiceover to the player
      } else {
        _showError('Failed to generate voiceover.');
      }
    } catch (e) {
      _showError('Error generating voiceover: $e');
    }

    setState(() {
      _isLoading = false;
      _loadingIndex = -1;
    });
  }

  Future<void> _transcribeAndGenerateAss(String audioFilePath) async {
    setState(() {
      _isLoading = true;
    });

    try {
      String contentType;
      if (audioFilePath.endsWith('.mp3')) {
        contentType = 'audio/mpeg';
      } else if (audioFilePath.endsWith('.wav')) {
        contentType = 'audio/wav';
      } else {
        print('Unsupported file type');
        return;
      }

      File file = File(audioFilePath);
      List<int> fileBytes = await file.readAsBytes();

      Uri url = Uri.parse(
          'https://api.deepgram.com/v1/listen?smart_format=true&model=nova-2&language=en-IN');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token ${Config.transcribeVoiceoversToken}',
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
          widget.onAssFileGenerated(assFilePath);
          print('Generated .ass file: $_assFileName');
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

  Future<Directory?> _getStorageDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
    return null;
  }

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

    // Writing Script Info
    sink.writeln('[Script Info]');
    sink.writeln('Title: Transcription');
    sink.writeln('ScriptType: v4.00+');
    sink.writeln('Collisions: Normal');
    sink.writeln('PlayDepth: 0');
    sink.writeln('Timer: 100.0000');

    // Writing Styles
    sink.writeln('[V4+ Styles]');
    sink.writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    sink.writeln(
        'Style: Default,$fontName,$fontSize,$primaryColor,$primaryColor,$outlineColor,$backColor,$bold,0,0,0,100,100,0,0,1,$outlineThickness,$shadowThickness,$alignment,10,10,$verticalMargin,1');

    // Writing Events
    sink.writeln('[Events]');
    sink.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    // Writing dialogue lines
    for (var word in words) {
      String start = _formatTime(word['start']);
      String end = _formatTime(word['end']);
      String text = word['punctuated_word'].replaceAll('\n', ' ').toUpperCase();

      print('Writing subtitle: Start: $start, End: $end, Text: $text');
      // Adjusted alignment \an2 ensures bottom center alignment
      sink.writeln(
          'Dialogue: 0,$start,$end,Default,,0,0,$verticalMargin,,{\\an2}$text');
    }

    await sink.close();
    print(
        'ASS file created. Path: $assFilePath, Size: ${assFile.lengthSync()} bytes');
    return assFilePath;
  }

// Helper function to format time as HH:MM:SS.xx
  String _formatTime(double time) {
    int hours = time ~/ 3600;
    int minutes = (time % 3600) ~/ 60;
    int seconds = (time % 60).toInt();
    int milliseconds = ((time % 1) * 100).toInt();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
  }

  // Method to combine voiceovers into a single audio file
  Future<String?> _combineVoiceovers() async {
    Directory directory = await getApplicationDocumentsDirectory();
    String outputPath = '${directory.path}/combined_voiceover.mp3';

    // Create a list of voiceover file paths
    List<String> voiceoverFiles = widget.scenes
        .where((scene) => scene.voiceoverUrl != null)
        .map((scene) => scene.voiceoverUrl!)
        .toList();

    if (voiceoverFiles.isEmpty) {
      print("No voiceovers available to combine.");
      return null;
    }

    // Handle the case where there is only one voiceover file (no need to concatenate)
    if (voiceoverFiles.length == 1) {
      print("Only one voiceover file, copying it directly.");
      File inputFile = File(voiceoverFiles.first);
      await inputFile.copy(outputPath);
      return outputPath;
    }

    // Create a temporary file listing the voiceover files
    String concatFilePath = '${directory.path}/concat.txt';
    File concatFile = File(concatFilePath);
    IOSink sink = concatFile.openWrite();
    for (String filePath in voiceoverFiles) {
      sink.writeln("file '$filePath'");
    }
    await sink.close();

    // Use FFmpeg concat protocol to combine the audio files
    String ffmpegCommand =
        '-y -f concat -safe 0 -i "$concatFilePath" -c copy "$outputPath"';

    print("Executing FFmpeg command: $ffmpegCommand");

    final session = await FFmpegKit.execute(ffmpegCommand);
    final returnCode = await session.getReturnCode();

    if (returnCode!.isValueSuccess()) {
      print("Voiceovers combined successfully at: $outputPath");
      return outputPath;
    } else {
      print("FFmpeg failed with return code: $returnCode");
      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.scenes.length,
            itemBuilder: (context, index) {
              final scene = widget.scenes[index];
              final player = _audioPlayers[index];
              return Card(
                child: ListTile(
                  title: TextField(
                    controller: TextEditingController(text: scene.text),
                    onChanged: (newText) {
                      setState(() {
                        scene.text = newText;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Scene Text',
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (scene.voiceoverUrl != null)
                        Text('Voiceover: ${scene.voiceoverUrl}')
                      else
                        Text('No Voiceover'),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _pickVoiceover(index),
                            child: Text('Pick'),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _generateVoiceover(index),
                            child: Text('Generate'),
                          ),
                        ],
                      ),
                      if (_isLoading && _loadingIndex == index)
                        LinearProgressIndicator(),
                      if (scene.voiceoverUrl != null) ...[
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(_isPlaying[index]
                                  ? Icons.pause
                                  : Icons.play_arrow),
                              onPressed: () async {
                                if (_isPlaying[index]) {
                                  await player.pause();
                                } else {
                                  await player.play();
                                }
                                setState(() {
                                  _isPlaying[index] = !_isPlaying[index];
                                });
                              },
                            ),
                            Expanded(
                              child: StreamBuilder<Duration>(
                                stream: player.positionStream,
                                builder: (context, snapshot) {
                                  final position =
                                      snapshot.data ?? Duration.zero;
                                  final duration =
                                      player.duration ?? Duration.zero;
                                  return SeekBar(
                                    duration: duration,
                                    position: position,
                                    onChangeEnd: (newPosition) {
                                      player.seek(newPosition);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            String? combinedAudioPath = await _combineVoiceovers();
            if (combinedAudioPath != null) {
              await _transcribeAndGenerateAss(combinedAudioPath);
            } else {
              _showError("No voiceovers available to combine.");
            }
          },
          child: Text('Transcribe Combined Voiceovers'),
        ),
        if (_isLoading) CircularProgressIndicator(),
      ],
    );
  }
}

class SeekBar extends StatelessWidget {
  final Duration duration;
  final Duration position;
  final ValueChanged<Duration> onChangeEnd;

  SeekBar({
    required this.duration,
    required this.position,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Slider(
      min: 0,
      max: duration.inMilliseconds.toDouble(),
      value: position.inMilliseconds
          .toDouble()
          .clamp(0, duration.inMilliseconds.toDouble()),
      onChanged: (value) {
        onChangeEnd(Duration(milliseconds: value.round()));
      },
    );
  }
}
