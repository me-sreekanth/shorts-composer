import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart'; // For audio playback
import 'package:shorts_composer/components/seekbar.dart';
import 'package:shorts_composer/services/video_service.dart'; // Import your VideoService

class SoundsWatermarkScreen extends StatefulWidget {
  final Function(String) onMusicSelected;
  final Function(String) onWatermarkSelected; // Add this line
  final VideoService videoService;
  final String? backgroundMusicFileName;
  final String? watermarkFileName;

  const SoundsWatermarkScreen({
    required this.onMusicSelected,
    required this.onWatermarkSelected, // Add this line
    required this.videoService,
    this.backgroundMusicFileName,
    this.watermarkFileName,
    Key? key,
  }) : super(key: key);

  @override
  _SoundsWatermarkScreenState createState() => _SoundsWatermarkScreenState();
}

class _SoundsWatermarkScreenState extends State<SoundsWatermarkScreen> {
  String? _backgroundMusicFileName;
  File? _selectedWatermark;
  bool _isLoading = false;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _backgroundMusicFileName = widget.backgroundMusicFileName;
    _audioPlayer = AudioPlayer();

    // Listen to changes in the playing state
    _audioPlayer?.playingStream.listen((isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    });

    if (widget.videoService.watermarkPath != null) {
      _selectedWatermark = File(widget.videoService.watermarkPath!);
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

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

          // Load and play the music file automatically
          _audioPlayer?.setFilePath(newFilePath).then((_) {
            _audioPlayer?.play(); // Start playing as soon as it's loaded
          });
        });

        print('Stored background music at: $newFilePath');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickWatermark() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedWatermark = File(pickedFile.path);
      });

      // Set the watermark path in the VideoService
      widget.videoService.watermarkPath = pickedFile.path;

      // Notify the parent widget about the selected watermark
      widget.onWatermarkSelected(pickedFile.path); // Add this line
    }
  }

  // Clear the selected background music
  void _clearBackgroundMusic() {
    setState(() {
      _backgroundMusicFileName = null;
      _audioPlayer?.stop();
    });
  }

  // Clear the selected watermark
  void _clearWatermark() {
    setState(() {
      _selectedWatermark = null;
      widget.videoService.watermarkPath = null;
      widget.onWatermarkSelected(''); // Notify parent that watermark is cleared
    });
  }

  // Get appropriate storage directory based on platform
  Future<Directory?> _getStorageDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
    return null;
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer?.pause();
    } else {
      await _audioPlayer?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choose background music & watermark',
          style: TextStyle(
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Overall padding
          child: Column(
            children: [
              // Background Music Section (as a card)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 350, // Minimum height for the card
                ),
                child: Card(
                  margin: const EdgeInsets.only(
                      bottom: 16), // Add space between cards
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Background Music',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_backgroundMusicFileName != null)
                          Text(
                            'Selected: $_backgroundMusicFileName',
                            textAlign: TextAlign.center,
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickBackgroundMusic,
                              icon: const Icon(Icons.music_note),
                              label: const Text('Pick Background Music'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                textStyle: const TextStyle(fontSize: 16),
                                minimumSize: Size
                                    .zero, // Ensure button adjusts to content size
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            if (_backgroundMusicFileName != null)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: _clearBackgroundMusic,
                                tooltip: 'Delete Background Music',
                              ),
                          ],
                        ),
                        SizedBox(height: 20),
                        if (_backgroundMusicFileName != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: SeekBar(
                                    player: _audioPlayer!,
                                    onPlayPause: _togglePlayPause,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Watermark Section (as a card)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 350, // Minimum height for the card
                ),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Watermark',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_selectedWatermark != null)
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth:
                                  200, // Set a max width for the image container
                              minWidth: 50,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black26),
                              ),
                              child: Image.file(
                                _selectedWatermark!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickWatermark,
                              icon: const Icon(Icons.image),
                              label: const Text('Pick Watermark'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                textStyle: const TextStyle(fontSize: 16),
                                minimumSize: Size
                                    .zero, // Ensure button adjusts to content size
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            if (_selectedWatermark != null)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: _clearWatermark,
                                tooltip: 'Delete Watermark',
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Recommended size: 100x50',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_isLoading) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
