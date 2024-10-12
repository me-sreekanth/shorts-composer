import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shorts_composer/components/seekbar.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/voiceover_service.dart';
import 'package:shorts_composer/services/api_service.dart';
import 'dart:io';
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
  bool _isTranscribing = false;
  int _loadingIndex = -1;
  final List<AudioPlayer> _audioPlayers = [];
  final List<bool> _isPlaying = [];
  final _voiceoverService = VoiceoverService();
  AudioPlayer? _combinedAudioPlayer;
  bool _isCombinedPlaying = false;
  String? _combinedAudioPath;
  String? _firstFewWordsFromAss;
  bool _isExpanded = false; // Track if the bottom sheet is expanded
  List<Map<String, String>> _fullTranscription =
      []; // To store transcription with timestamps
  DraggableScrollableController _scrollableController =
      DraggableScrollableController();

  final List<TextEditingController> _textControllers = [];

  @override
  void initState() {
    super.initState();
    _initializePlayers();
    _initializeTextControllers();
  }

  void _initializePlayers() {
    _audioPlayers.clear();
    _isPlaying.clear();
    for (var i = 0; i < widget.scenes.length; i++) {
      _audioPlayers.add(AudioPlayer());
      _isPlaying.add(false);
    }
  }

  void _initializeTextControllers() {
    _textControllers.clear();
    for (var scene in widget.scenes) {
      _textControllers.add(TextEditingController(text: scene.text));
    }
  }

  Widget _buildNoDataMessage() {
    return Center(
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
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
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
            if (_isLoading && _loadingIndex == index) LinearProgressIndicator(),
            if (scene.voiceoverUrl != null)
              _buildAudioPlayerControls(player, index),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVoiceover(int index) async {
    String? filePath = await _voiceoverService.pickVoiceover();
    if (filePath != null) {
      widget.onVoiceoverSelected(index, filePath, isLocal: true);
      await _audioPlayers[index].setFilePath(filePath);
    }
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

  Widget _buildActionButtons(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          onPressed: () => _pickVoiceover(index),
          icon: Icon(Icons.upload_file, color: Colors.white),
          label: Text(
            'Pick',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _generateVoiceover(index),
          icon: Icon(Icons.mic, color: Colors.white),
          label: Text(
            'Generate',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
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

  Widget _buildSceneTextField(Scene scene, int index) {
    return TextField(
      controller: _textControllers[index],
      onChanged: (newText) {
        setState(() {
          scene.text = newText;
        });
      },
      decoration: InputDecoration(
        labelText: 'Scene Text',
        labelStyle: TextStyle(fontSize: 16, color: Colors.blueGrey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
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
        color: scene.voiceoverUrl != null ? Colors.green : Colors.red,
      ),
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

  Widget _buildCombinedAudioPlayer() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 0.0),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isCombinedPlaying ? Icons.pause : Icons.play_arrow),
              color: Colors.blueAccent,
              onPressed: () async {
                if (_isCombinedPlaying) {
                  await _combinedAudioPlayer!.pause();
                } else {
                  await _combinedAudioPlayer!.play();
                }
                setState(() {
                  _isCombinedPlaying = !_isCombinedPlaying;
                });
              },
            ),
            Expanded(
              child: SeekBar(
                player: _combinedAudioPlayer!,
                onPlayPause: () {
                  setState(() {
                    _isCombinedPlaying = !_isCombinedPlaying;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _textControllers) {
      controller.dispose();
    }
    _combinedAudioPlayer?.dispose();
    _audioPlayers.forEach((player) => player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int scenesWithVoiceovers = _getScenesWithVoiceovers();
    int totalScenes = widget.scenes.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Voiceovers for scenes ($scenesWithVoiceovers/$totalScenes)',
          style: TextStyle(fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: widget.scenes.isEmpty
                    ? _buildNoDataMessage()
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                itemCount: widget.scenes.length,
                                itemBuilder: (context, index) {
                                  final scene = widget.scenes[index];
                                  final player = _audioPlayers[index];
                                  return _buildSceneCard(scene, player, index);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildDraggableBottomSheet(),
          ),
          if (_isLoading) CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildDraggableBottomSheet() {
    return DraggableScrollableSheet(
      controller: _scrollableController,
      initialChildSize: 0.3, // Increased initial collapsed size to fit contents
      minChildSize: 0.3, // Set minimum size to avoid overflow when collapsed
      maxChildSize: 0.7, // Maximum size when expanded
      expand: false, // Allow dragging and toggling between expand and collapse
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.grey.shade300)],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          child: Column(
            children: [
              _buildExpandCollapseHeader(), // Expand/Collapse header

              // Make the list scrollable with Flexible
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (_fullTranscription.isNotEmpty)
                        ..._fullTranscription
                            .map(
                              (line) => ListTile(
                                title: Text(line['text']!),
                                subtitle: Text(line['timestamp']!),
                              ),
                            )
                            .toList(),
                    ],
                  ),
                ),
              ),

              // Fixed player and button at the bottom
              _buildTranscribeAndPlayerSection(), // Always visible section
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscribeAndPlayerSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.grey.shade300)],
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min, // Stick the player and button at the bottom
        children: [
          if (_combinedAudioPlayer != null) _buildCombinedAudioPlayer(),
          SizedBox(height: 16),
          _buildTranscribeButton(),
        ],
      ),
    );
  }

  Widget _buildExpandCollapseHeader() {
    final firstThreeWords = _firstFewWordsFromAss != null
        ? _firstFewWordsFromAss!.split(' ').take(3).join(' ') + '...'
        : '';
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
        _scrollableController.animateTo(
          _isExpanded ? 0.7 : 0.2, // Expand or collapse
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isExpanded ? 'Collapse' : 'Expand',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            Flexible(
              child: Text(
                firstThreeWords,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              color: Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscribeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isTranscribing ? null : _transcribeCombinedVoiceovers,
        child: _isTranscribing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(width: 16),
                  Text('Transcribing...',
                      style: TextStyle(color: Colors.white)),
                ],
              )
            : Text('Transcribe Voiceovers',
                style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    );
  }

  // Handle the transcription process as before
  Future<void> _transcribeCombinedVoiceovers() async {
    if (widget.scenes.any((scene) => scene.voiceoverUrl == null)) {
      _showError("Please pick or generate voiceovers for all scenes.");
      return;
    }

    setState(() {
      _isTranscribing = true;
    });

    List<String> voiceoverFiles = widget.scenes
        .where((scene) => scene.voiceoverUrl != null)
        .map((scene) => scene.voiceoverUrl!)
        .toList();

    _combinedAudioPath =
        await _voiceoverService.combineVoiceovers(voiceoverFiles);

    if (_combinedAudioPath != null) {
      String assFilePath = await _voiceoverService.transcribeAndGenerateAss(
          _combinedAudioPath!, widget.onAssFileGenerated);

      _fullTranscription = await _parseAssFileForTranscription(assFilePath);
      _firstFewWordsFromAss = _fullTranscription.isNotEmpty
          ? _fullTranscription.first['text']
          : null;

      _combinedAudioPlayer = AudioPlayer();
      await _combinedAudioPlayer!.setFilePath(_combinedAudioPath!);
    } else {
      _showError("No voiceovers available to combine.");
    }

    setState(() {
      _isTranscribing = false;
    });
  }

  Future<List<Map<String, String>>> _parseAssFileForTranscription(
      String assFilePath) async {
    final List<Map<String, String>> transcription = [];
    final assFile = await File(assFilePath).readAsString();
    final lines = assFile.split('\n');
    RegExp formattingRegex = RegExp(r'{\\.*?}');

    for (String line in lines) {
      if (line.startsWith('Dialogue:')) {
        final dialogueParts = line.split(',');
        if (dialogueParts.length > 9) {
          final startTime = dialogueParts[1].trim();
          final textPart = dialogueParts[9].replaceAll('\\N', ' ').trim();

          final cleanedText = textPart.replaceAll(formattingRegex, '');

          transcription.add({
            'timestamp': startTime,
            'text': cleanedText,
          });
        }
      }
    }
    return transcription;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  int _getScenesWithVoiceovers() {
    return widget.scenes.where((scene) => scene.voiceoverUrl != null).length;
  }
}
