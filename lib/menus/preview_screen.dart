import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    final String tempDir = (await getApplicationDocumentsDirectory()).path;
    final String subtitleOutputPath = '$tempDir/final_video_with_subs.mp4';

    if (widget.assFilePath != null) {
      // Apply .ass subtitles to the video
      final List<String> subtitleCommand = [
        '-i', widget.videoPath,
        '-vf', 'ass=${widget.assFilePath}',
        '-c:v', 'libx264', // Re-encode the video with subtitles
        '-c:a', 'aac', // Ensure audio is encoded
        '-b:a', '192k', // Audio bitrate
        '-y', subtitleOutputPath
      ];

      print('Executing FFmpeg subtitle command: $subtitleCommand');

      var session = await FFmpegKit.execute(subtitleCommand.join(' '));
      var returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        _controller = VideoPlayerController.file(File(subtitleOutputPath));
      } else {
        _controller = VideoPlayerController.file(File(widget.videoPath));
      }
    } else {
      _controller = VideoPlayerController.file(File(widget.videoPath));
    }

    // Initialize the video player once FFmpeg has finished
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
