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
      // Clear the prompt input field
      _controllers[index]?.clear();
      // Update the description in the widget.scenes array
      widget.scenes[index].description = '';
    }
  }

  Future<void> _generateImage(int index) async {
    setState(() {
      _isLoading[index] = true;
    });

    final prompt = _controllers[index]?.text ?? '';
    final imagePath = await ApiService().generateImage(prompt, index);

    if (imagePath != null) {
      widget.onImageSelected(index, imagePath, isLocal: false);
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

  void _deleteScene(int index) async {
    // Add a fade-out animation when deleting a scene
    setState(() {
      _isLoading[index] = true; // Show loading state during deletion
    });

    await Future.delayed(const Duration(milliseconds: 300)); // Simulate delay

    setState(() {
      widget.scenes.removeAt(index);

      // Update scene numbers for remaining scenes
      for (int i = index; i < widget.scenes.length; i++) {
        widget.scenes[i].sceneNumber = i + 1;
      }

      // Remove the controller and loading state for the deleted scene
      _controllers.remove(index);
      _isLoading.remove(index);

      // Shift controllers and loading states for remaining scenes
      final newControllers = <int, TextEditingController>{};
      final newLoadingStates = <int, bool>{};

      for (int i = 0; i < widget.scenes.length; i++) {
        newControllers[i] = _controllers[i] ?? TextEditingController();
        newLoadingStates[i] = _isLoading[i] ?? false;
      }

      _controllers = newControllers;
      _isLoading = newLoadingStates;
    });

    // Animate to the previous or next scene after deletion
    if (_pageController.hasClients) {
      if (index >= widget.scenes.length) {
        _pageController.animateToPage(
          widget.scenes.length - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      } else {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final int totalScenes = widget.scenes.length;
    final int scenesWithImages = _countScenesWithImages();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scenes with images ($scenesWithImages/$totalScenes)',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        backgroundColor: colorScheme.primary,
        elevation: 4,
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
                      Icon(Icons.image_not_supported,
                          size: 80,
                          color: colorScheme.onSurface.withOpacity(0.5)),
                      const SizedBox(height: 20),
                      Text('No Scenes Available',
                          style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7))),
                      const SizedBox(height: 10),
                      Text('Add scenes to start creating your project.',
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
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Scene Number and Delete Button (always visible)
                                Row(
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
                                const SizedBox(height: 16),
                                // Image Section (Expands to fill remaining space)
                                Expanded(
                                  child: Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: scene.imageUrl != null &&
                                                scene.imageUrl!.isNotEmpty
                                            ? () =>
                                                OpenFilex.open(scene.imageUrl!)
                                            : null,
                                        child: Container(
                                          width: double.infinity,
                                          height: double
                                              .infinity, // Fill remaining space
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceVariant,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: scene.imageUrl != null &&
                                                  scene.imageUrl!.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.file(
                                                    File(scene.imageUrl!),
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : (_isLoading[index] ?? false)
                                                  ? Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          CircularProgressIndicator(
                                                            color: colorScheme
                                                                .primary,
                                                          ),
                                                          const SizedBox(
                                                              height: 16),
                                                          Text(
                                                              'Generating image...',
                                                              style: textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                      color: colorScheme
                                                                          .onSurface
                                                                          .withOpacity(
                                                                              0.7))),
                                                        ],
                                                      ),
                                                    )
                                                  : Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(Icons.image,
                                                              size: 60,
                                                              color: colorScheme
                                                                  .onSurface
                                                                  .withOpacity(
                                                                      0.5)),
                                                          const SizedBox(
                                                              height: 16),
                                                          ElevatedButton.icon(
                                                            onPressed: () =>
                                                                _pickImage(
                                                                    index),
                                                            icon: Icon(
                                                                Icons
                                                                    .photo_library,
                                                                color: colorScheme
                                                                    .onPrimary),
                                                            label: Text(
                                                                'Pick Image',
                                                                style: textTheme
                                                                    .labelLarge
                                                                    ?.copyWith(
                                                                        color: colorScheme
                                                                            .onPrimary)),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  colorScheme
                                                                      .primary,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12,
                                                                      horizontal:
                                                                          16),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                            ),
                                                          ),
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
                                              backgroundColor:
                                                  colorScheme.errorContainer,
                                              radius: 16,
                                              child: Icon(Icons.clear,
                                                  color: colorScheme
                                                      .onErrorContainer,
                                                  size: 18),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // "OR" Label and Prompt Section (only shown if no image is picked or if the image is generated)
                                if (scene.imageUrl == null ||
                                    scene.imageUrl!.isEmpty ||
                                    !scene.isLocalImage)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 16),
                                      // "OR" Label (only shown if no image is picked)
                                      if (scene.imageUrl == null ||
                                          scene.imageUrl!.isEmpty)
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8.0),
                                            child: Text(
                                              'OR',
                                              style:
                                                  textTheme.bodyLarge?.copyWith(
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.7),
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Prompt Section
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          controller: _controllers[index],
                                          onChanged: (value) {
                                            widget.onDescriptionChanged(
                                                index, value);
                                            setState(
                                                () {}); // Rebuild the UI to show/hide the Generate button
                                          },
                                          maxLines: 5, // Allow up to 5 lines
                                          minLines:
                                              1, // Start with a single line
                                          decoration: InputDecoration(
                                            labelText:
                                                'Prompt for generating the image',
                                            labelStyle:
                                                textTheme.bodyMedium?.copyWith(
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.7),
                                            ),
                                            floatingLabelBehavior:
                                                FloatingLabelBehavior.auto,
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
                                            fillColor: colorScheme.surface,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_controllers[index]
                                              ?.text
                                              .isNotEmpty ==
                                          true)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _generateImage(index),
                                              icon: Icon(
                                                Icons.auto_awesome,
                                                size: 18,
                                                color: colorScheme.onPrimary,
                                              ),
                                              label: Text(
                                                'Generate',
                                                style: textTheme.labelLarge
                                                    ?.copyWith(
                                                  color: colorScheme.onPrimary,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    colorScheme.primary,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
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
}
