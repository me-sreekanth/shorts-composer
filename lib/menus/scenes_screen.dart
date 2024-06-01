import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:shorts_composer/services/api_service.dart';

class ScenesScreen extends StatefulWidget {
  final List<Scene> scenes;
  final Function(int, String) onDescriptionChanged;
  final Function(int, String, {bool isLocal}) onImageSelected;

  ScenesScreen({
    required this.scenes,
    required this.onDescriptionChanged,
    required this.onImageSelected,
  });

  @override
  _ScenesScreenState createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  final Map<int, bool> _isLoading = {}; // Track loading status for each scene

  Future<void> _pickImage(int index) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        print('Image picked: ${pickedFile.path}');
        widget.onImageSelected(index, pickedFile.path, isLocal: true);
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _generateImage(int index) async {
    setState(() {
      _isLoading[index] = true; // Set loading status to true for this scene
    });

    final scene = widget.scenes[index];
    final processId =
        await _apiService.generateImage(scene.description, scene.sceneNumber);
    if (processId != null) {
      final imageUrl = await _apiService.fetchStatus(processId);
      if (imageUrl != null) {
        widget.onImageSelected(index, imageUrl, isLocal: false);
      }
    }

    setState(() {
      _isLoading[index] = false; // Set loading status to false for this scene
    });
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
                  controller: TextEditingController(text: scene.description),
                  decoration: InputDecoration(labelText: 'Description'),
                  onChanged: (value) {
                    widget.onDescriptionChanged(index, value);
                  },
                ),
                SizedBox(height: 10),
                _isLoading[index] == true
                    ? Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: Center(child: CircularProgressIndicator()))
                    : scene.imageUrl != null
                        ? scene.isLocalImage
                            ? Image.file(File(scene.imageUrl!))
                            : Image.network(scene.imageUrl!)
                        : Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: Center(child: Text('No Image'))),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _generateImage(index);
                      },
                      child: Row(
                        children: [
                          Icon(Icons.image),
                          SizedBox(width: 5),
                          Text('Generate'),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _pickImage(index);
                      },
                      child: Row(
                        children: [
                          Icon(Icons.photo_library),
                          SizedBox(width: 5),
                          Text('Choose'),
                        ],
                      ),
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
