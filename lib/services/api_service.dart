import 'dart:convert';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:shorts_composer/services/config_service.dart';

class ApiService {
  // final String apiKey =
  //     '6b60433911651d961d2ffc90bfa206e0999be6c017c6fe00e420cbdc6553fbcdece9b72e15637b7d3df26026f6db12f2';

  Future<String?> generateImage(String prompt, int sceneNumber) async {
    final url = Uri.parse(ConfigService.get('imageGenerationApiUrl'));
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['prompt'] = prompt
        ..headers['x-api-key'] = ConfigService.get('imageGenerationToken');

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBytes = await response.stream.toBytes();

        // Save the image to the device's storage
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = '${directory.path}/$sceneNumber-generated.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(responseBytes);
        return imagePath; // Return the saved file path
      } else {
        print('Failed to generate image. Status code: ${response.statusCode}');
        return null;
      }
    } catch (error) {
      print('Exception: $error');
      return null;
    }
  }

  Future<String?> fetchStatus(String processId) async {
    final payload = {
      'process_id': processId,
    };

    final response = await http.post(
      Uri.parse('${ConfigService.get('imageGenerationApiUrl')}/check-status'),
      headers: {
        'Authorization': 'Bearer ${ConfigService.get('imageGenerationToken')}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    print('Request Payload: ${jsonEncode(payload)}');
    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      if (responseData['data']['data']['status'] == 'COMPLETED' &&
          responseData['data']['data']['result'] != null) {
        return responseData['data']['data']['result']['output'][0];
      } else if (responseData['data']['data']['status'] == 'IN_PROGRESS' ||
          responseData['data']['data']['status'] == 'IN_QUEUE') {
        await Future.delayed(Duration(seconds: 10));
        return fetchStatus(processId);
      }
    } else {
      print('Error: ${response.reasonPhrase}');
      return null;
    }
  }

  Future<String> downloadImage(String url, int sceneNumber) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/$sceneNumber-scene.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(response.bodyBytes);
      return imagePath;
    } else {
      throw Exception('Failed to download image');
    }
  }

  Future<String?> generateVoiceover(String text, int sceneNumber) async {
    try {
      // Perform the POST request to the Deepgram API
      final response = await http.post(
        Uri.parse(
            '${ConfigService.get("voiceoverGenerationUrl")}?${ConfigService.get("voiceoverModel")}'),
        headers: {
          'Authorization':
              'Token ${ConfigService.get("deepgramApiToken")}', // Replace with your actual Deepgram API key
          'Content-Type': 'text/plain',
        },
        body: text,
      );

      print('Request Text: $text');
      print('Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          // Save the original MP3 file
          final directory = await getApplicationDocumentsDirectory();
          final originalFilePath =
              '${directory.path}/scene_${sceneNumber}_original.mp3';
          final reformattedAudioPath =
              '${directory.path}/scene_${sceneNumber}_reformatted.mp3';
          final reformattedSilencePath =
              '${directory.path}/silence_reformatted.mp3';
          final intermediateFilePath =
              '${directory.path}/scene_${sceneNumber}_intermediate.mp3';
          final finalFilePath = '${directory.path}/scene_$sceneNumber.mp3';

          // Write the response body as bytes to the file
          final originalFile = File(originalFilePath);
          await originalFile.writeAsBytes(response.bodyBytes);

          print('Original MP3 file saved at: $originalFilePath');

          // Copy the silence.mp3 asset to a temporary directory
          final tempDir = await getTemporaryDirectory();
          final silenceFilePath = '${tempDir.path}/silence.mp3';

          final byteData =
              await rootBundle.load('lib/assets/audio/silence.mp3');
          final silenceFile = File(silenceFilePath);
          await silenceFile.writeAsBytes(byteData.buffer.asUint8List());

          print('Silence file copied to: $silenceFilePath');

          // Reformat silence file to ensure compatibility
          final silenceReformatCommand = '-y -i $silenceFilePath '
              '-ar 44100 -ac 2 -c:a libmp3lame $reformattedSilencePath';

          final silenceReformatSession =
              await FFmpegKit.execute(silenceReformatCommand);
          if (!ReturnCode.isSuccess(
              await silenceReformatSession.getReturnCode())) {
            print('Error reformatting silence file.');
            final logs = await silenceReformatSession.getLogs();
            print(
                'FFmpeg Silence Reformat Error Logs:\n${logs.map((log) => log.getMessage()).join('\n')}');
            return null;
          }
          print('Silence reformatted: $reformattedSilencePath');

          // Reformat original audio to ensure compatibility
          final audioReformatCommand = '-y -i $originalFilePath '
              '-ar 44100 -ac 2 -c:a libmp3lame $reformattedAudioPath';

          final audioReformatSession =
              await FFmpegKit.execute(audioReformatCommand);
          if (!ReturnCode.isSuccess(
              await audioReformatSession.getReturnCode())) {
            print('Error reformatting original audio file.');
            final logs = await audioReformatSession.getLogs();
            print(
                'FFmpeg Audio Reformat Error Logs:\n${logs.map((log) => log.getMessage()).join('\n')}');
            return null;
          }
          print('Audio reformatted: $reformattedAudioPath');

          // Step 1: Add silence to the beginning
          final addBeginningCommand = '-y '
              '-i $reformattedSilencePath -i $reformattedAudioPath '
              '-filter_complex "[0:a][1:a]concat=n=2:v=0:a=1[out]" '
              '-map "[out]" $intermediateFilePath';

          final beginningSession = await FFmpegKit.execute(addBeginningCommand);
          if (!ReturnCode.isSuccess(await beginningSession.getReturnCode())) {
            print('Error adding silence to the beginning.');
            final logs = await beginningSession.getLogs();
            print(
                'FFmpeg Beginning Error Logs:\n${logs.map((log) => log.getMessage()).join('\n')}');
            return null;
          }
          print('Silence added to the beginning: $intermediateFilePath');

          // Step 2: Add silence to the end
          final addEndCommand = '-y '
              '-i $intermediateFilePath -i $reformattedSilencePath '
              '-filter_complex "[0:a][1:a]concat=n=2:v=0:a=1[out]" '
              '-map "[out]" $finalFilePath';

          final endSession = await FFmpegKit.execute(addEndCommand);
          if (!ReturnCode.isSuccess(await endSession.getReturnCode())) {
            print('Error adding silence to the end.');
            final logs = await endSession.getLogs();
            print(
                'FFmpeg End Error Logs:\n${logs.map((log) => log.getMessage()).join('\n')}');
            return null;
          }

          print('Silence added to the end: $finalFilePath');
          return finalFilePath;
        } catch (e) {
          print('Error processing MP3 file: $e');
          return null;
        }
      } else {
        print('Error: ${response.reasonPhrase}');
        print('Error Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Unexpected Error: $e');
      return null;
    }
  }

  Future<String> downloadVoiceover(String url, int sceneNumber) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final directory = await getApplicationDocumentsDirectory();
      final voiceoverPath = '${directory.path}/$sceneNumber-voiceover.mp3';
      final voiceoverFile = File(voiceoverPath);
      await voiceoverFile.writeAsBytes(response.bodyBytes);
      return voiceoverPath;
    } else {
      throw Exception('Failed to download voiceover');
    }
  }
}
