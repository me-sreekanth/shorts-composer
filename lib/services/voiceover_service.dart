import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shorts_composer/config.dart';
import 'package:shorts_composer/services/api_service.dart';

class VoiceoverService {
  /// Pick an MP3 file using File Picker
  Future<String?> pickVoiceover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (result != null && result.files.single.path != null) {
      return result.files.single.path;
    }
    return null;
  }

  /// Generate voiceover using the provided API service
  Future<String?> generateVoiceover(
      String text, int sceneNumber, ApiService apiService) async {
    return await apiService.generateVoiceover(text, sceneNumber);
  }

  /// Combine voiceovers into a single audio file using FFmpeg
  Future<String?> combineVoiceovers(List<String> voiceoverFiles) async {
    if (voiceoverFiles.isEmpty) {
      return null;
    }

    Directory directory = await getApplicationDocumentsDirectory();
    String outputPath = '${directory.path}/combined_voiceover.mp3';

    // If there's only one file, no need to concatenate
    if (voiceoverFiles.length == 1) {
      File inputFile = File(voiceoverFiles.first);
      await inputFile.copy(outputPath);
      return outputPath;
    }

    // Create a file with the list of audio files to concatenate
    String concatFilePath = '${directory.path}/concat.txt';
    File concatFile = File(concatFilePath);
    IOSink sink = concatFile.openWrite();
    for (String filePath in voiceoverFiles) {
      sink.writeln("file '$filePath'");
    }
    await sink.close();

    // Run FFmpeg command to concatenate audio files
    String ffmpegCommand =
        '-y -f concat -safe 0 -i "$concatFilePath" -c copy "$outputPath"';

    print("Executing FFmpeg command: $ffmpegCommand");

    final session = await FFmpegKit.execute(ffmpegCommand);
    final returnCode = await session.getReturnCode();

    if (returnCode!.isValueSuccess()) {
      print("Voiceovers combined successfully at: $outputPath");
      return outputPath;
    } else {
      print("FFmpeg failed with return code: $returnCode");
      return null;
    }
  }

  /// Transcribe the combined audio file and generate an ASS subtitle file
  Future<String> transcribeAndGenerateAss(
      String audioFilePath, Function(String) onAssFileGenerated) async {
    String contentType =
        audioFilePath.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav';

    Uri url = Uri.parse(
        'https://api.deepgram.com/v1/listen?smart_format=true&model=nova-2&language=en-IN');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Token ${Config.transcribeVoiceoversToken}',
        'Content-Type': contentType,
      },
      body: File(audioFilePath).readAsBytesSync(),
    );

    if (response.statusCode == 200) {
      List<dynamic> words = jsonDecode(response.body)['results']['channels'][0]
          ['alternatives'][0]['words'];
      return await _createAssFileFromApi(words, onAssFileGenerated);
    }
    throw Exception("Failed to transcribe audio");
  }

  /// Create an ASS subtitle file from the API transcription data
  Future<String> _createAssFileFromApi(
      List<dynamic> words, Function(String) onAssFileGenerated) async {
    Directory? directory = await getApplicationDocumentsDirectory();
    final Directory appDir = Directory('${directory!.path}/ShortsComposer');
    if (!(await appDir.exists())) {
      await appDir.create(recursive: true);
    }
    final String assFilePath = '${appDir.path}/generated_subtitles.ass';
    final File assFile = File(assFilePath);
    IOSink sink = assFile.openWrite();

    // Write the ASS file headers and styles
    final String fontName = "impact";
    final int fontSize = 20;
    final String primaryColor = "&H00FFFFFF";
    final String backColor = "&H0000FFFF";
    final String outlineColor = "&H00000000";
    final int outlineThickness = 20;
    final int shadowThickness = 20;
    final int alignment = 2;
    final int bold = -1;
    final int verticalMargin = 100;

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
        'Style: Default,$fontName,$fontSize,$primaryColor,$primaryColor,$outlineColor,$backColor,$bold,0,0,0,100,100,0,0,1,$outlineThickness,$shadowThickness,$alignment,10,10,$verticalMargin,1');

    // Write events section and dialogue lines
    sink.writeln('[Events]');
    sink.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');
    for (var word in words) {
      String start = _formatTime(word['start']);
      String end = _formatTime(word['end']);
      String text = word['punctuated_word'].replaceAll('\n', ' ');

      print('Writing subtitle: Start: $start, End: $end, Text: $text');
      sink.writeln(
          'Dialogue: 0,$start,$end,Default,,0,0,$verticalMargin,,{\\an2}$text');
    }

    await sink.close();
    print(
        'ASS file created. Path: $assFilePath, Size: ${assFile.lengthSync()} bytes');
    onAssFileGenerated(assFilePath);
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
