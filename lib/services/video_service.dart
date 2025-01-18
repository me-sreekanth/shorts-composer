import 'dart:convert';

import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart'; // For loading assets
import 'package:shorts_composer/models/scene.dart';
import 'package:flutter/foundation.dart';
import 'package:shorts_composer/services/config_service.dart';
import 'package:http/http.dart' as http;

class VideoService {
  String? backgroundMusicPath;
  String? subtitlesPath;
  String? watermarkPath;

  final ValueNotifier<String> progressNotifier =
      ValueNotifier<String>('Starting video generation...');

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
        // FINAL animations
        //Zoom in
        "zoompan=z='zoom+0.0015':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

        //Jerk animation
        "zoompan=z=1.5:x='iw/2-(iw/zoom/2)':y='random(1)*20':d={duration}:s=1080x1920",

        //Random zoom with both horizontal and vertical random panning
        "zoompan=z='1.3+random(1)*0.1':x='random(1)*iw':y='random(1)*ih':d={duration}:s=1080x1920",

        //Pan left to right
        "zoompan=z=1.3:x='(iw-iw/zoom)*(1-on/({duration}*0.7))':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",
        "zoompan=z=1.4:x='(iw-iw/zoom)*(1-on/({duration}*0.5))':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

        // Smooth Orbit Zoom In (Circular Pan)
        "zoompan=z='1.05+0.0003*on':x='iw/2-(iw/zoom/2)+cos(on*0.1)*30':y='ih/2-(ih/zoom/2)+sin(on*0.1)*30':d={duration}:s=1080x1920",

        //Diagonal Pan with Zoom In
        "zoompan=z='zoom+0.002':x='iw/2-(iw/zoom/2)+(on*10)':y='ih/2-(ih/zoom/2)+(on*10)':d={duration}:s=1080x1920",

        // Oscillating Zoom with Horizontal Sway
        "zoompan=z='1+0.04*sin(on*6)':x='iw/2-(iw/zoom/2)+sin(on*3.14)*200':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920"

            // Soft Bounce Effect with Light Zoom
            "zoompan=z='1+0.02*sin(on*3.14/6)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

        // Smooth Zoom In
        "zoompan=z='1.05+0.0005*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

        // Diagonal Pan with Slow Zoom
        "zoompan=z='1.1+0.0005*on':x='(iw-iw/zoom)*(on/({duration}*0.7))':y='(ih-ih/zoom)*(on/({duration}*0.7))':d={duration}:s=1080x1920",

        // Gentle Zoom Out
        "zoompan=z='1.2-0.0005*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

        // Vertical Slide with Subtle Zoom Out
        "zoompan=z='1.1-0.0005*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)-(on*5)':d={duration}:s=1080x1920",

        // Smooth Circular Pan with Slow Zoom In
        "zoompan=z='1.1+0.0003*on':x='iw/2-(iw/zoom/2)+cos(on*0.05)*20':y='ih/2-(ih/zoom/2)+sin(on*0.05)*20':d={duration}:s=1080x1920",

        // Slow Diagonal Slide with Zoom Out
        "zoompan=z='1.1-0.0004*on':x='(iw-iw/zoom)*(on/({duration}*0.7))':y='(ih-ih/zoom)*(1-on/({duration}*0.7))':d={duration}:s=1080x1920",

        // Subtle Diagonal Pan Top-Left to Bottom-Right with Zoom Out
        "zoompan=z='1.1-0.0003*on':x='(iw-iw/zoom)*(1-on/({duration}*0.9))':y='(ih-ih/zoom)*(1-on/({duration}*0.9))':d={duration}:s=1080x1920",

        // Gentle Orbit with Light Zoom In
        "zoompan=z='1.02+0.0002*on':x='iw/2-(iw/zoom/2)+cos(on*0.05)*15':y='ih/2-(ih/zoom/2)+sin(on*0.05)*15':d={duration}:s=1080x1920",

        // Slow Vertical Sway with Zoom Out
        "zoompan=z='1.1-0.0003*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)+sin(on*0.05)*30':d={duration}:s=1080x1920",

