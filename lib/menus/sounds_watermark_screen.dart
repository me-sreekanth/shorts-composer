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
  final VideoService videoService;
  final String? backgroundMusicFileName;
  final String? watermarkFileName;

  const SoundsWatermarkScreen({
    required this.onMusicSelected,
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
  AudioPlayer? _audioPlayer; // For playing audio
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _backgroundMusicFileName = widget.backgroundMusicFileName;
    _audioPlayer = AudioPlayer();
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
          _audioPlayer
              ?.setFilePath(newFilePath); // Load the music file for playback
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
    }
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
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Sound & Watermark'),
      ),
      body: Column(
        children: [
          // Background Music Section (occupies half of the screen)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Background Music',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_backgroundMusicFileName != null)
                    Text('Selected: $_backgroundMusicFileName'),
                  ElevatedButton.icon(
                    onPressed: _pickBackgroundMusic,
                    icon: const Icon(Icons.music_note),
                    label: const Text('Pick Background Music'),
                  ),
                  const SizedBox(height: 10),
                  if (_backgroundMusicFileName != null)
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _togglePlayPause,
                          icon:
                              Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                          label: Text(_isPlaying ? 'Pause' : 'Play'),
                        ),
                        SeekBar(
                          player: _audioPlayer!,
                          onPlayPause: _togglePlayPause,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Watermark Section (occupies half of the screen)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Watermark',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _selectedWatermark != null
                      ? Image.file(_selectedWatermark!)
                      : widget.watermarkFileName != null
                          ? Text(
                              'Selected watermark: ${widget.watermarkFileName}')
                          : const Text('No watermark selected'),
                  ElevatedButton.icon(
                    onPressed: _pickWatermark,
                    icon: const Icon(Icons.image),
                    label: const Text('Pick Watermark'),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading) const CircularProgressIndicator(),
        ],
      ),
    );
  }
}
