import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shorts_composer/components/seekbar.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/voiceover_service.dart';
import 'package:shorts_composer/services/api_service.dart';
import 'package:path/path.dart' as p;

class VoiceoversScreen extends StatefulWidget {
  final List<Scene> scenes;
  final ApiService apiService;
  final Function(int, String, {bool isLocal}) onVoiceoverSelected;
  final Function(int, String) onSceneTextUpdated;

  const VoiceoversScreen({
    super.key,
    required this.scenes,
    required this.apiService,
    required this.onVoiceoverSelected,
    required this.onSceneTextUpdated,
  });

  @override
  _VoiceoversScreenState createState() => _VoiceoversScreenState();
}

class _VoiceoversScreenState extends State<VoiceoversScreen> {
  bool _isLoading = false;
  int _loadingIndex = -1;
  final List<AudioPlayer> _audioPlayers = [];
  final List<bool> _isPlaying = [];
  final _voiceoverService = VoiceoverService();
  final DraggableScrollableController _scrollableController =
      DraggableScrollableController();
  final List<TextEditingController> _textControllers = [];

  @override
  void initState() {
    super.initState();
    _initializePlayers();
    _initializeTextControllers();

    // Restore audio file paths if they exist
    for (int i = 0; i < widget.scenes.length; i++) {
      final voiceoverUrl = widget.scenes[i].voiceoverUrl;
      if (voiceoverUrl != null) {
        _audioPlayers[i].setFilePath(voiceoverUrl);
      }
    }
  }

  @override
  void dispose() {
    for (var player in _audioPlayers) {
      player.dispose();
    }
    // _combinedAudioPlayer?.dispose();
    for (var controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializePlayers() {
    if (_audioPlayers.isNotEmpty) {
      // Retain existing players
      for (int i = 0; i < widget.scenes.length; i++) {
        if (i >= _audioPlayers.length) {
          _audioPlayers.add(AudioPlayer());
          _isPlaying.add(false);
        }
      }
    } else {
      // Initialize new players
      for (var i = 0; i < widget.scenes.length; i++) {
        _audioPlayers.add(AudioPlayer());
        _isPlaying.add(false);
      }
    }
  }

  void _initializeTextControllers() {
    _textControllers.clear();
    for (var scene in widget.scenes) {
      _textControllers.add(TextEditingController(text: scene.text));
    }
  }

  Widget _buildSceneTextField(Scene scene, int index) {
    return TextField(
      controller: _textControllers[index],
      onChanged: (newText) {
        setState(() {
          scene.text = newText;
        });
        widget.onSceneTextUpdated(
            index, newText); // Pass updated text back to parent
      },
      maxLines: null,
      decoration: InputDecoration(
        labelText: 'Voiceover text',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int scenesWithVoiceovers = _getScenesWithVoiceovers();
    int totalScenes = widget.scenes.length;

    double screenHeight = MediaQuery.of(context).size.height;
    double bottomSheetHeightCollapsed =
        screenHeight * 0.23; // Example value for collapsed height

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Voiceovers for scenes ($scenesWithVoiceovers/$totalScenes)',
          style: TextStyle(fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              // Allow main list (scene list) scrolling to collapse bottom sheet
              if (scrollNotification is ScrollUpdateNotification &&
                  scrollNotification.metrics.axis == Axis.vertical &&
                  scrollNotification.metrics.pixels > 0) {
                _scrollableController.animateTo(
                  0.3,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
              return false;
            },
            child: Column(
              children: [
                Expanded(
                  child: widget.scenes.isEmpty
                      ? _buildNoDataMessage()
                      : Padding(
                          padding: EdgeInsets.only(
                              bottom: bottomSheetHeightCollapsed),
                          child: ListView.builder(
                            itemCount: widget.scenes.length,
                            itemBuilder: (context, index) {
                              final scene = widget.scenes[index];
                              final player = _audioPlayers[index];
                              return _buildSceneCard(scene, player, index);
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getScenesWithVoiceovers() {
    return widget.scenes.where((scene) => scene.voiceoverUrl != null).length;
  }

  Widget _buildNoDataMessage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_off, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'No Voiceovers Available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 10),
          Text(
            'Add new scenes for voiceovers',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneCard(Scene scene, AudioPlayer player, int index) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSceneTextField(scene, index),
              const SizedBox(height: 8),
              _buildVoiceoverStatus(scene),
              const SizedBox(height: 8),
              _buildActionButtons(index),
              if (_isLoading && _loadingIndex == index)
                LinearProgressIndicator(),
              if (scene.voiceoverUrl != null)
                _buildAudioPlayerControls(player, index),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildVoiceoverStatus(Scene scene) {
    String? fileName =
        scene.voiceoverUrl != null ? p.basename(scene.voiceoverUrl!) : null;
    return Text(
      fileName != null ? 'Voiceover: $fileName' : 'No Voiceover',
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: scene.voiceoverUrl != null ? Colors.green : Colors.red),
    );
  }

  Widget _buildActionButtons(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          onPressed: () => _pickVoiceover(index),
          icon: const Icon(Icons.upload_file, color: Colors.white),
          label:
              Text('Pick', style: TextStyle(fontSize: 16, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _generateVoiceover(index),
          icon: const Icon(Icons.mic, color: Colors.white),
          label: const Text('Generate',
              style: TextStyle(fontSize: 16, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlayerControls(AudioPlayer player, int index) {
    return Row(
      children: [
        IconButton(
          icon: Icon(_isPlaying[index] ? Icons.pause : Icons.play_arrow),
          color: Colors.blueAccent,
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
          child: SeekBar(
            player: player,
            onPlayPause: () {
              setState(() {
                _isPlaying[index] = !_isPlaying[index];
              });
            },
          ),
        ),
      ],
    );
  }

  Future<void> _generateVoiceover(int index) async {
    setState(() {
      _isLoading = true;
      _loadingIndex = index;
    });
    try {
      final scene = widget.scenes[index];
      final voiceoverFilePath = await _voiceoverService.generateVoiceover(
          scene.text, scene.sceneNumber, widget.apiService);
      if (voiceoverFilePath != null) {
        widget.onVoiceoverSelected(index, voiceoverFilePath, isLocal: true);
        await _audioPlayers[index].setFilePath(voiceoverFilePath);
      } else {
        _showError('Failed to generate voiceover.');
      }
    } finally {
      setState(() {
        _isLoading = false;
        _loadingIndex = -1;
      });
    }
  }

  Future<void> _pickVoiceover(int index) async {
    String? filePath = await _voiceoverService
        .pickVoiceover(); // Assuming _voiceoverService handles file picking
    if (filePath != null) {
      // Update the scene with the selected voiceover file
      widget.onVoiceoverSelected(index, filePath, isLocal: true);

      // Set the picked file to the audio player for that scene
      await _audioPlayers[index].setFilePath(filePath);
    } else {
      _showError('No file selected or an error occurred.');
    }
  }
}
