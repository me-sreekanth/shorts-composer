import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:shorts_composer/models/scene.dart';

class VideoService {
  String? backgroundMusicPath;
  String? subtitlesPath;

  Future<String?> createVideo(List<Scene> scenes) async {
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
        final imagePath = scene.imageUrl!;
        final audioPath = scene.voiceoverUrl!;
        final outputPath = '$tempDir/${scene.sceneNumber}-scene.mp4';
        scene.updateVideoPath(outputPath);

        // Select a random effect for the scene
        final selectedEffect = effects[random.nextInt(effects.length)]
            .replaceAll("{duration}", (scene.duration * 25).toString());

        // FFmpeg command to generate video clips with voiceover and animation
        final ffmpegCommand = [
          '-y',
          '-loop',
          '1',
          '-i',
          imagePath,
          '-i',
          audioPath,
          '-vf',
          selectedEffect,
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
          scene.duration.toString(),
          outputPath
        ];

        print(
            'Executing FFmpeg command for scene ${scene.sceneNumber}: $ffmpegCommand');

        var session = await FFmpegKit.execute(ffmpegCommand.join(' '));
        var returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
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
