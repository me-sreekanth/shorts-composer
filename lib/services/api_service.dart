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
      // Step 1: Perform the POST request to the Deepgram API
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
          // Step 2: Save the generated MP3 file
          final directory = await getApplicationDocumentsDirectory();
          final originalFilePath =
              '${directory.path}/scene_${sceneNumber}_original.mp3';
          final finalFilePath =
              '${directory.path}/scene_${sceneNumber}_with_beeps.mp3';

          // Write the response body as bytes to the file
          final originalFile = File(originalFilePath);
          await originalFile.writeAsBytes(response.bodyBytes);

          print('Original MP3 file saved at: $originalFilePath');

          // Step 3: Copy the beep.mp3 asset to a temporary directory
          final tempDir = await getTemporaryDirectory();
          final beepFilePath = '${tempDir.path}/silence-half-second.mp3';

          final byteData =
              await rootBundle.load('lib/assets/audio/silence-half-second.mp3');
          final beepFile = File(beepFilePath);
          await beepFile.writeAsBytes(byteData.buffer.asUint8List());

          print('Beep file copied to: $beepFilePath');

          // Step 4: Add beep at the beginning and end of the audio file
          final command = '-y '
              '-i $beepFilePath -i $originalFilePath -i $beepFilePath '
              '-filter_complex "[0:a][1:a][2:a]concat=n=3:v=0:a=1[out]" '
              '-map "[out]" $finalFilePath';

          final session = await FFmpegKit.execute(command);
          final returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            print(
                'Final MP3 file with beeps added at the beginning and end saved at: $finalFilePath');
            return finalFilePath;
          } else {
            print('Error appending beeps to the audio.');
            final logs = await session.getLogs();
            final errorLog = logs.map((log) => log.getMessage()).join('\n');
            print('FFmpeg Full Error Logs:\n$errorLog');
            return null;
          }
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
