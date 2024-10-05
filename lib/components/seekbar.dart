import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SeekBar extends StatelessWidget {
  final AudioPlayer player;
  final Function onPlayPause;

  SeekBar({required this.player, required this.onPlayPause});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = player.duration ?? Duration.zero;
        return Slider(
          min: 0,
          max: duration.inMilliseconds.toDouble(),
          value: position.inMilliseconds
              .toDouble()
              .clamp(0, duration.inMilliseconds.toDouble()),
          onChanged: (value) {
            player.seek(Duration(milliseconds: value.round()));
          },
        );
      },
    );
  }
}
