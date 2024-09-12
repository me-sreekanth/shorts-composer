import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shorts_composer/models/scene.dart';

class ScenesScreen extends StatefulWidget {
  final List<Scene> scenes;
  final Function(int, String, {bool isLocal}) onImageSelected;
  final Function(int, String) onDescriptionChanged;
  final Future<void> Function(int) onGenerateImage;

  ScenesScreen({
    required this.scenes,
    required this.onImageSelected,
    required this.onDescriptionChanged,
    required this.onGenerateImage,
  });

  @override
  _ScenesScreenState createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  bool _isLoading = false;
  int _loadingIndex = -1;

  // Function to pick an image from the gallery
  void _pickImage(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      widget.onImageSelected(index, pickedFile.path, isLocal: true);
    }
  }

  // Function to generate an image for a scene
  Future<void> _generateImage(int index) async {
    setState(() {
      _isLoading = true;
      _loadingIndex = index;
    });

    await widget.onGenerateImage(index);

    setState(() {
      _isLoading = false;
      _loadingIndex = -1;
    });
  }

  // Function to add a new empty scene to the list
  void _addNewScene() {
    setState(() {
      final newSceneNumber = widget.scenes.length + 1;
      widget.scenes.add(
        Scene(
          sceneNumber: newSceneNumber,
          duration: 5, // Default duration (can be modified by the user)
          text: '', // Empty text initially
          description: '', // Empty description initially
        ),
      );
    });
  }

  // Function to delete a scene
  void _deleteScene(int index) {
    setState(() {
      widget.scenes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.scenes.length,
            itemBuilder: (context, index) {
              final scene = widget.scenes[index];
              return Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (newDescription) => widget
                              .onDescriptionChanged(index, newDescription),
                          decoration: InputDecoration(
                            hintText: 'Enter description',
                            labelText: 'Description',
                          ),
                          controller:
                              TextEditingController(text: scene.description),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        color: Colors.red,
                        onPressed: () => _deleteScene(index),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (scene.imageUrl != null)
                        Image.file(
                          File(scene.imageUrl!),
                          height: 100,
                          width: 100,
                        )
                      else
                        Container(
                          height: 100,
                          width: 100,
                          color: Colors.grey,
                          child: Center(child: Text('No Image')),
                        ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _pickImage(index),
                            child: Text('Pick'),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _generateImage(index),
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
          ),
        ),
        ElevatedButton.icon(
          onPressed: _addNewScene,
          icon: Icon(Icons.add),
          label: Text('Add New Scene'),
        ),
      ],
    );
  }
}
