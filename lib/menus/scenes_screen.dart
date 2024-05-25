import 'package:flutter/material.dart';
import 'package:shorts_composer/models/scene.dart';

class ScenesScreen extends StatefulWidget {
  final List<Scene> scenes;
  final Function(int, String) onDescriptionChanged;
  final Function(int) onGenerateImage;

  ScenesScreen(
      {required this.scenes,
      required this.onDescriptionChanged,
      required this.onGenerateImage});

  @override
  _ScenesScreenState createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
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
                    ? Image.network(scene.imageUrl!)
                    : Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: Center(child: Text('No Image'))),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    widget.onGenerateImage(index);
                  },
                  child: Icon(Icons.image),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
