import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shorts_composer/config.dart';
import 'dart:io';

class ApiService {
  Future<String?> generateImage(String description, int sceneNumber) async {
    final data = {
      'model': 'sdxl-base',
      'data': {
        'negprompt': 'unreal,fake,meme,joke,disfigured,poor quality,bad,ugly',
        'samples': 1,
        'steps': 50,
        'aspect_ratio': 'portrait',
        'guidance_scale': 35,
        'seed': 8265801,
        'prompt': description,
        'style': 'realism',
      },
    };

    final response = await http.post(
      Uri.parse('${Config.imageGenerationApiUrl}/generate/processId'),
      headers: {
        'Authorization': 'Bearer ${Config.imageGenerationToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    print('Request Payload: ${jsonEncode(data)}');
    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['process_id'];
    } else {
      print('Error: ${response.reasonPhrase}');
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
    final data = {
      'text': text,
      'voice': 'Adam',
      'model_id': 'eleven_monolingual_v1',
      'voice_settings': {
        'stability': 0,
        'similarity_boost': 0,
        'style': 0,
        'use_speaker_boost': true,
      },
    };

    final response = await http.post(
      Uri.parse(
          '${Config.voiceoverGenerationApiUrl}?optimize_streaming_latency=0&output_format=mp3_44100_128'),
      headers: {
        'Authorization': 'Bearer ${Config.voiceoverGenerationToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['url'];
    } else {
      print('Error: ${response.reasonPhrase}');
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
