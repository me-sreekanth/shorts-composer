import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shorts_composer/models/scene.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shorts_composer/services/api_service.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ScenesScreen extends StatefulWidget {
  final List<Scene> scenes;
  final Function(int, String, {bool isLocal}) onImageSelected;
  final Function(int, String) onDescriptionChanged;
  final Future<void> Function(int) onGenerateImage;

  const ScenesScreen({
    super.key,
    required this.scenes,
    required this.onImageSelected,
    required this.onDescriptionChanged,
    required this.onGenerateImage,
  });

  @override
  _ScenesScreenState createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  double _currentPage = 0;
  Map<int, TextEditingController> _controllers = {}; // Persistent controllers
  Map<int, bool> _isLoading = {}; // Loading state per scene

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

    for (int i = 0; i < widget.scenes.length; i++) {
      _controllers[i] =
          TextEditingController(text: widget.scenes[i].description);
      _isLoading[i] = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _pickImage(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      widget.onImageSelected(index, pickedFile.path, isLocal: true);
    }
  }

  Future<void> _generateImage(int index) async {
    setState(() {
      _isLoading[index] = true;
    });

    final prompt = _controllers[index]?.text ?? '';
    final imagePath = await ApiService().generateImage(prompt, index);

    if (imagePath != null) {
      widget.onImageSelected(index, imagePath, isLocal: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate image.')),
      );
    }

    setState(() {
      _isLoading[index] = false;
    });
  }

  void _clearImage(int index) {
    widget.onImageSelected(index, '', isLocal: false);
  }

  void _deleteScene(int index) {
    setState(() {
      widget.scenes.removeAt(index);
      _controllers.remove(index);
      _isLoading.remove(index);
    });
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

      _controllers[newIndex] = TextEditingController();
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

  int _countScenesWithImages() {
    return widget.scenes
        .where((scene) => scene.imageUrl != null && scene.imageUrl!.isNotEmpty)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    double imageHeight = MediaQuery.of(context).size.height * 0.5;
    double imageWidth = MediaQuery.of(context).size.width * 0.7;

    final int totalScenes = widget.scenes.length;
    final int scenesWithImages = _countScenesWithImages();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scenes with images ($scenesWithImages/$totalScenes)',
          style: const TextStyle(
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.scenes.isEmpty) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported,
                          size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text('No Scenes Available',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 10),
                      Text('Add scenes to start creating your project.',
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
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

                    return Transform.scale(
                      scale: (1 - (_currentPage - index).abs() * 0.15)
                          .clamp(0.85, 1.0),
                      child: Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Description TextField
                                TextField(
                                  controller: _controllers[index],
                                  onChanged: (value) =>
                                      widget.onDescriptionChanged(index, value),
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Prompt for generating the image',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                SizedBox(height: 10),
                                // Image Container with Clear Button
                                Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: scene.imageUrl != null &&
                                              scene.imageUrl!.isNotEmpty
                                          ? () =>
                                              OpenFilex.open(scene.imageUrl!)
                                          : null,
                                      child: Container(
                                        height: imageHeight,
                                        width: imageWidth,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: scene.imageUrl != null &&
                                                scene.imageUrl!.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.file(
                                                  File(scene.imageUrl!),
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : (_isLoading[index] ?? false)
                                                ? Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      CircularProgressIndicator(),
                                                      SizedBox(height: 10),
                                                      Text(
                                                          'Generating image...',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[700])),
                                                    ],
                                                  )
                                                : Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(Icons.image,
                                                            size: 60,
                                                            color: Colors
                                                                .grey[700]),
                                                        SizedBox(height: 10),
                                                        Text(
                                                            'No Image Selected',
                                                            style: TextStyle(
                                                                color:
                                                                    Colors.grey[
                                                                        700])),
                                                        SizedBox(height: 5),
                                                        Text(
                                                            'Tap "Pick Image" or "Generate Image"',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors.grey[
                                                                        600])),
                                                      ],
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
                                          onTap: () => _clearImage(index),
                                          child: CircleAvatar(
                                            backgroundColor: Colors.black54,
                                            radius: 16,
                                            child: Icon(Icons.clear,
                                                color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton(
                                        onPressed: () => _pickImage(index),
                                        child: Text('Pick Image')),
                                    ElevatedButton(
                                        onPressed: () => _generateImage(index),
                                        child: Text('Generate Image')),
                                    IconButton(
                                        onPressed: () => _deleteScene(index),
                                        icon: Icon(Icons.delete,
                                            color: Colors.red)),
                                  ],
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
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: widget.scenes.length,
                  effect: const WormEffect(
                      dotHeight: 8, dotWidth: 8, activeDotColor: Colors.red),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _addNewScene,
                icon: const Icon(
                  Icons.add,
                  color: Colors.white,
                ),
                label: const Text(
                  'Add New Scene',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  backgroundColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
