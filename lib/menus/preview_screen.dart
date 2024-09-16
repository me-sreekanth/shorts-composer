import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class PreviewScreen extends StatefulWidget {
  final String videoPath;
  final String? assFilePath;

  PreviewScreen({required this.videoPath, this.assFilePath});

  @override
  _PreviewScreenState createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Ask for permissions when screen is loaded
    _initializeVideoPlayer();
  }

  // Request storage permissions for Android and gallery permission for iOS
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    } else if (Platform.isIOS) {
      if (await Permission.photosAddOnly.isDenied) {
        await Permission.photosAddOnly.request();
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));

    setState(() {
      _initializeVideoPlayerFuture = _controller!.initialize();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _isPlaying = !_controller!.value.isPlaying;
    });
  }

  Future<void> _saveVideoToDocuments(String videoPath) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        directory =
            await getExternalStorageDirectory(); // Android's external storage
      } else if (Platform.isIOS) {
        directory =
            await getApplicationDocumentsDirectory(); // iOS Documents directory
      }

      if (directory != null) {
        String newFilePath = '${directory.path}/final_video_with_subs.mp4';
        final File newFile = File(videoPath);
        await newFile.copy(newFilePath);

        print('Video successfully saved to Documents folder: $newFilePath');

        // Open the video using the platform's default video player
        OpenFilex.open(newFilePath).then((result) {
          if (result.type != ResultType.done) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to open video file')),
            );
          }
        });
      } else {
        print("Failed to access the directory.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to access the directory')),
        );
      }
    } catch (e) {
      print('Error saving video to Documents: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving video to Documents')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Video'),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _saveVideoToDocuments(widget.videoPath),
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder(
            future: _initializeVideoPlayerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return GestureDetector(
                  onTap: _togglePlayPause,
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller?.value.size.width ?? 0,
                        height: _controller?.value.size.height ?? 0,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_controller != null)
                  VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: Colors.red,
                      bufferedColor: Colors.grey,
                      backgroundColor: Colors.black,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                    IconButton(
                      icon: Icon(Icons.replay, color: Colors.white),
                      onPressed: () {
                        _controller!.seekTo(Duration.zero);
                        _controller!.play();
                        setState(() {
                          _isPlaying = true;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
