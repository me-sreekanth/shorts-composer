import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/api_service.dart';

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

  void _pickVoiceover(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (result != null && result.files.single.path != null) {
      widget.onVoiceoverSelected(index, result.files.single.path!,
          isLocal: true);
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
              ],
            ),
          ),
        );
      },
    );
  }
}
