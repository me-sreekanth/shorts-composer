import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _isAppBarVisible = true; // Track AppBar visibility

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeVideoPlayer();
  }

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

    // Initialize the video controller and add a listener
    _initializeVideoPlayerFuture = _controller!.initialize().then((_) {
      // Ensure the first frame is shown after the video is initialized
      setState(() {});

      // Add listener to update AppBar visibility based on playback state
      _controller!.addListener(_videoPlayerListener);
    });
  }

  void _videoPlayerListener() {
    final bool isPlaying = _controller!.value.isPlaying;
    final bool isEnded =
        _controller!.value.position >= _controller!.value.duration;

    if (isPlaying != _isPlaying || isEnded) {
      setState(() {
        _isPlaying = isPlaying;

        // Show AppBar when video is paused or ended
        if (!_isPlaying || isEnded) {
          _isAppBarVisible = true;
        } else {
          _isAppBarVisible = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoPlayerListener);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isAppBarVisible = true; // Show AppBar when paused
      } else {
        _controller!.play();
        _isAppBarVisible = false; // Hide AppBar when playing
      }
      _isPlaying = _controller!.value.isPlaying;
    });
  }

  Future<void> _pickSaveLocationAndSaveVideo(String videoPath) async {
    try {
      if (Platform.isAndroid) {
        String? selectedDirectory =
            await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory != null) {
          String newFilePath = '$selectedDirectory/final_video_with_subs.mp4';
          final File newFile = File(videoPath);
          await newFile.copy(newFilePath);

          print('Video successfully saved to: $newFilePath');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video saved to $newFilePath')),
          );

          OpenFilex.open(newFilePath).then((result) {
            if (result.type != ResultType.done) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to open video file')),
              );
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No folder selected')),
          );
        }
      } else if (Platform.isIOS) {
        await Share.shareXFiles([XFile(videoPath)],
            text: 'Save the video file');
      }
    } catch (e) {
      print('Error saving video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving video')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isAppBarVisible
          ? AppBar(
              title: const Text('Preview Video'),
              actions: [
                IconButton(
                  icon: Icon(Icons.download),
                  onPressed: () =>
                      _pickSaveLocationAndSaveVideo(widget.videoPath),
                ),
              ],
            )
          : null,
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
          if (_isAppBarVisible)
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
                            _isAppBarVisible = false; // Hide AppBar on replay
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
