import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';

class TranscribeScreen extends StatefulWidget {
  final Function(String?) onBackgroundMusicSelected;

  const TranscribeScreen({Key? key, required this.onBackgroundMusicSelected})
      : super(key: key);

  @override
  _TranscribeScreenState createState() => _TranscribeScreenState();
}

class _TranscribeScreenState extends State<TranscribeScreen> {
  String? _backgroundMusicPath;
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _currentPosition = 0.0;
  Duration? _totalDuration;
  bool _isPlaying = false;

  void _pickBackgroundMusic() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _backgroundMusicPath = result.files.single.path!;
        widget.onBackgroundMusicSelected(_backgroundMusicPath);
        _audioPlayer.setFilePath(_backgroundMusicPath!).then((duration) {
          setState(() {
            _totalDuration = duration;
          });
        });
      });
    }
  }

  void _playPauseMusic() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _currentPosition = position.inSeconds.toDouble();
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _pickBackgroundMusic,
          child: Text('Pick Background Music'),
        ),
        if (_backgroundMusicPath != null)
          Column(
            children: [
              Slider(
                value: _currentPosition,
                min: 0.0,
                max: _totalDuration?.inSeconds.toDouble() ?? 0.0,
                onChanged: (value) {
                  setState(() {
                    _currentPosition = value;
                  });
                  _audioPlayer.seek(Duration(seconds: value.toInt()));
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: _playPauseMusic,
                  ),
                  IconButton(
                    icon: Icon(Icons.replay),
                    onPressed: () {
                      _audioPlayer.seek(Duration.zero);
                      _audioPlayer.play();
                      setState(() {
                        _isPlaying = true;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
