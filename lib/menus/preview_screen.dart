import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

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
    _initializeVideoPlayer();
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

  Future<void> _saveVideoToGallery(String videoPath) async {
    try {
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.storage.request();
        if (!status.isGranted) {
          print("Permission not granted for storage access");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Permission not granted for storage access')),
          );
          return;
        }
      } else if (Platform.isIOS) {
        PermissionStatus status = await Permission.photosAddOnly.request();
        if (!status.isGranted) {
          print("Permission not granted for gallery access");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Permission not granted for gallery access')),
          );
          return;
        }
      }

      // Use GallerySaver to save the video to the gallery
      await GallerySaver.saveVideo(videoPath).then((bool? success) {
        if (success != null && success) {
          print('Video successfully saved to gallery');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video saved to gallery')),
          );
        } else {
          print('Failed to save video to gallery');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save video to gallery')),
          );
        }
      });
    } catch (e) {
      print('Error saving video to gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving video to gallery')),
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
            onPressed: () => _saveVideoToGallery(widget.videoPath),
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
