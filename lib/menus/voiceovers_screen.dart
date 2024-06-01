import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shorts_composer/models/scene.dart';

class VoiceoversScreen extends StatefulWidget {
  final List<Scene> scenes;

  VoiceoversScreen({required this.scenes});

  @override
  _VoiceoversScreenState createState() => _VoiceoversScreenState();
}

class _VoiceoversScreenState extends State<VoiceoversScreen> {
  final Map<int, String> _voiceoverPaths = {};
  final Map<int, bool> _isLoading = {};
  final Map<int, TextEditingController> _controllers = {};
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.scenes.length; i++) {
      _controllers[i] =
          TextEditingController(text: widget.scenes[i].voiceOverText);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generateVoiceOver(int index) async {
    setState(() {
      _isLoading[index] = true;
    });

    final scene = widget.scenes[index];
    final voiceoverText = _controllers[index]?.text ?? scene.voiceOverText;
    final voiceoverPath =
        await _fetchVoiceOver(voiceoverText, scene.sceneNumber);

    setState(() {
      _isLoading[index] = false;
      if (voiceoverPath != null) {
        _voiceoverPaths[index] = voiceoverPath;
      }
    });
  }

  Future<String?> _fetchVoiceOver(String text, int sceneNumber) async {
    const apiKey = '193f83bf36e4f903ec4664616ca2ef49';
    const voiceID = 'pNInz6obpgDQGcFmaJgB';
    final outputDirectory = (await getApplicationDocumentsDirectory()).path;

    final data = {
      'text': text,
      'model_id': 'eleven_monolingual_v1',
      'voice_settings': {
        'stability': 0,
        'similarity_boost': 0,
        'style': 0,
        'use_speaker_boost': true,
      },
    };

    final response = await http.post(
      Uri.parse(
          'https://api.elevenlabs.io/v1/text-to-speech/$voiceID?optimize_streaming_latency=0&output_format=mp3_44100_128'),
      headers: {
        'accept': 'audio/mpeg',
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final filePath = '$outputDirectory/$sceneNumber-scene-voiceover.mp3';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } else {
      print('Error generating voice-over: ${response.reasonPhrase}');
      return null;
    }
  }

  void _playVoiceOver(int index) async {
    final filePath = _voiceoverPaths[index];
    if (filePath != null) {
      await _audioPlayer.setFilePath(filePath);
      _audioPlayer.play();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice-over not generated yet.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.scenes.length,
      itemBuilder: (context, index) {
        final scene = widget.scenes[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controllers[index],
                  decoration: InputDecoration(labelText: 'Voice Over Text'),
                  onChanged: (value) {
                    setState(() {
                      // Update the scene's voiceOverText in the state
                      scene.updateVoiceOverText(value);
                    });
                  },
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _generateVoiceOver(index);
                      },
                      child: _isLoading[index] == true
                          ? CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : Text('Generate Voice-over'),
                    ),
                    ElevatedButton(
                      onPressed: _voiceoverPaths.containsKey(index)
                          ? () {
                              _playVoiceOver(index);
                            }
                          : null,
                      child: Text('Play Voice-over'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
