import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:open_filex/open_filex.dart'; // Importing open_filex package

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
  Map<int, TextEditingController> _controllers = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed
    _controllers.values.forEach((controller) => controller.dispose());
    _scrollController.dispose();
    super.dispose();
  }

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

  // Function to clear the image
  void _clearImage(int index) {
    setState(() {
      widget.onImageSelected(index, '',
          isLocal: false); // Ensure image path is cleared
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

    // Scroll to bottom after adding a new scene
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // Function to delete a scene
  void _deleteScene(int index) {
    setState(() {
      widget.scenes.removeAt(index);
      _controllers.remove(index); // Remove the corresponding controller
    });
  }

  // Helper function to count scenes with images
  int _countScenesWithImages() {
    return widget.scenes
        .where((scene) => scene.imageUrl != null && scene.imageUrl!.isNotEmpty)
        .length;
  }

  // Function to open the picked or generated image in the gallery
  void _openImage(String imagePath) {
    OpenFilex.open(imagePath); // Using open_filex instead of open_file
  }

  @override
  Widget build(BuildContext context) {
    final int totalScenes = widget.scenes.length;
    final int scenesWithImages = _countScenesWithImages();

    return Scaffold(
      appBar: AppBar(
        title: Text('Scenes'),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.scenes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported,
                            size: 80, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          'No Scenes Available',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Add scenes to start creating your project.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Display the count of added and picked/generated scenes
                        Text(
                          'Scenes with Images: $scenesWithImages/$totalScenes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: widget.scenes.length,
                            itemBuilder: (context, index) {
                              final scene = widget.scenes[index];

                              // Initialize TextEditingController for each scene
                              if (!_controllers.containsKey(index)) {
                                _controllers[index] = TextEditingController(
                                  text: scene.description,
                                );
                              }

                              return Stack(
                                children: [
                                  Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextField(
                                            onChanged: (newDescription) =>
                                                widget.onDescriptionChanged(
                                                    index, newDescription),
                                            decoration: InputDecoration(
                                              hintText: 'Enter description',
                                              labelText: 'Description',
                                              border: OutlineInputBorder(),
                                            ),
                                            controller: _controllers[
                                                index], // Use the persistent controller
                                            maxLines:
                                                null, // Allows multiline input
                                          ),
                                          SizedBox(height: 10),
                                          Stack(
                                            children: [
                                              GestureDetector(
                                                onTap: scene.imageUrl != null &&
                                                        scene.imageUrl!
                                                            .isNotEmpty
                                                    ? () => _openImage(
                                                        scene.imageUrl!)
                                                    : null,
                                                child: Container(
                                                  height:
                                                      300, // Fixed height for the image area
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: scene.imageUrl !=
                                                              null &&
                                                          scene.imageUrl!
                                                              .isNotEmpty
                                                      ? ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          child: Image.file(
                                                            File(scene
                                                                .imageUrl!),
                                                            height: 300,
                                                            width:
                                                                double.infinity,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        )
                                                      : Center(
                                                          child: _isLoading &&
                                                                  _loadingIndex ==
                                                                      index
                                                              ? Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    CircularProgressIndicator(),
                                                                    SizedBox(
                                                                        height:
                                                                            10),
                                                                    Text(
                                                                      'Generating image...',
                                                                      style: TextStyle(
                                                                          color:
                                                                              Colors.grey[600]),
                                                                    ),
                                                                  ],
                                                                )
                                                              : Text(
                                                                  'No Image',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .grey),
                                                                ),
                                                        ),
                                                ),
                                              ),
                                              if (scene.imageUrl != null &&
                                                  scene.imageUrl!.isNotEmpty)
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: GestureDetector(
                                                    onTap: () =>
                                                        _clearImage(index),
                                                    child: CircleAvatar(
                                                      backgroundColor:
                                                          Colors.black54,
                                                      child: Icon(Icons.clear,
                                                          color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          SizedBox(height: 10),
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                onPressed: () =>
                                                    _pickImage(index),
                                                child: Text(
                                                  'Pick Image',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.blueAccent,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    _generateImage(index),
                                                child: Text(
                                                  'Generate Image',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                              ),
                                              Spacer(),
                                              IconButton(
                                                icon: Icon(Icons.delete,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _deleteScene(index),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _addNewScene,
              icon: Icon(
                Icons.add,
                color: Colors.white,
              ),
              label: Text(
                'Add New Scene',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                backgroundColor: Colors.red, // Red button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
