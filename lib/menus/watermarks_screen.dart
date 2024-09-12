import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shorts_composer/services/video_service.dart'; // Import your VideoService

class WatermarksScreen extends StatefulWidget {
  final VideoService videoService;
  final String? watermarkFileName;

  const WatermarksScreen({
    super.key,
    required this.videoService,
    this.watermarkFileName,
  });

  @override
  _WatermarksScreenState createState() => _WatermarksScreenState();
}

class _WatermarksScreenState extends State<WatermarksScreen> {
  File? _selectedWatermark;

  @override
  void initState() {
    super.initState();
    if (widget.videoService.watermarkPath != null) {
      _selectedWatermark = File(widget.videoService.watermarkPath!);
    }
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

      // Pass the watermark file name to the parent widget
      if (widget.watermarkFileName != null) {
        widget.videoService.watermarkPath = pickedFile.path;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Watermark'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _selectedWatermark != null
                ? Image.file(_selectedWatermark!)
                : widget.watermarkFileName != null
                    ? Text('Selected watermark: ${widget.watermarkFileName}')
                    : const Text('No watermark selected'),
            ElevatedButton(
              onPressed: _pickWatermark,
              child: const Text('Pick Watermark'),
            ),
          ],
        ),
      ),
    );
  }
}
