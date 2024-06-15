import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shorts_composer/services/transcription_service.dart';

class PreviewScreen extends StatefulWidget {
  final String videoPath;

  PreviewScreen({required this.videoPath});

  @override
  _PreviewScreenState createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  bool _isPlaying = false;
  String _transcription = '';
  List<String> _transcriptionWords = [];
  int _currentWordIndex = 0;
  bool _isTranscribing = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _isPlaying = true;
      });

    _initializeVideoPlayerFuture = _controller.initialize();

    _generateTranscription();
  }

  Future<void> _generateTranscription() async {
    TranscriptionService transcriptionService = TranscriptionService();
    String transcription =
        await transcriptionService.transcribeVideo(widget.videoPath);

    setState(() {
      _transcription = transcription;
      _transcriptionWords = transcription.split(' ');
      _isTranscribing = false;
    });

    _startTranscriptionAnimation();
  }

  void _startTranscriptionAnimation() {
    _controller.addListener(() {
      final position = _controller.value.position.inSeconds;
      if (position > _currentWordIndex &&
          _currentWordIndex < _transcriptionWords.length) {
        setState(() {
          _currentWordIndex = position;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _isPlaying = !_controller.value.isPlaying;
    });
  }

  void _replay() {
    _controller.seekTo(Duration.zero);
    _controller.play();
    setState(() {
      _isPlaying = true;
      _currentWordIndex = 0;
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
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
          if (!_isTranscribing &&
              _currentWordIndex < _transcriptionWords.length)
            Center(
              child: Container(
                padding: EdgeInsets.all(8.0),
                color: Colors.black54,
                child: Text(
                  _transcriptionWords[_currentWordIndex],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                VideoProgressIndicator(
                  _controller,
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
                      onPressed: _replay,
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
