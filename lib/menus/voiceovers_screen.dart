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

  void _initializePlayers() {
    for (var i = 0; i < widget.scenes.length; i++) {
      _audioPlayers.add(AudioPlayer());
      _isPlaying.add(false);
    }
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

  // Future<void> _generateVoiceover(int index) async {
  //   setState(() {
  //     _isLoading[index] = true;
  //   });

  //   try {
  //     final scene = widget.scenes[index];
  //     final voiceoverFilePath = await _voiceoverService.generateVoiceover(
  //         scene.text, scene.sceneNumber, widget.apiService);
  //     if (voiceoverFilePath != null) {
  //       widget.onVoiceoverSelected(index, voiceoverFilePath, isLocal: true);
  //       await _audioPlayers[index].setFilePath(voiceoverFilePath);
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Failed to generate voiceover.')),
  //       );
  //     }
  //   } finally {
  //     setState(() {
  //       _isLoading[index] = false;
  //     });
  //   }
  // }

  // Future<void> _pickVoiceover(int index) async {
  //   String? filePath = await _voiceoverService.pickVoiceover();
  //   if (filePath != null) {
  //     widget.onVoiceoverSelected(index, filePath, isLocal: true);
  //     await _audioPlayers[index].setFilePath(filePath);
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('No file selected or an error occurred.')),
  //     );
  //   }
  // }

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

    return Scaffold(
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
                          child: Column(
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
                              // Scene Image (Larger Size)
                              Container(
                                height: 250, // Increased height for the image
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                  image: scene.imageUrl != null &&
                                          scene.imageUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image:
                                              FileImage(File(scene.imageUrl!)),
                                          fit: BoxFit.cover,
                                        )
                                      : const DecorationImage(
                                          image: AssetImage(
                                              'assets/dummy_image.png'), // Add a dummy image asset
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                child: Stack(
                                  children: [
                                    // Semi-Transparent Overlay
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(16)),
                                      ),
                                    ),
                                    // Pick Voiceover Button (Inside Image Area)
                                    if (scene.voiceoverUrl == null ||
                                        scene.voiceoverUrl!.isEmpty)
                                      Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: Center(
                                          child: _buildPickVoiceoverButton(
                                              index, colorScheme, textTheme),
                                        ),
                                      ),
                                    // No Voiceover Selected Content or Audio Player
                                    Center(
                                      child: scene.voiceoverUrl != null &&
                                              scene.voiceoverUrl!.isNotEmpty
                                          ? _buildAudioPlayerControls(
                                              player, index)
                                          : _buildNoVoiceoverPlaceholder(
                                              colorScheme),
                                    ),
                                  ],
                                ),
                              ),
                              // Content Below the Image
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                      // Voiceover Text Field (Always Visible)
                                      TextField(
                                        controller: _textControllers[index],
                                        onChanged: (value) {
                                          widget.onSceneTextUpdated(
                                              index, value);
                                        },
                                        maxLines: 5, // Multiline text field
                                        minLines: 3, // Minimum 3 lines
                                        decoration: InputDecoration(
                                          hintText:
                                              'Generate voiceover from text',
                                          hintStyle:
                                              textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurface
                                                .withOpacity(0.5),
                                          ),
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
                                          fillColor: colorScheme.surfaceVariant,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Generate Voiceover Button (Hidden if Voiceover is Picked)
                                      if (scene.voiceoverUrl == null ||
                                          scene.voiceoverUrl!.isEmpty)
                                        _buildGenerateVoiceoverButton(
                                            index, colorScheme, textTheme),
                                      // Progress Indicator for Transcription
                                      if (_isTranscribing[index] ?? false)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16.0),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      // Progress Indicator for Voiceover Generation
                                      if (_isGenerating[index] ?? false)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16.0),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      // Clear Voiceover Button (Visible if Voiceover is Picked)
                                      if (scene.voiceoverUrl != null &&
                                          scene.voiceoverUrl!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16.0),
                                          child: Center(
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _clearVoiceover(index),
                                              icon: Icon(Icons.clear,
                                                  color: colorScheme.onPrimary),
                                              label: Text('Clear Voiceover',
                                                  style: textTheme.labelLarge
                                                      ?.copyWith(
                                                          color: colorScheme
                                                              .onPrimary)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    colorScheme.primary,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
    );
  }

// Helper method to build the "No Voiceover Selected" placeholder
  Widget _buildNoVoiceoverPlaceholder(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mic_off, size: 40, color: Colors.white.withOpacity(0.7)),
        const SizedBox(height: 8),
        Text(
          'No Voiceover Selected',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

// Helper method to build the "Pick Voiceover" button
  Widget _buildPickVoiceoverButton(
      int index, ColorScheme colorScheme, TextTheme textTheme) {
    return OutlinedButton.icon(
      onPressed: () => _pickVoiceover(index),
      icon: Icon(Icons.upload_file, color: Colors.white),
      label: Text('Pick Voiceover',
          style: textTheme.labelLarge?.copyWith(color: Colors.white)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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
        backgroundColor: colorScheme.primary,
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

// Generate Voiceover
  Future<void> _generateVoiceover(int index) async {
    setState(() {
      _isGenerating[index] = true; // Show progress indicator
    });

    try {
      final prompt = _textControllers[index].text;
      final voiceoverFilePath = await _voiceoverService.generateVoiceover(
          prompt, widget.scenes[index].sceneNumber, widget.apiService);

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
