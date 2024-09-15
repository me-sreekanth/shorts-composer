import 'dart:convert';

import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:shorts_composer/models/scene.dart';

class VideoService {
  String? backgroundMusicPath;
  String? subtitlesPath;
  String? watermarkPath; // Add a watermarkPath for the selected watermark

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

// Simplified FFmpeg command to get the audio duration in raw format
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

      // Prepare the commands to generate video clips from scenes
      for (var scene in scenes) {
        // Check if the process has been canceled
        if (isCanceled) {
          print('Video generation canceled.');
          return null;
        }

        final imagePath = scene.imageUrl!;
        final audioPath = scene.voiceoverUrl!;
        final outputPath = '$tempDir/${scene.sceneNumber}-scene.mp4';
        scene.updateVideoPath(outputPath);

        // Get the actual duration of the voiceover
        double audioDuration = await _getAudioDuration(audioPath);
        print(
            'Voiceover duration for scene ${scene.sceneNumber}: $audioDuration');

        // Select a random effect for the scene
        final selectedEffect = effects[random.nextInt(effects.length)]
            .replaceAll("{duration}", (audioDuration * 25).toString());

        // Watermark handling
        String watermarkFilter = '';
        if (watermarkPath != null) {
          watermarkFilter = "[2:v]scale=iw*1.5:-1[wm];[bg][wm]overlay=160:160";
        }

        // FFmpeg command to generate video clips with voiceover, animation, and watermark
        final ffmpegCommand = [
          '-y',
          '-loop', '1', // Loop the image
          '-i', imagePath, // Input image (scene)
          '-i', audioPath, // Input audio (voiceover)
          '-i', watermarkPath ?? 'null', // Input watermark image (optional)
          '-filter_complex',
          "[0:v]$selectedEffect[bg];" +
              watermarkFilter, // Overlay watermark with specified margins
          '-c:v', 'libx264', // Video codec
          '-pix_fmt', 'yuv420p', // Pixel format
          '-c:a', 'aac', // Audio codec
          '-b:a', '192k', // Audio bitrate
          '-shortest', // Stops at the shortest stream (audio or video)
          '-t', audioDuration.toString(), // Set video duration to match audio
          outputPath
        ];

        print(
            'Executing FFmpeg command for scene ${scene.sceneNumber}: $ffmpegCommand');

        // Execute FFmpeg command
        var session = await FFmpegKit.execute(ffmpegCommand.join(' '));
        var returnCode = await session.getReturnCode();

        // Check the result of the command
        if (ReturnCode.isSuccess(returnCode)) {
          print('FFmpeg command succeeded.');
        } else {
          print('FFmpeg command failed with result: $returnCode');
          throw Exception(
              'Error executing FFmpeg command for scene ${scene.sceneNumber}');
        }
      }

      // Concatenate the clips into a single video
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

      // Mix background music with the concatenated video
      String finalVideoPath = outputVideoPath;
      if (backgroundMusicPath != null) {
        final finalOutputPath = '$tempDir/final_video_with_music.mp4';

        final mixCommand = [
          '-y',
          '-i', outputVideoPath, // Input video with voiceover audio
          '-i', backgroundMusicPath!, // Input background music
          '-filter_complex',
          '[1:a]volume=0.3[a1];[0:a][a1]amix=inputs=2:duration=first:dropout_transition=2',
          '-map', '0:v', // Map video from the first input (outputVideoPath)
          '-c:v', 'copy', // Copy video without re-encoding
          '-c:a', 'aac', // Re-encode audio to AAC
          '-shortest', // Set duration to the shortest input
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

      // Apply subtitles to the final video if available
      if (subtitlesPath != null) {
        final subtitleOutputPath = '$tempDir/final_video_with_subs.mp4';

        final subtitleCommand = [
          '-y',
          '-i', finalVideoPath,
          '-vf', 'ass=$subtitlesPath',
          '-c:v', 'libx264', // Re-encoding to ensure subtitle filter works
          '-c:a', 'aac',
          '-b:a', '192k',
          subtitleOutputPath
        ];

        print('Executing FFmpeg subtitle command: $subtitleCommand');

        var subtitleSession =
            await FFmpegKit.execute(subtitleCommand.join(' '));
        var subtitleReturnCode = await subtitleSession.getReturnCode();
        var failStackTrace = await subtitleSession.getFailStackTrace();
        var output = await subtitleSession.getOutput();

        if (ReturnCode.isSuccess(subtitleReturnCode)) {
          print('FFmpeg subtitle command succeeded.');
          print('Output: $output');
          return subtitleOutputPath;
        } else {
          print(
              'FFmpeg subtitle command failed with result: $subtitleReturnCode');
          print('Fail Stack Trace: $failStackTrace');
          print('Output: $output');
          throw Exception('Error applying subtitles');
        }
      }

      return finalVideoPath;
    } catch (e) {
      print('Exception during video creation: $e');
      throw Exception('Error creating video: $e');
    }
  }
}
