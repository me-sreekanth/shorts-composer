import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:shorts_composer/models/scene.dart';

class VideoService {
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
  String? backgroundMusicPath;

  Future<String?> createVideo(List<Scene> scenes) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final String tempDir = directory.path;

      // Prepare the commands to generate video clips from scenes
      for (var scene in scenes) {
        final imagePath = scene.imageUrl!;
        final audioPath = scene.voiceoverUrl!;
        final outputPath = '$tempDir/${scene.sceneNumber}-scene.mp4';

        final ffmpegCommand = [
          '-y',
          '-loop',
          '1',
          '-i',
          imagePath,
          '-i',
          audioPath,
          '-c:v',
          'mpeg4',
          '-c:a',
          'aac',
          '-b:a',
          '192k',
          '-shortest',
          '-t',
          scene.duration.toString(),
          outputPath
        ];

        print('Executing FFmpeg command: $ffmpegCommand');

        int result = await _flutterFFmpeg.executeWithArguments(ffmpegCommand);
        if (result != 0) {
          print('FFmpeg command failed with result: $result');
          throw Exception('Error executing ffmpeg command');
        }
      }

      // Concatenate the clips into a single video
      final concatFilePath = '$tempDir/concat.txt';
      final outputVideoPath = '$tempDir/final_video.mp4';
      final File concatFile = File(concatFilePath);

      // Write the paths of the individual video clips to concat.txt
      await concatFile.writeAsString(
        scenes
            .map((scene) => 'file ${tempDir}/${scene.sceneNumber}-scene.mp4')
            .join('\n'),
      );

      final concatCommand = [
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        concatFilePath,
        '-c',
        'copy',
        outputVideoPath
      ];

      print('Executing FFmpeg concat command: $concatCommand');

      int concatResult =
          await _flutterFFmpeg.executeWithArguments(concatCommand);
      if (concatResult != 0) {
        print('FFmpeg concat command failed with result: $concatResult');
        throw Exception('Error concatenating video files');
      }

      // Mix background music with the concatenated video
      if (backgroundMusicPath != null) {
        final finalOutputPath = '$tempDir/final_video_with_music.mp4';

        final mixCommand = [
          '-y',
          '-i',
          outputVideoPath,
          '-i',
          backgroundMusicPath!,
          '-filter_complex',
          '[1]volume=0.2[a1];[0][a1]amix=inputs=2:duration=first:dropout_transition=2',
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          finalOutputPath
        ];

        print('Executing FFmpeg mix command: $mixCommand');

        int mixResult = await _flutterFFmpeg.executeWithArguments(mixCommand);
        if (mixResult != 0) {
          print('FFmpeg mix command failed with result: $mixResult');
          throw Exception('Error mixing background music');
        }

        return finalOutputPath;
      }

      return outputVideoPath;
    } catch (e) {
      print('Exception during video creation: $e');
      throw Exception('Error creating video: $e');
    }
  }
}