        // Horizontal Sway with Subtle Zoom
        "zoompan=z='1.02+0.0004*on':x='iw/2-(iw/zoom/2)+sin(on*0.1)*50':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",
      ];

      for (var scene in scenes) {
        if (isCanceled) {
          print('Video generation canceled.');
          return null;
        }

        progressNotifier.value = 'Processing scene ${scene.sceneNumber}...';

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

        // Updated Scale and Crop Filter
        final scaleAndCropFilter =
            "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920";

        final ffmpegCommand = [
          '-y',
          '-loop',
          '1',
          '-i',
          '"$imagePath"', // Image file
          '-i',
          '"$audioPath"', // Voiceover audio
          '-i',
          watermarkPath != null ? '"$watermarkPath"' : 'null', // Watermark file
          '-filter_complex',
          "[0:v]$scaleAndCropFilter,$selectedEffect[bg];" + watermarkFilter,
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
          '"$outputPath"' // Output video
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

      progressNotifier.value = 'Combining video scenes...';
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

      //generate subtitles
      final audioPath = await extractAudioFromVideo(finalVideoPath);
      await _transcribeCombinedVoiceovers(audioPath);

      print('subtitlesPath: $subtitlesPath');
      // Apply subtitles to the final video if available
      if (subtitlesPath != null && _doesFileExist(subtitlesPath!)) {
        progressNotifier.value = 'Applying subtitles...';
        final subtitleOutputPath = '$tempDir/final_video_with_subs.mp4';

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
        progressNotifier.value = 'Mixing background music...';
        final finalOutputPath = '$tempDir/final_video_with_music.mp4';

        final mixCommand = [
          '-y',
          '-i',
          '"$finalVideoPath"', // Wrap path in quotes
          '-i',
          '"$backgroundMusicPath"', // Wrap background music path in quotes
          '-filter_complex',
          '[0:a]volume=4.0[a0];[1:a]volume=0.5[a1];[a0][a1]amix=inputs=2:duration=first:dropout_transition=2',
          '-map',
          '0:v',
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          '-shortest',
          '"$finalOutputPath"' // Wrap output path in quotes
        ];

        print('Executing FFmpeg mix command: $mixCommand');

        var mixSession = await FFmpegKit.execute(mixCommand.join(' '));
        var mixReturnCode = await mixSession.getReturnCode();
        if (!ReturnCode.isSuccess(mixReturnCode)) {
          throw Exception('Error mixing background music');
        }

        finalVideoPath = finalOutputPath;
      }

      progressNotifier.value = 'Video generation completed.';
      return finalVideoPath;
    } catch (e) {
      print('Exception during video creation: $e');
      progressNotifier.value = 'Error during video generation.';
      throw Exception('Error creating video: $e');
    }
  }

  Future<void> _transcribeCombinedVoiceovers(String audioPath) async {
    try {
      print('combinedAudioPath: $audioPath');
      if (audioPath != null) {
        // Pass both the scenes and the onAssFileGenerated callback
        String assFilePath = await transcribeAndGenerateAss(audioPath);
        subtitlesPath = assFilePath;
        print('assFilePath: $assFilePath');
      }
    } catch (e) {
      print('Exception during transcription: $e');
    } finally {}
  }

  /// Extracts audio from a video file and returns the generated MP3 file path.
  Future<String> extractAudioFromVideo(String videoPath) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String audioOutputPath =
        '${directory.path}/${videoPath.split('/').last}.mp3';

    final extractAudioCommand = [
      '-y', '-i', videoPath, // Input video
      '-vn', // Remove video stream
      '-acodec', 'libmp3lame', // Use MP3 codec
      '-q:a', '3', // Quality: Lower is better (3 is decent quality)
      audioOutputPath
    ];

    print('Extracting audio from video: $videoPath');

    var session = await FFmpegKit.execute(extractAudioCommand.join(' '));
    var returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print('Audio extracted successfully: $audioOutputPath');
      return audioOutputPath;
    } else {
      print('Error extracting audio from video');
      throw Exception('FFmpeg failed to extract audio from video');
    }
  }

  Future<String> transcribeAndGenerateAss(String audioFilePath) async {
    String contentType =
        audioFilePath.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav';

    Uri url = Uri.parse(ConfigService.get('transcribeVoiceoversUrl'));
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Token ${ConfigService.get('deepgramApiToken')}',
        'Content-Type': contentType,
      },
      body: File(audioFilePath).readAsBytesSync(),
    );

    print('response: $response.body');
    if (response.statusCode == 200) {
      final decodedResponse = jsonDecode(response.body);
      List<dynamic> words =
          decodedResponse['results']['channels'][0]['alternatives'][0]['words'];
      print('words: $words');
      // Generate ASS file
      return await _createAssFileFromApi(words);
    }
    throw Exception("Failed to transcribe audio");
  }

  Future<String> _createAssFileFromApi(List<dynamic> words) async {
    Directory? directory = await getApplicationDocumentsDirectory();
    final Directory appDir = Directory('${directory!.path}/ShortsComposer');
    if (!(await appDir.exists())) {
      await appDir.create(recursive: true);
    }
    final String assFilePath = '${appDir.path}/generated_subtitles.ass';
    final File assFile = File(assFilePath);
    IOSink sink = assFile.openWrite();

    // Write the ASS file headers and styles
    String fontName = "impact";
    int fontSize = 20;
    String primaryColor = "&H00FFFFFF";
    String backColor = "&H0000FFFF";
    String outlineColor = "&H00000000";
    int outlineThickness = 20;
    int shadowThickness = 20;
    int alignment = 2;
    int bold = -1;
    int verticalMargin = 100;

    // Write script info section
    sink.writeln('[Script Info]');
    sink.writeln('Title: Transcription');
    sink.writeln('ScriptType: v4.00+');
    sink.writeln('Collisions: Normal');
    sink.writeln('PlayDepth: 0');
    sink.writeln('Timer: 100.0000');

    // Write styles section
    sink.writeln('[V4+ Styles]');
    sink.writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    sink.writeln(
        'Style: Default,$fontName,$fontSize,$primaryColor,$primaryColor,$outlineColor,$backColor,$bold,0,0,0,100,100,0,0,3,$outlineThickness,$shadowThickness,$alignment,10,10,$verticalMargin,1');

    // Write events section and dialogue lines
    sink.writeln('[Events]');
    sink.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');
    for (var word in words) {
      String start = _formatTime(word['start']);
      String end = _formatTime(word['end']);
      String text = word['punctuated_word'];

      print('Writing subtitle: Start: $start, End: $end, Text: $text');
      sink.writeln(
          'Dialogue: 0,$start,$end,Default,,0,0,$verticalMargin,,{\\an2}$text');
    }

    await sink.close();
    print(
        'ASS file created. Path: $assFilePath, Size: ${assFile.lengthSync()} bytes');
    // onAssFileGenerated(assFilePath);
    return assFilePath;
  }

  /// Helper function to format time in the HH:MM:SS.xx format for ASS subtitles
  String _formatTime(double time) {
    int hours = time ~/ 3600;
    int minutes = (time % 3600) ~/ 60;
    int seconds = (time % 60).toInt();
    int milliseconds = ((time % 1) * 100).toInt();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
  }
}
