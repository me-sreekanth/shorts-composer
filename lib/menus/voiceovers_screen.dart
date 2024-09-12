import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/api_service.dart';
import 'package:just_audio/just_audio.dart';

class VoiceoversScreen extends StatefulWidget {
  final List<Scene> scenes;
  final ApiService apiService;
  final Function(int, String, {bool isLocal}) onVoiceoverSelected;

  VoiceoversScreen({
    required this.scenes,
    required this.apiService,
    required this.onVoiceoverSelected,
  });

  @override
  _VoiceoversScreenState createState() => _VoiceoversScreenState();
}

class _VoiceoversScreenState extends State<VoiceoversScreen> {
  bool _isLoading = false;
  int _loadingIndex = -1;
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

  Future<void> _generateVoiceover(int index) async {
    setState(() {
      _isLoading = true;
      _loadingIndex = index;
    });

    try {
      final scene = widget.scenes[index];
      final voiceoverUrl = await widget.apiService
          .generateVoiceover(scene.text, scene.sceneNumber);
      if (voiceoverUrl != null) {
        final localVoiceoverPath = await widget.apiService
            .downloadImage(voiceoverUrl, scene.sceneNumber);
        widget.onVoiceoverSelected(index, localVoiceoverPath, isLocal: true);
        await _audioPlayers[index].setFilePath(localVoiceoverPath);
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.scenes.length,
      itemBuilder: (context, index) {
        final scene = widget.scenes[index];
        final player = _audioPlayers[index];
        return Card(
          child: ListTile(
            title: Text(scene.text),
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
                        icon: Icon(
                            _isPlaying[index] ? Icons.pause : Icons.play_arrow),
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
                            final position = snapshot.data ?? Duration.zero;
                            final duration = player.duration ?? Duration.zero;
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
