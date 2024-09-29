import 'dart:convert';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart'; // For loading assets
import 'package:shorts_composer/models/scene.dart';

class VideoService {
  String? backgroundMusicPath;
  String? subtitlesPath;
  String? watermarkPath;

  bool _doesFileExist(String path) {
    File file = File(path);
    bool exists = file.existsSync();
    if (!exists) {
      print('File does not exist: $path');
    } else {
      print('File exists: $path');
    }
    return exists;
  }

  Future<double> _getAudioDuration(String audioPath) async {
    final audioPlayer = AudioPlayer();
    try {
      final duration = await audioPlayer.setFilePath(audioPath);
      if (duration != null) {
        return duration.inSeconds.toDouble();
      } else {
        throw Exception('Could not get audio duration.');
      }
    } finally {
      await audioPlayer.dispose();
    }
  }

  Future<String?> createVideo(List<Scene> scenes, bool isCanceled) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final String tempDir = directory.path;
      final Random random = Random();

      final List<String> effects = [
        "zoompan=z='zoom+0.0015':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",
        "zoompan=z='zoom+0.005':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=25:s=1080x1920",
        "zoompan=z=1.5:x='iw/2-(iw/zoom/2)':y='random(1)*20':d={duration}:s=1080x1920",
      ];

      for (var scene in scenes) {
        if (isCanceled) {
          print('Video generation canceled.');
          return null;
        }

        final imagePath = scene.imageUrl!;
        final audioPath = scene.voiceoverUrl!;
        final outputPath = '$tempDir/${scene.sceneNumber}-scene.mp4';
        scene.updateVideoPath(outputPath);

        double audioDuration = await _getAudioDuration(audioPath);
        print(
            'Voiceover duration for scene ${scene.sceneNumber}: $audioDuration');

        final selectedEffect = effects[random.nextInt(effects.length)]
            .replaceAll("{duration}", (audioDuration * 25).toString());

        String watermarkFilter = '';
        if (watermarkPath != null) {
          watermarkFilter = "[2:v]scale=iw*1.5:-1[wm];[bg][wm]overlay=160:160";
        }

        final ffmpegCommand = [
          '-y',
          '-loop',
          '1',
          '-i',
          imagePath,
          '-i',
          audioPath,
          '-i',
          watermarkPath ?? 'null',
          '-filter_complex',
          "[0:v]$selectedEffect[bg];" + watermarkFilter,
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          '-c:a',
          'aac',
          '-b:a',
          '192k',
          '-shortest',
          '-t',
          audioDuration.toString(),
          outputPath
        ];

        print(
            'Executing FFmpeg command for scene ${scene.sceneNumber}: $ffmpegCommand');

        var session = await FFmpegKit.execute(ffmpegCommand.join(' '));
        var returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          print('FFmpeg command succeeded.');
        } else {
          print('FFmpeg command failed with result: $returnCode');
          throw Exception(
              'Error executing FFmpeg command for scene ${scene.sceneNumber}');
        }
      }

      final concatFilePath = '$tempDir/concat.txt';
      final outputVideoPath = '$tempDir/final_video.mp4';
      final File concatFile = File(concatFilePath);

      final concatContent =
          scenes.map((scene) => "file '${scene.videoPath}'").join('\n');
      await concatFile.writeAsString(concatContent);

      final concatCommand = [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        concatFilePath,
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        outputVideoPath
      ];

      print('Executing FFmpeg concat command: $concatCommand');

      var concatSession = await FFmpegKit.execute(concatCommand.join(' '));
      var concatReturnCode = await concatSession.getReturnCode();
      if (!ReturnCode.isSuccess(concatReturnCode)) {
        throw Exception('Error concatenating video files');
      }

      String finalVideoPath = outputVideoPath;

      // Apply subtitles to the final video if available
      if (subtitlesPath != null && _doesFileExist(subtitlesPath!)) {
        final subtitleOutputPath = '$tempDir/final_video_with_subs.mp4';

        // Ensure the .ass file is in the correct location
        final fontData = await rootBundle.load('lib/assets/impact.ttf');
        final fontPath = '${directory.path}/impact.ttf';
        await File(fontPath).writeAsBytes(fontData.buffer.asUint8List());

        final subtitleCommand = [
          '-y',
          '-i',
          finalVideoPath,
          '-vf',
          'ass=${subtitlesPath}:fontsdir=${directory.path}', // Reference the subtitlesPath and font
          '-c:v',
          'libx264',
          '-c:a',
          'aac',
          '-b:a',
          '192k',
          subtitleOutputPath
        ];

        print('Subtitle path: $subtitlesPath');
        print('Executing FFmpeg subtitle command: $subtitleCommand');

        var subtitleSession =
            await FFmpegKit.execute(subtitleCommand.join(' '));
        var subtitleReturnCode = await subtitleSession.getReturnCode();

        if (ReturnCode.isSuccess(subtitleReturnCode)) {
          print('FFmpeg subtitle command succeeded.');
          finalVideoPath = subtitleOutputPath;
        } else {
          print('FFmpeg subtitle command failed');
          throw Exception('Error applying subtitles');
        }
      } else {
        print("No subtitles to apply or subtitle file does not exist.");
      }

      // **Mix background music if it's available**
      if (backgroundMusicPath != null) {
        final finalOutputPath = '$tempDir/final_video_with_music.mp4';

        final mixCommand = [
          '-y',
          '-i',
          finalVideoPath,
          '-i',
          backgroundMusicPath!,
          '-filter_complex',
          '[1:a]volume=0.3[a1];[0:a][a1]amix=inputs=2:duration=first:dropout_transition=2', // Mixing the background music with voiceover
          '-map',
          '0:v',
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          '-shortest',
          finalOutputPath
        ];

        print('Executing FFmpeg mix command: $mixCommand');

        var mixSession = await FFmpegKit.execute(mixCommand.join(' '));
        var mixReturnCode = await mixSession.getReturnCode();
        if (!ReturnCode.isSuccess(mixReturnCode)) {
          throw Exception('Error mixing background music');
        }

        finalVideoPath = finalOutputPath;
      }

      return finalVideoPath;
    } catch (e) {
      print('Exception during video creation: $e');
      throw Exception('Error creating video: $e');
    }
  }
}
