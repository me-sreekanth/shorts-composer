import 'dart:io'; // Import this package

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shorts_composer/models/scene.dart';

class ScenesScreen extends StatefulWidget {
  final List<Scene> scenes;
  final Function(int, String) onDescriptionChanged;
  final Function(int) onGenerateImage;
  final Function(int, String, bool) onImageSelected;

  ScenesScreen({
    required this.scenes,
    required this.onDescriptionChanged,
    required this.onGenerateImage,
    required this.onImageSelected,
  });

  @override
  _ScenesScreenState createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(int index) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        print('Image picked: ${pickedFile.path}');
        widget.onImageSelected(index, pickedFile.path, true);
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
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
                scene.imageUrl != null
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
                        widget.onGenerateImage(index);
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
