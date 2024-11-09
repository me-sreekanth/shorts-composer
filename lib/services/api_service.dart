import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shorts_composer/config.dart';
import 'dart:io';

class ApiService {
  final String apiKey =
      '6b60433911651d961d2ffc90bfa206e0999be6c017c6fe00e420cbdc6553fbcdece9b72e15637b7d3df26026f6db12f2';

  Future<String?> generateImage(String prompt, int sceneNumber) async {
    final url = Uri.parse('https://clipdrop-api.co/text-to-image/v1');
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['prompt'] = prompt
        ..headers['x-api-key'] = apiKey;

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
      Uri.parse('${Config.imageGenerationApiUrl}/check-status'),
      headers: {
        'Authorization': 'Bearer ${Config.imageGenerationToken}',
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
    // Define the request data (just the 'text' as per the working cURL request)
    final data = {
      'text': text,
    };

    // Perform the POST request to the correct endpoint with the voice ID
    final response = await http.post(
      Uri.parse(
          '${Config.voiceoverGenerationApiUrl}/${Config.voiceoverVoiceId}'),
      headers: {
        'xi-api-key': Config.voiceoverGenerationToken,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    print('Request Body: ${jsonEncode(data)}');
    print('Response Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      // Save the response body (binary data) as an MP3 file
      try {
        // Get a directory to store the file
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/scene_$sceneNumber.mp3';

        // Write the response body as bytes to the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        print('MP3 file saved at: $filePath');

        // Return the file path so that it can be played or used later
        return filePath;
      } catch (e) {
        print('Error saving MP3 file: $e');
        return null;
      }
    } else {
      print('Error: ${response.reasonPhrase}');
      print('Error Body: ${response.body}');
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
