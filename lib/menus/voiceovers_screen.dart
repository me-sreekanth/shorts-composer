import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shorts_composer/components/seekbar.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/config_service.dart';
import 'package:shorts_composer/services/voiceover_service.dart';
import 'package:shorts_composer/services/api_service.dart';
import 'package:path/path.dart' as p;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:http/http.dart' as http;

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
  final PageController _pageController = PageController(viewportFraction: 0.8);
  double _currentPage = 0;
  final List<AudioPlayer> _audioPlayers = [];
  final List<bool> _isPlaying = [];
  final VoiceoverService _voiceoverService = VoiceoverService();
  final List<TextEditingController> _textControllers = [];
  Map<int, bool> _isLoading = {};

  Map<int, bool> _isGenerating = {};
  Map<int, bool> _isTranscribing = {};

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      }
    });

    _initializePlayers();
    _initializeTextControllers();

    for (int i = 0; i < widget.scenes.length; i++) {
      _isLoading[i] = false;
      final voiceoverUrl = widget.scenes[i].voiceoverUrl;
      if (voiceoverUrl != null) {
        _audioPlayers[i].setFilePath(voiceoverUrl);
      }
    }
  }

  void _initializePlayers() {
    for (var i = 0; i < widget.scenes.length; i++) {
      final player = AudioPlayer();
      _audioPlayers.add(player);
      _isPlaying.add(false);

      // Listen to player state changes
      player.playerStateStream.listen((playerState) {
        if (mounted) {
          setState(() {
            _isPlaying[i] = playerState.playing;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var player in _audioPlayers) {
      player.dispose();
    }
    for (var controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeTextControllers() {
    for (var scene in widget.scenes) {
      _textControllers.add(TextEditingController(text: scene.text));
    }
  }

  int _countScenesWithVoiceovers() {
    return widget.scenes
        .where((scene) =>
            scene.voiceoverUrl != null && scene.voiceoverUrl!.isNotEmpty)
        .length;
  }

  void _deleteScene(int index) {
    setState(() {
      widget.scenes.removeAt(index);
      _audioPlayers.removeAt(index);
      _isPlaying.removeAt(index);
      _textControllers.removeAt(index);
      _isLoading.remove(index);

      for (int i = index; i < widget.scenes.length; i++) {
        widget.scenes[i].sceneNumber = i + 1;
      }
    });

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index >= widget.scenes.length ? widget.scenes.length - 1 : index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  void _addNewScene() {
    setState(() {
      int newIndex = widget.scenes.length;
      widget.scenes.add(
        Scene(
          sceneNumber: newIndex + 1,
          duration: 5,
          text: '',
          description: '',
        ),
      );

      _audioPlayers.add(AudioPlayer());
      _isPlaying.add(false);
      _textControllers.add(TextEditingController());
      _isLoading[newIndex] = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          widget.scenes.length - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final int totalScenes = widget.scenes.length;
    final int scenesWithVoiceovers = _countScenesWithVoiceovers();

    return GestureDetector(
      onTap: () {
        // Unfocus the text field when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Voiceovers for scenes ($scenesWithVoiceovers/$totalScenes)',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
          backgroundColor: colorScheme.primary,
          elevation: 4,
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (widget.scenes.isEmpty) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic_off,
                            size: 80,
                            color: colorScheme.onSurface.withOpacity(0.5)),
                        const SizedBox(height: 20),
                        Text('No Voiceovers Available',
                            style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7))),
                        const SizedBox(height: 10),
                        Text('Add scenes to start creating voiceovers.',
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.scenes.length,
                    onPageChanged: (index) async {
                      // Pause the currently playing voiceover when the card is changed
                      for (var player in _audioPlayers) {
                        if (player.playing) {
                          await player.pause();
                        }
                      }
                      setState(() {
                        _isPlaying.fillRange(0, _isPlaying.length, false);
                      });
                    },
                    itemBuilder: (context, index) {
                      final scene = widget.scenes[index];
                      final player = _audioPlayers[index];

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Transform.scale(
                          key: ValueKey(scene.sceneNumber),
                          scale: (1 - (_currentPage - index).abs() * 0.15)
                              .clamp(0.85, 1.0),
                          child: Card(
                            elevation: 6,
                            margin: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Scene Number and Delete Button Row
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Scene ${scene.sceneNumber}',
                                          style: textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _deleteScene(index),
                                          icon: Icon(Icons.delete,
                                              color: colorScheme.error),
                                          tooltip: 'Delete Scene',
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Scene Image (Fixed Height of 150)
                                  Container(
                                    height: 150,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.6),
                                          Colors.black.withOpacity(0.4),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Scene Image (if available)
                                        if (scene.imageUrl != null &&
                                            scene.imageUrl!.isNotEmpty)
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              topRight: Radius.circular(16),
                                            ),
                                            child: Image.file(
                                              File(scene.imageUrl!),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          ),
                                        // Black Gradient Overlay
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              topRight: Radius.circular(16),
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.black.withOpacity(0.6),
                                                Colors.black.withOpacity(0.4),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                        // No Voiceover Selected Content or Audio Player
                                        if (_isTranscribing[index] != true &&
                                            _isGenerating[index] != true)
                                          Center(
                                            child: scene.voiceoverUrl != null &&
                                                    scene.voiceoverUrl!
                                                        .isNotEmpty
                                                ? _buildAudioPlayerControls(
                                                    player, index)
                                                : _buildNoVoiceoverPlaceholder(),
                                          ),
                                        // Loader for Transcription or Generation
                                        if (_isTranscribing[index] == true ||
                                            _isGenerating[index] == true)
                                          Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                CircularProgressIndicator(
                                                  color: colorScheme.primary,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _isTranscribing[index] == true
                                                      ? 'Transcribing audio...'
                                                      : 'Generating voiceover...',
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Content Below the Image
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceVariant,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Pick Voiceover Button (Above OR Label)
                                        if (scene.voiceoverUrl == null ||
                                            scene.voiceoverUrl!.isEmpty)
                                          SizedBox(
                                            width: double.infinity,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 16.0),
                                              child: _buildPickVoiceoverButton(
                                                  index,
                                                  colorScheme,
                                                  textTheme),
                                            ),
                                          ),
                                        // OR Label
                                        if (scene.voiceoverUrl == null ||
                                            scene.voiceoverUrl!.isEmpty)
                                          Center(
                                            child: Text(
                                              'OR',
                                              style:
                                                  textTheme.bodyLarge?.copyWith(
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.7),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        // Voiceover Text Field
                                        TextField(
                                          controller: _textControllers[index],
                                          onChanged: (value) {
                                            widget.onSceneTextUpdated(
                                                index, value);
                                          },
                                          maxLines: 5,
                                          minLines: 3,
                                          decoration: InputDecoration(
                                            labelText: scene.voiceoverUrl !=
                                                        null &&
                                                    scene.voiceoverUrl!
                                                        .isNotEmpty
                                                ? 'Transcript'
                                                : 'Generate voiceover from text',
                                            labelStyle:
                                                textTheme.titleMedium?.copyWith(
                                              fontSize: 18,
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.7),
                                            ),
                                            alignLabelWithHint: true,
                                            floatingLabelAlignment:
                                                FloatingLabelAlignment.start,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                  color: colorScheme.outline),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                  color: colorScheme.primary,
                                                  width: 2),
                                            ),
                                            filled: true,
                                            fillColor:
                                                colorScheme.surfaceVariant,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Generate Voiceover Button
                                        if (scene.voiceoverUrl == null ||
                                            scene.voiceoverUrl!.isEmpty)
                                          SizedBox(
                                            width: double.infinity,
                                            child:
                                                _buildGenerateVoiceoverButton(
                                                    index,
                                                    colorScheme,
                                                    textTheme),
                                          ),
                                        // Clear Voiceover Button
                                        if (scene.voiceoverUrl != null &&
                                            scene.voiceoverUrl!.isNotEmpty)
                                          SizedBox(
                                            width: double.infinity,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 16.0),
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _clearVoiceover(index),
                                                icon: Icon(Icons.clear,
                                                    color: Colors.white),
                                                label: Text('Clear Voiceover',
                                                    style: textTheme.labelLarge
                                                        ?.copyWith(
                                                            color:
                                                                Colors.white)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 12,
                                                      horizontal: 16),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: widget.scenes.length,
                    effect: WormEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        activeDotColor: colorScheme.primary,
                        dotColor: colorScheme.surfaceVariant),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _addNewScene,
                  icon: Icon(Icons.add, color: colorScheme.onPrimary),
                  label: Text('Add New Scene',
                      style: textTheme.labelLarge
                          ?.copyWith(color: colorScheme.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build the "Pick Voiceover" button
  Widget _buildPickVoiceoverButton(
      int index, ColorScheme colorScheme, TextTheme textTheme) {
    return ElevatedButton.icon(
      onPressed: () => _pickVoiceover(index),
      icon: Icon(Icons.upload_file, color: colorScheme.onSecondary),
      label: Text('Pick Voiceover',
          style:
              textTheme.labelLarge?.copyWith(color: colorScheme.onSecondary)),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.secondary, // Use secondary color
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Helper method to build the "No Voiceover Selected" placeholder
  Widget _buildNoVoiceoverPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mic_off, size: 40, color: Colors.white),
        const SizedBox(height: 8),
        Text(
          'No Voiceover Selected',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // Helper method to show an alert when the text field is empty
  void _showEmptyTextAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text('Text input field cannot be empty.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Updated _generateVoiceover method to include validation
  Future<void> _generateVoiceover(int index) async {
    final text = _textControllers[index].text.trim();
    if (text.isEmpty) {
      _showEmptyTextAlert(context);
      return;
    }

    setState(() {
      _isGenerating[index] = true; // Show progress indicator
    });

    try {
      final voiceoverFilePath = await _voiceoverService.generateVoiceover(
          text, widget.scenes[index].sceneNumber, widget.apiService);

      if (voiceoverFilePath != null) {
        setState(() {
          widget.scenes[index].voiceoverUrl = voiceoverFilePath;
          _isGenerating[index] = false; // Hide progress indicator
        });
        await _audioPlayers[index].setFilePath(voiceoverFilePath);
      } else {
        setState(() {
          _isGenerating[index] = false; // Hide progress indicator
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate voiceover.')),
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating[index] = false; // Hide progress indicator
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate voiceover: $e')),
      );
    }
  }

  // Helper method to build the "Generate Voiceover" button
  Widget _buildGenerateVoiceoverButton(
      int index, ColorScheme colorScheme, TextTheme textTheme) {
    return ElevatedButton.icon(
      onPressed: () => _generateVoiceover(index),
      icon: Icon(Icons.mic, color: colorScheme.onPrimary),
      label: Text('Generate Voiceover',
          style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary)),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary, // Use primary color
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Audio player controls
  Widget _buildAudioPlayerControls(AudioPlayer player, int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying[index] ? Icons.pause : Icons.play_arrow),
            color: Colors.white,
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
      ),
    );
  }

  // Clear Voiceover
  void _clearVoiceover(int index) {
    setState(() {
      widget.scenes[index].voiceoverUrl = null;
      _audioPlayers[index].stop();
      _isPlaying[index] = false;
      _textControllers[index].clear(); // Clear the text field
    });
    widget.onVoiceoverSelected(index, '', isLocal: false);
  }

  // Pick Voiceover
  Future<void> _pickVoiceover(int index) async {
    String? filePath = await _voiceoverService.pickVoiceover();
    if (filePath != null) {
      setState(() {
        _isTranscribing[index] = true; // Show progress indicator
      });

      try {
        final transcription = await transcribeAndGenerateAss(filePath);
        setState(() {
          widget.scenes[index].voiceoverUrl = filePath;
          _textControllers[index].text = transcription; // Set the transcription
          widget.onSceneTextUpdated(index, transcription); // Update scene text
          _isTranscribing[index] = false; // Hide progress indicator
        });
        await _audioPlayers[index].setFilePath(filePath);
      } catch (e) {
        setState(() {
          _isTranscribing[index] = false; // Hide progress indicator
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to transcribe audio: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected or an error occurred.')),
      );
    }
  }

  // Transcribe and Generate ASS File
  Future<String> transcribeAndGenerateAss(String audioFilePath) async {
    String contentType =
        audioFilePath.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav';

    Uri url = Uri.parse(ConfigService.get('transcribeVoiceoversUrl'));
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Token ${ConfigService.get('deepgramApiToken')}',
        'Content-Type': contentType,
      },
      body: File(audioFilePath).readAsBytesSync(),
    );

    if (response.statusCode == 200) {
      final decodedResponse = jsonDecode(response.body);
      return decodedResponse['results']['channels'][0]['alternatives'][0]
          ['transcript'];
    }
    throw Exception("Failed to transcribe audio");
  }
}
